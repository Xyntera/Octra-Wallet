import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../rpc.dart';
import '../wallet.dart';
import 'bridge_models.dart';
import 'bridge_relayer.dart';
import 'eth_abi.dart';
import 'eth_account.dart';
import 'eth_constants.dart';
import 'eth_rpc.dart';
import 'eth_tx_sender.dart';

/// Orchestrates the OCT <-> wOCT bridge: builds/submits the Octra lock, drives
/// the relayer claim flow on Ethereum (wrap), and the approve/burn flow
/// (unwrap), persisting history so claims can be resumed.
///
/// Experimental — handles mainnet funds. Test with minimal amounts.
class BridgeService extends ChangeNotifier {
  final WalletController wallet;
  final EthRpc _eth;
  final BridgeRelayer _relayer;
  final FlutterSecureStorage _storage;

  static const _historyKey = 'bridge_history';

  final List<BridgeRecord> _history = [];
  List<BridgeRecord> get history => List.unmodifiable(_history);
  bool _disposed = false;

  BigInt ethBalanceWei = BigInt.zero;
  BigInt woctBalanceRaw = BigInt.zero;
  bool busy = false;

  BridgeService({
    required this.wallet,
    EthRpc? eth,
    BridgeRelayer? relayer,
    FlutterSecureStorage? storage,
  })  : _eth = eth ?? EthRpc(),
        _relayer = relayer ?? BridgeRelayer(),
        _storage = storage ?? const FlutterSecureStorage();

  // ---- history persistence -------------------------------------------------

