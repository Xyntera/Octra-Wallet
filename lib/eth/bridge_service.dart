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
import 'eth_signer.dart';

/// Orchestrates the OCT <-> wOCT bridge: builds/submits the Octra lock, drives
/// the relayer claim flow on Ethereum (wrap), and the approve/burn flow
/// (unwrap), persisting history so claims can be resumed.
///
/// Experimental — handles mainnet funds. Test with minimal amounts.
class BridgeService extends ChangeNotifier {
  final WalletController wallet;
  final EthRpc _eth;
  final BridgeRelayer _relayer;
  final EthSigner _signer;
  final FlutterSecureStorage _storage;

  static const _historyKey = 'bridge_history';

  final List<BridgeRecord> _history = [];
  List<BridgeRecord> get history => List.unmodifiable(_history);

  BigInt ethBalanceWei = BigInt.zero;
  BigInt woctBalanceRaw = BigInt.zero;
  bool busy = false;

  BridgeService({
    required this.wallet,
    EthRpc? eth,
    BridgeRelayer? relayer,
    EthSigner? signer,
    FlutterSecureStorage? storage,
  })  : _eth = eth ?? EthRpc(),
        _relayer = relayer ?? BridgeRelayer(),
        _signer = signer ?? EthSigner(),
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
    notifyListeners();
  }

  // ---- balances ------------------------------------------------------------

  Future<void> refreshBalances(String ethAddress) async {
    if (!EthAccount.isValidAddress(ethAddress)) return;
    try {
      ethBalanceWei = await _eth.ethBalanceWei(ethAddress);
      woctBalanceRaw = await _eth.woctBalance(ethAddress);
      notifyListeners();
    } catch (_) {/* surfaced by callers */}
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

  /// Step 3: claim wOCT on Ethereum (derived-account signing). The relayer's
  /// opaque calldata is fetched fresh and submitted to the bridge.
  Future<BridgeRecord> claim(BridgeRecord rec, EthAccount account) async {
    if (!account.canSign) {
      throw StateError('connect or derive an Ethereum account to claim');
    }
    final epoch = rec.epoch;
    if (epoch == null) throw StateError('record has no epoch');
    final calldata =
        await _relayer.claimCalldataForRecipient(epoch, rec.ethAddress);
    if (calldata == null) throw StateError('claim calldata unavailable');

    _upsert(rec.copyWith(status: BridgeStatus.submitting));
    final hash = await _signer.sendCall(
      account: account,
      to: EthConstants.ethereumBridge,
      dataHex: calldata,
      gasLimit: EthConstants.claimGasLimit,
    );
    final ok = await _signer.waitForSuccess(hash);
    final updated = rec.copyWith(
      claimTxHash: hash,
      status: ok == true ? BridgeStatus.completed : BridgeStatus.failed,
      error: ok == true ? null : 'claim not confirmed',
    );
    _upsert(updated);
    await refreshBalances(rec.ethAddress);
    return updated;
  }

  // ---- UNWRAP (wOCT -> OCT) ------------------------------------------------

  /// approve(bridge, amount) then burn(octraRecipient, amount). OCT is then
  /// released on Octra by the relayer (poll the wallet balance separately).
  Future<BridgeRecord> startUnwrap({
    required EthAccount account,
    required String octraRecipient,
    required int microOct,
  }) async {
    if (!account.canSign) {
      throw StateError('connect or derive an Ethereum account to unwrap');
    }
    final recip = octraRecipient.trim();
    if (recip.length != 47 || !recip.startsWith('oct')) {
      throw StateError('invalid Octra recipient');
    }
    final amount = BigInt.from(microOct);

    final rec = BridgeRecord(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      direction: BridgeDirection.unwrap,
      amountRaw: microOct.toString(),
      ethAddress: account.address,
      octraAddress: recip,
      status: BridgeStatus.submitting,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _upsert(rec);

    // 1. approve
    final approveHash = await _signer.sendCall(
      account: account,
      to: EthConstants.wOctToken,
      dataHex: EthAbi.approve(EthConstants.ethereumBridge, amount),
      gasLimit: EthConstants.approveGasLimit,
    );
    if (await _signer.waitForSuccess(approveHash) != true) {
      final failed = rec.copyWith(
          approveTxHash: approveHash,
          status: BridgeStatus.failed,
          error: 'approve not confirmed');
      _upsert(failed);
      return failed;
    }

    // 2. burn
    final burnHash = await _signer.sendCall(
      account: account,
      to: EthConstants.ethereumBridge,
      dataHex: EthAbi.burn(recip, amount),
      gasLimit: EthConstants.burnGasLimit,
    );
    final burnOk = await _signer.waitForSuccess(burnHash);
    final updated = rec.copyWith(
      approveTxHash: approveHash,
      burnTxHash: burnHash,
      status: burnOk == true ? BridgeStatus.pending : BridgeStatus.failed,
      error: burnOk == true ? null : 'burn not confirmed',
    );
    _upsert(updated);
    await refreshBalances(account.address);
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
    _eth.dispose();
    _relayer.dispose();
    _signer.dispose();
    super.dispose();
  }
}