  Future<void> loadHistory() async {
    final raw = await _storage.read(key: _historyKey);
    _history.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final e in list) {
            if (e is Map) {
              _history.add(BridgeRecord.fromJson(e.cast<String, dynamic>()));
            }
          }
        }
      } catch (_) {/* ignore corrupt history */}
    }
    _history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  Future<void> _persist() async {
    await _storage.write(
      key: _historyKey,
      value: jsonEncode(_history.map((r) => r.toJson()).toList()),
    );
  }

  void _upsert(BridgeRecord r) {
    final i = _history.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      _history[i] = r;
    } else {
      _history.insert(0, r);
    }
    _persist();
    if (!_disposed) notifyListeners();
  }

  // ---- balances + gas price ------------------------------------------------

  Future<void> refreshBalances(String ethAddress) async {
    if (!EthAccount.isValidAddress(ethAddress)) return;
    try {
      ethBalanceWei = await _eth.ethBalanceWei(ethAddress);
      woctBalanceRaw = await _eth.woctBalance(ethAddress);
      if (!_disposed) notifyListeners();
    } catch (_) {/* surfaced by callers */}
  }

  /// Current Ethereum gas price in wei (for fee estimation in the UI).
  Future<BigInt> currentGasPrice() => _eth.gasPrice();

  /// Checks the relayer recovery feed for [ethAddress] and advances any pending
  /// wrap records to [BridgeStatus.claimable] (or [BridgeStatus.completed] if
  /// already claimed on-chain). Call this when the bridge screen opens or on
  /// manual refresh.
  ///
  /// Claim calldata is built client-side from the recovery feed data using
  /// the `verifyAndMint` ABI — this matches the mechanism used by
  /// bridge.0xio.xyz and does not require the relayer's RPC.
  Future<void> resumePendingWraps(String ethAddress) async {
    // First, reconcile any claim that outran its receipt poll.
    await _recheckSubmittingClaims();

    final pending = _history
        .where((r) =>
            r.direction == BridgeDirection.wrap &&
            r.status == BridgeStatus.pending &&
            r.lockTxHash != null)
        .toList();
    if (pending.isEmpty) return;

    List<Map<String, dynamic>> recovery = const [];
    try {
      recovery = await _relayer.fetchRecovery(ethAddress);
    } catch (_) {}

    for (var rec in pending) {
      // Find matching recovery entry by tx_hash (no 0x prefix in the feed).
      Map<String, dynamic>? entry;
      final lockHash =
          (rec.lockTxHash ?? '').toLowerCase().replaceAll('0x', '');
      for (final e in recovery) {
        final th = (e['tx_hash'] as String? ?? '').toLowerCase();
        if (th == lockHash) {
          entry = e;
          break;
        }
      }
      if (entry == null) continue;

      final epochStr = entry['epoch']?.toString();
      final epoch = epochStr != null ? int.tryParse(epochStr) : null;
      final srcNonce = entry['src_nonce'] is num
          ? (entry['src_nonce'] as num).toInt()
          : int.tryParse(entry['src_nonce']?.toString() ?? '');
      final amountRaw = BigInt.tryParse(
          entry['amount_raw']?.toString() ?? rec.amountRaw);

      if (epoch == null || srcNonce == null || amountRaw == null) continue;

      // Persist epoch + srcNonce so the record can claim without the feed.
      if (rec.epoch == null || rec.srcNonce == null) {
        rec = rec.copyWith(epoch: epoch.toString(), srcNonce: srcNonce);
        _upsert(rec);
      }

      // Build verifyAndMint calldata locally and simulate it.
      await _checkClaimable(rec, epoch, amountRaw, srcNonce);
    }
  }

  /// Looks up [lockTxHash] in the global recovery feed (all recipients) and
  /// creates/updates a [BridgeRecord] for it.  Used by "Claim by TX Hash".
  Future<BridgeRecord?> importByLockTxHash(String lockTxHash) async {
    final entry = await _relayer.findRecoveryByTxHash(lockTxHash);
    if (entry == null) return null;

    final ethAddr = entry['eth_address']?.toString() ?? '';
    final epochStr = entry['epoch']?.toString();
    final epoch = epochStr != null ? int.tryParse(epochStr) : null;
    final srcNonce = entry['src_nonce'] is num
        ? (entry['src_nonce'] as num).toInt()
        : int.tryParse(entry['src_nonce']?.toString() ?? '');
    final amountRaw =
        BigInt.tryParse(entry['amount_raw']?.toString() ?? '');

    if (epoch == null || srcNonce == null || amountRaw == null) return null;

    // Reuse an existing record if one already matches.
    final normHash = lockTxHash.toLowerCase().replaceAll('0x', '');
    var rec = _history.cast<BridgeRecord?>().firstWhere(
          (r) =>
              r != null &&
              (r.lockTxHash ?? '').toLowerCase().replaceAll('0x', '') ==
                  normHash,
          orElse: () => null,
        );

    if (rec == null) {
      rec = BridgeRecord(
        id: 'w_import_${lockTxHash.substring(0, 8)}',
        direction: BridgeDirection.wrap,
        amountRaw: amountRaw.toString(),
        ethAddress: ethAddr,
        octraAddress: wallet.currentWallet?.address ?? '',
        lockTxHash: lockTxHash,
        epoch: epoch.toString(),
        srcNonce: srcNonce,
        status: BridgeStatus.pending,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      _upsert(rec);
    } else if (rec.epoch == null || rec.srcNonce == null) {
      rec = rec.copyWith(epoch: epoch.toString(), srcNonce: srcNonce);
      _upsert(rec);
    }

    await _checkClaimable(rec, epoch, amountRaw, srcNonce);
    return _history.firstWhere((r) => r.id == rec!.id);
  }

  /// Builds verifyAndMint calldata and simulates it; advances [rec] to
  /// [BridgeStatus.claimable] or [BridgeStatus.completed] as appropriate.
  Future<void> _checkClaimable(
    BridgeRecord rec,
    int epoch,
    BigInt amountRaw,
    int srcNonce,
  ) async {
    final calldata = EthAbi.verifyAndMint(
      epochId: epoch,
      amountRaw: amountRaw,
      srcNonce: srcNonce,
      ethRecipient: rec.ethAddress,
    );
    try {
      await _eth.call(EthConstants.ethereumBridge, calldata);
      // Simulation succeeded → claimable.
      _upsert(rec.copyWith(status: BridgeStatus.claimable));
    } catch (e) {
      if (e.toString().contains('already_claimed')) {
        _upsert(rec.copyWith(status: BridgeStatus.completed));
      }
      // Otherwise header not yet live on Ethereum — stay pending.
    }
  }

  // ---- WRAP (OCT -> wOCT) --------------------------------------------------

  /// Step 1: lock OCT on Octra. Returns the created record (status pending).
  Future<BridgeRecord> startWrap({
    required String ethRecipient,
    required int microOct,
  }) async {
    final octra = wallet.currentWallet?.address ?? '';
    final res = await wallet.bridgeLockToEth(ethRecipient, microOct);
    final hash = _extractTxHash(res);
    if (hash == null) {
      throw StateError(res.text.isEmpty ? 'Lock failed' : res.text);
    }
    final rec = BridgeRecord(
      id: 'w_${DateTime.now().millisecondsSinceEpoch}',
      direction: BridgeDirection.wrap,
      amountRaw: microOct.toString(),
      ethAddress: ethRecipient.trim(),
      octraAddress: octra,
      lockTxHash: hash,
      status: BridgeStatus.pending,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _upsert(rec);
    return rec;
  }

  /// Step 2: wait for the epoch + relayer header, then verify the claim is
  /// live on Ethereum. Marks the record [BridgeStatus.claimable] when ready.
  Future<BridgeRecord> prepareClaim(
    BridgeRecord rec, {
    Duration headerTimeout = const Duration(minutes: 6),
  }) async {
    final lockHash = rec.lockTxHash;
    if (lockHash == null) throw StateError('missing lock tx');

    // epoch from the contract receipt
    String? epoch = rec.epoch;
    final deadline = DateTime.now().add(headerTimeout);
    while (epoch == null && DateTime.now().isBefore(deadline)) {
      final receipt = await wallet.rpc.contractReceipt(lockHash);
      final e = receipt?['epoch'] ?? receipt?['epoch_id'];
      if (e != null) epoch = e.toString();
      if (epoch == null) await Future<void>.delayed(const Duration(seconds: 3));
    }
    if (epoch == null) throw StateError('epoch not finalized yet');

    // relayer header + claim calldata for our recipient
    String? calldata;
    while (calldata == null && DateTime.now().isBefore(deadline)) {
      final count = await _relayer.bridgeHeaderMessageCount(epoch);
      if (count > 0) {
        calldata =
            await _relayer.claimCalldataForRecipient(epoch, rec.ethAddress);
      }
      if (calldata == null) {
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    }
    if (calldata == null) throw StateError('claim not available yet');

    // verify the header has landed on Ethereum (simulate until it stops
    // reverting)
    var ok = false;
    while (!ok && DateTime.now().isBefore(deadline)) {
      try {
        await _eth.call(EthConstants.ethereumBridge, calldata);
        ok = true;
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    }

    final updated = rec.copyWith(epoch: epoch, status: BridgeStatus.claimable);
    _upsert(updated);
    return updated;
  }

  /// Step 3: claim wOCT on Ethereum. Calldata is built client-side from the
  /// stored epoch, srcNonce, and amountRaw — same mechanism as bridge.0xio.xyz.
  Future<BridgeRecord> claim(
    BridgeRecord rec,
    EthTxSender sender, {
    GasSpeed gasSpeed = GasSpeed.standard,
  }) async {
    final epochStr = rec.epoch;
    if (epochStr == null) throw StateError('record has no epoch');
    final epoch = int.tryParse(epochStr);
    if (epoch == null) throw StateError('epoch is not numeric: $epochStr');

    var srcNonce = rec.srcNonce;
    final amountRaw = BigInt.tryParse(rec.amountRaw) ?? BigInt.zero;

    // If srcNonce is missing (pre-fix records), try to fetch it from the feed.
    if (srcNonce == null) {
      final entry = await _relayer.findRecoveryByTxHash(rec.lockTxHash ?? '');
      if (entry == null) {
        throw StateError(
            'srcNonce not stored and tx not found in recovery feed — '
            'open the bridge screen to refresh.');
      }
      srcNonce = entry['src_nonce'] is num
          ? (entry['src_nonce'] as num).toInt()
          : int.tryParse(entry['src_nonce']?.toString() ?? '');
      if (srcNonce == null) throw StateError('srcNonce could not be resolved');
      rec = rec.copyWith(srcNonce: srcNonce);
      _upsert(rec);
    }

    final calldata = EthAbi.verifyAndMint(
      epochId: epoch,
      amountRaw: amountRaw,
      srcNonce: srcNonce,
      ethRecipient: rec.ethAddress,
    );

    _upsert(rec.copyWith(status: BridgeStatus.submitting));
    final hash = await sender.sendCall(
      to: EthConstants.ethereumBridge,
      dataHex: calldata,
      gasLimit: EthConstants.claimGasLimit,
      speed: gasSpeed,
    );
    final ok = await sender.waitForSuccess(hash);
    // ok == true → mined OK; false → reverted; null → not mined within the
    // poll window (still likely confirming — keep it submitting so we don't
    // mislabel a slow-but-valid claim as failed; refresh re-checks the receipt).
    final BridgeStatus status;
    final String? err;
    if (ok == true) {
      status = BridgeStatus.completed;
      err = null;
    } else if (ok == false) {
      status = BridgeStatus.failed;
      err = 'claim reverted on Ethereum';
    } else {
      status = BridgeStatus.submitting;
      err = null;
    }
    final updated = rec.copyWith(claimTxHash: hash, status: status, error: err);
    _upsert(updated);
    await refreshBalances(rec.ethAddress);
    return updated;
  }

  /// Re-checks any claim still [BridgeStatus.submitting] with a known claim tx
  /// hash by reading its Ethereum receipt, advancing it to completed or failed
  /// once the receipt lands. Called from [resumePendingWraps] so a slow claim
  /// that outran its receipt poll is reconciled on the next refresh.
  Future<void> _recheckSubmittingClaims() async {
    final submitting = _history
        .where((r) =>
            r.direction == BridgeDirection.wrap &&
            r.status == BridgeStatus.submitting &&
            r.claimTxHash != null)
        .toList();
    for (final rec in submitting) {
      try {
        final receipt = await _eth.transactionReceipt(rec.claimTxHash!);
        if (receipt == null) continue; // still pending
        final st = receipt['status']?.toString();
        final ok = st == '0x1' || st == '1';
        _upsert(rec.copyWith(
          status: ok ? BridgeStatus.completed : BridgeStatus.failed,
          error: ok ? null : 'claim reverted on Ethereum',
        ));
        if (ok) await refreshBalances(rec.ethAddress);
      } catch (_) {/* leave as submitting; retry next refresh */}
    }
  }

  // ---- UNWRAP (wOCT -> OCT) ------------------------------------------------

  /// approve(bridge, amount) then burn(octraRecipient, amount). OCT is then
  /// released on Octra by the relayer (poll the wallet balance separately).
  Future<BridgeRecord> startUnwrap({
    required EthTxSender sender,
    required String octraRecipient,
    required int microOct,
    GasSpeed gasSpeed = GasSpeed.standard,
  }) async {
    final recip = octraRecipient.trim();
    if (recip.length != 47 || !recip.startsWith('oct')) {
      throw StateError('invalid Octra recipient');
    }
    final amount = BigInt.from(microOct);

    final rec = BridgeRecord(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      direction: BridgeDirection.unwrap,
      amountRaw: microOct.toString(),
      ethAddress: sender.address,
      octraAddress: recip,
      status: BridgeStatus.submitting,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _upsert(rec);

    // 1. approve — must be confirmed before the burn (the burn spends the
    // allowance). A null (timeout) result can't be trusted, so we stop and let
    // the user retry rather than burn against an unconfirmed allowance.
    final approveHash = await sender.sendCall(
      to: EthConstants.wOctToken,
      dataHex: EthAbi.approve(EthConstants.ethereumBridge, amount),
      gasLimit: EthConstants.approveGasLimit,
      speed: gasSpeed,
    );
    final approveOk = await sender.waitForSuccess(approveHash);
    if (approveOk != true) {
      final failed = rec.copyWith(
          approveTxHash: approveHash,
          status: BridgeStatus.failed,
          error: approveOk == false
              ? 'approval reverted on Ethereum'
              : 'approval not confirmed in time — try again');
      _upsert(failed);
      return failed;
    }

    // 2. burn. ok → OCT releasing (pending); false → reverted (failed);
    // null → broadcast but not yet mined — treat as pending (the burn is
    // likely confirming and OCT will release) rather than mislabel as failed.
    final burnHash = await sender.sendCall(
      to: EthConstants.ethereumBridge,
      dataHex: EthAbi.burn(recip, amount),
      gasLimit: EthConstants.burnGasLimit,
      speed: gasSpeed,
    );
    final burnOk = await sender.waitForSuccess(burnHash);
    final updated = rec.copyWith(
      approveTxHash: approveHash,
      burnTxHash: burnHash,
      status: burnOk == false ? BridgeStatus.failed : BridgeStatus.pending,
      error: burnOk == false ? 'burn reverted on Ethereum' : null,
    );
    _upsert(updated);
    await refreshBalances(sender.address);
    return updated;
  }

  // ---- helpers -------------------------------------------------------------

  static String? _extractTxHash(RpcResponse res) {
    final body = res.json;
    dynamic result = body;
    if (body is Map) result = body['result'] ?? body;
    if (result is String && result.isNotEmpty) return result;
    if (result is Map) {
      final h = result['tx_hash'] ?? result['hash'] ?? result['tx'];
      if (h != null) return h.toString();
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    _eth.dispose();
    _relayer.dispose();
    super.dispose();
  }
}
