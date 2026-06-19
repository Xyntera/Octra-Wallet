import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../eth/bridge_models.dart';
import '../eth/bridge_service.dart';
import '../eth/eth_account.dart';
import '../eth/eth_constants.dart';
import '../eth/eth_tx_sender.dart';
import '../eth/eth_wallet_store.dart';
import '../eth/eth_walletconnect.dart';
import '../wallet.dart';
import 'eth_account_sheet.dart';

/// OCT <-> wOCT bridge screen. Experimental: moves real mainnet funds.
class BridgeScreen extends StatefulWidget {
  const BridgeScreen({super.key});

  @override
  State<BridgeScreen> createState() => _BridgeScreenState();
}

class _BridgeScreenState extends State<BridgeScreen> {
  late final WalletController _wallet;
  late final BridgeService _service;
  final _amountCtrl = TextEditingController();
  final _recipientCtrl = TextEditingController();
  final _txHashCtrl = TextEditingController();

  BridgeDirection _direction = BridgeDirection.wrap;
  late final EthWalletStore _store;
  final WcService _wc = WcService();
  bool _working = false;
  String? _status;

  EthAccount? get _ethAccount => _store.account;

  EthTxSender? _senderFor(EthAccount? acc) {
    if (acc == null) return null;
    if (acc.mode == EthAccountMode.walletConnect) {
      return _wc.isConnected ? WalletConnectSender(_wc) : null;
    }
    return acc.canSign ? LocalEthSender(acc) : null;
  }

  @override
  void initState() {
    super.initState();
    _wallet = context.read<WalletController>();
    _service = BridgeService(wallet: _wallet);
    _store = context.read<EthWalletStore>();
    _store.addListener(_onAccountChanged);
    _service.loadHistory();
  }

  void _onAccountChanged() {
    if (!mounted) return;
    _syncRecipientField();
    final addr = _store.account?.address;
    if (addr != null) {
      _service.refreshBalances(addr);
      unawaited(_service.resumePendingWraps(addr));
      unawaited(_store.refreshBalances());
    }
    setState(() {});
  }

  void _syncRecipientField() {
    _recipientCtrl.text = _direction == BridgeDirection.wrap
        ? (_ethAccount?.address ?? '')
        : (_wallet.currentWallet?.address ?? '');
  }

  Future<void> _manageAccount() async {
    await Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) =>
          buildEthAccountScreen(_store, onConnect: _connectWalletConnect),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _connectWalletConnect() async {
    if (!_wc.isConfigured) {
      _showInfo('WalletConnect',
          'WalletConnect project id is not configured.');
      return;
    }
    final uri = await _wc.beginConnect(
      onConnected: (addr) async {
        await _store.setWalletConnect(addr);
        await _store.refreshBalances();
      },
    );
    if (uri.isEmpty || !mounted) return;
    await _showWalletPickerSheet(uri);
  }

  // List of popular EVM wallets for the picker
  static const _evmWallets = [
    _WalletInfo('MetaMask',    Color(0xFFF6851B), 'M',  'metamask://wc?uri=',        'https://metamask.app.link/wc?uri='),
    _WalletInfo('Trust',       Color(0xFF3375BB), 'T',  'trust://wc?uri=',           'https://link.trustwallet.com/wc?uri='),
    _WalletInfo('Coinbase',    Color(0xFF1652F0), 'C',  'cbwallet://wc?uri=',        'https://go.cb-w.com/wc?uri='),
    _WalletInfo('Rainbow',     Color(0xFF032BEE), 'R',  'rainbow://wc?uri=',         'https://rnbwapp.com/wc?uri='),
    _WalletInfo('1inch',       Color(0xFFE62B57), '1',  'oneinch-wallet://wc?uri=',  null),
    _WalletInfo('Zerion',      Color(0xFF2962FF), 'Z',  'zerion://wc?uri=',          null),
    _WalletInfo('OKX',         Color(0xFF1A1A1A), 'OK', 'okx://wc?uri=',             null),
    _WalletInfo('Phantom',     Color(0xFF4E44CE), 'P',  'phantom://wc?uri=',         null),
  ];

  Future<void> _showWalletPickerSheet(String wcUri) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _WalletPickerSheet(wcUri: wcUri),
    );
  }

  void _showInfo(String title, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _store.removeListener(_onAccountChanged);
    _amountCtrl.dispose();
    _recipientCtrl.dispose();
    _txHashCtrl.dispose();
    _service.dispose();
    super.dispose();
  }

  int? _microAmount() => _parseMicro(_amountCtrl.text, 6);

  static int? _parseMicro(String input, int decimals) {
    final s = input.trim();
    if (s.isEmpty || s == '.') return null;
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(s)) return null;
    final parts = s.split('.');
    final whole = parts[0].isEmpty ? '0' : parts[0];
    var frac = parts.length > 1 ? parts[1] : '';
    if (frac.length > decimals) return null;
    frac = frac.padRight(decimals, '0');
    final micro = int.tryParse('$whole$frac');
    if (micro == null || micro <= 0) return null;
    return micro;
  }

  Future<bool?> _confirm(String title, String message) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message, style: const TextStyle(fontSize: 13)),
        ),
        actions: [
          CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm')),
        ],
      ),
    );
  }

  // ---- gas tier picker ------------------------------------------------------

  /// Shows a modal bottom sheet for selecting Ethereum gas speed.
  /// Fetches current gas price to display estimated fees.
  /// Returns null if the user cancels.
  Future<GasSpeed?> _pickGasSpeed({required int gasLimit}) async {
    BigInt? gasPrice;
    try {
      gasPrice = await _service.currentGasPrice();
    } catch (_) {}

    if (!mounted) return null;

    return showCupertinoModalPopup<GasSpeed>(
      context: context,
      builder: (ctx) => _GasSpeedSheet(
        gasLimit: gasLimit,
        gasPrice: gasPrice,
      ),
    );
  }

  // ---- manual refresh -------------------------------------------------------

  Future<void> _refreshPending() async {
    final addr = _ethAccount?.address;
    if (addr == null) {
      setState(() => _status = 'Set up an Ethereum account first.');
      return;
    }
    setState(() {
      _working = true;
      _status = 'Checking relayer for claimable wraps…';
    });
    try {
      await _service.resumePendingWraps(addr);
      if (mounted) {
        setState(() => _status = null);
      }
    } catch (e) {
      if (mounted) setState(() => _status = _clean(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // ---- direction ------------------------------------------------------------

  void _onDirectionChanged(BridgeDirection d) {
    setState(() {
      _direction = d;
      _status = null;
      _recipientCtrl.text = d == BridgeDirection.wrap
          ? (_ethAccount?.address ?? '')
          : (_wallet.currentWallet?.address ?? '');
    });
  }

  // ---- submit ---------------------------------------------------------------

  Future<void> _submit() async {
    final micro = _microAmount();
    if (micro == null) {
      setState(() => _status = 'Enter a valid amount (max 6 decimals).');
      return;
    }
    if (_direction == BridgeDirection.wrap &&
        micro < EthConstants.minWrapMicroOct) {
      setState(() => _status = 'Minimum is 1 OCT.');
      return;
    }
    final recipient = _recipientCtrl.text.trim();
    try {
      if (_direction == BridgeDirection.wrap) {
        if (!EthAccount.isValidAddress(recipient)) {
          throw StateError('Enter a valid Ethereum recipient.');
        }
        final lockFee = int.tryParse(EthConstants.lockOu) ?? 1000;
        final availMicro = (_wallet.publicBalance * 1000000).round();
        if (micro + lockFee > availMicro) {
          throw StateError('Insufficient OCT balance — need '
              '${_microInt(micro + lockFee)} OCT incl. fee, have '
              '${_microInt(availMicro)}.');
        }
        if (!mounted) return;
        final ok = await _confirm(
            'Confirm wrap',
            'Lock ${_microInt(micro)} OCT and mint wOCT to:\n$recipient\n\n'
            'Real mainnet funds — this cannot be undone.');
        if (ok != true) return;

        setState(() {
          _working = true;
          _status = null;
        });
        final rec =
            await _service.startWrap(ethRecipient: recipient, microOct: micro);
        setState(() => _status =
            'Locked OCT (${_short(rec.lockTxHash)}). Waiting for epoch — '
            '~30–40 min. The Claim button will appear in history automatically.');
        unawaited(_service.prepareClaim(rec).then((r) {
          if (mounted) {
            setState(() => _status = 'Ready to claim wOCT — see history.');
          }
        }).catchError((_) {/* stays pending; resumePendingWraps will catch it */}));
      } else {
        // Unwrap: pick gas speed first, then confirm.
        final sender = _senderFor(_ethAccount);
        if (sender == null) {
          throw StateError(
              'Unwrap needs an Ethereum account that can sign. Tap Manage to '
              'create, import, or connect one.');
        }
        try {
          if (recipient.length != 47 || !recipient.startsWith('oct')) {
            throw StateError('Enter a valid Octra recipient.');
          }
          await _service.refreshBalances(sender.address);
          if (BigInt.from(micro) > _service.woctBalanceRaw) {
            throw StateError('Insufficient wOCT balance — have '
                '${_micro(_service.woctBalanceRaw)}.');
          }
          if (!mounted) return;
          final speed = await _pickGasSpeed(
              gasLimit: EthConstants.approveGasLimit + EthConstants.burnGasLimit);
          if (speed == null) return;

          if (!mounted) return;
          final ok = await _confirm(
              'Confirm unwrap',
              'Burn ${_microInt(micro)} wOCT and release OCT to:\n$recipient\n\n'
              'Sends two Ethereum transactions (approve + burn). '
              'Gas: ${speed.label} (${speed.timing}).');
          if (ok != true) return;

          setState(() {
            _working = true;
            _status = null;
          });
          await _service.startUnwrap(
            sender: sender,
            octraRecipient: recipient,
            microOct: micro,
            gasSpeed: speed,
          );
          setState(() => _status =
              'Burned wOCT. OCT will be released to your Octra address shortly.');
        } finally {
          sender.dispose();
        }
      }
    } catch (e) {
      setState(() => _status = _clean(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // ---- claim ----------------------------------------------------------------

  Future<void> _claim(BridgeRecord rec) async {
    final sender = _senderFor(_ethAccount);
    if (sender == null) {
      setState(() =>
          _status = 'Set up a signing Ethereum account to claim (Manage).');
      return;
    }
    try {
      final speed =
          await _pickGasSpeed(gasLimit: EthConstants.claimGasLimit);
      if (speed == null) return;

      final amount = BigInt.tryParse(rec.amountRaw) ?? BigInt.zero;
      final ok = await _confirm('Claim wOCT',
          'Submit the Ethereum claim for ${_micro(amount)} wOCT.\n'
          'Gas: ${speed.label} (${speed.timing}).');
      if (ok != true) return;
      setState(() => _working = true);
      await _service.claim(rec, sender, gasSpeed: speed);
      setState(() => _status = 'Claimed wOCT!');
    } catch (e) {
      setState(() => _status = _clean(e));
    } finally {
      sender.dispose();
      if (mounted) setState(() => _working = false);
    }
  }

  // ---- claim by lock tx hash ------------------------------------------------

  Future<void> _showClaimByTxSheet() async {
    _txHashCtrl.clear();
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _ClaimByTxSheet(
        ctrl: _txHashCtrl,
        onLookup: (hash) async {
          Navigator.of(ctx).pop();
          await _lookupAndClaim(hash);
        },
      ),
    );
  }

  Future<void> _lookupAndClaim(String lockTxHash) async {
    if (lockTxHash.trim().isEmpty) return;
    setState(() {
      _working = true;
      _status = 'Looking up tx in recovery feed…';
    });
    try {
      final rec = await _service.importByLockTxHash(lockTxHash.trim());
      if (rec == null) {
        setState(() => _status =
            'Tx not found in the recovery feed. '
            'The lock may still be processing — try again after ~30–40 min.');
        return;
      }
      if (rec.status == BridgeStatus.claimable) {
        setState(() => _status = 'Wrap found and ready to claim — see history.');
      } else if (rec.status == BridgeStatus.completed) {
        setState(() => _status = 'This wrap has already been claimed.');
      } else {
        setState(() => _status =
            'Wrap found but the Ethereum header is not yet live. '
            'Come back after the epoch finalizes (~30–40 min).');
      }
    } catch (e) {
      setState(() => _status = _clean(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // ---- helpers --------------------------------------------------------------

  static String _microInt(int micro) =>
      (micro / 1000000.0).toStringAsFixed(6);

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Bridge · OCT ⇄ wOCT · Beta'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _betaBanner(),
            const SizedBox(height: 16),
            CupertinoSlidingSegmentedControl<BridgeDirection>(
              groupValue: _direction,
              onValueChanged: (v) {
                if (v != null) _onDirectionChanged(v);
              },
              children: const {
                BridgeDirection.wrap: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Wrap  OCT→wOCT'),
                ),
                BridgeDirection.unwrap: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Unwrap  wOCT→OCT'),
                ),
              },
            ),
            const SizedBox(height: 20),
            _ethAccountCard(),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              placeholder: 'Amount (OCT)',
              padding: const EdgeInsets.all(14),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _recipientCtrl,
              placeholder: _direction == BridgeDirection.wrap
                  ? 'Ethereum recipient (0x…)'
                  : 'Octra recipient (oct…)',
              padding: const EdgeInsets.all(14),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 18),
            CupertinoButton.filled(
              onPressed: _working ? null : _submit,
              child: _working
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : Text(_direction == BridgeDirection.wrap
                      ? 'Lock OCT'
                      : 'Burn wOCT'),
            ),
            if (_status != null) ...[
              const SizedBox(height: 14),
              Text(_status!,
                  style:
                      const TextStyle(color: Color(0xFF8E8E93), fontSize: 13)),
            ],
            const SizedBox(height: 8),
            const Text('Fee: 0 · 1:1 · ~30–40 min to finalize a wrap',
                style: TextStyle(color: Color(0xFF636366), fontSize: 12)),
            const SizedBox(height: 24),
            _historySection(),
          ],
        ),
      ),
    );
  }

  Widget _betaBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9F0A).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFFF9F0A).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle_fill,
              color: Color(0xFFFF9F0A), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Beta · Ethereum mainnet. This bridge moves real funds and has not '
              'been fully tested end-to-end — try a tiny amount first.',
              style: TextStyle(
                  color: Color(0xFFFFD60A), fontSize: 12.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ethAccountCard() {
    return AnimatedBuilder(
      animation: _service,
      builder: (_, __) {
        final acc = _ethAccount;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.bitcoin_circle,
                      size: 18, color: Color(0xFF8E8E93)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      acc == null
                          ? 'No Ethereum account set up'
                          : '${_modeLabel(acc.mode)} · ${_short(acc.address)}',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    minSize: 0,
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: _manageAccount,
                    child: Text(acc == null ? 'Set up' : 'Manage',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              if (acc != null) ...[
                const SizedBox(height: 10),
                Text('ETH ${_wei(_service.ethBalanceWei)}   ·   '
                    'wOCT ${_micro(_service.woctBalanceRaw)}',
                    style: const TextStyle(
                        color: Color(0xFF8E8E93), fontSize: 12)),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _modeLabel(EthAccountMode mode) => switch (mode) {
        EthAccountMode.derived => 'Seed wallet',
        EthAccountMode.imported => 'Imported key',
        EthAccountMode.walletConnect => 'WalletConnect',
        EthAccountMode.manual => 'Watch address',
      };

  Widget _historySection() {
    return AnimatedBuilder(
      animation: _service,
      builder: (_, __) {
        if (_service.history.isEmpty) {
          return _emptyHistory();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('History',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: _working ? null : _refreshPending,
                  child: const Text('Refresh',
                      style:
                          TextStyle(color: Color(0xFF0A84FF), fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._service.history.map(_historyTile),
            const SizedBox(height: 12),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: _working ? null : _showClaimByTxSheet,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.search, size: 14,
                      color: Color(0xFF636366)),
                  SizedBox(width: 6),
                  Text('Recover by lock TX hash',
                      style: TextStyle(
                          color: Color(0xFF636366), fontSize: 12)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyHistory() {
    return Column(
      children: [
        const Text('No bridge activity yet.',
            style: TextStyle(color: Color(0xFF636366), fontSize: 13)),
        const SizedBox(height: 8),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: _working ? null : _showClaimByTxSheet,
          child: const Text('Have a lock TX? Recover it here.',
              style: TextStyle(color: Color(0xFF0A84FF), fontSize: 13)),
        ),
      ],
    );
  }

  Widget _historyTile(BridgeRecord r) {
    final isWrap = r.direction == BridgeDirection.wrap;
    final canClaim = isWrap &&
        r.status == BridgeStatus.claimable &&
        (_ethAccount?.canSign ?? false);

    final statusColor = switch (r.status) {
      BridgeStatus.completed => const Color(0xFF30D158),
      BridgeStatus.failed => const Color(0xFFFF453A),
      BridgeStatus.claimable => const Color(0xFFFF9F0A),
      BridgeStatus.submitting => const Color(0xFF0A84FF),
      BridgeStatus.pending => const Color(0xFF8E8E93),
    };

    final statusLabel = switch (r.status) {
      BridgeStatus.claimable => 'Ready to claim',
      BridgeStatus.pending =>
        r.epoch != null ? 'Pending · epoch ${r.epoch}' : 'Pending',
      BridgeStatus.submitting => 'Submitting…',
      BridgeStatus.completed => 'Completed',
      BridgeStatus.failed =>
        'Failed${r.error != null ? ': ${r.error}' : ''}',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(10),
        border: r.status == BridgeStatus.claimable
            ? Border.all(
                color: const Color(0xFFFF9F0A).withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    '${isWrap ? 'Wrap' : 'Unwrap'}  '
                    '${_micro(BigInt.tryParse(r.amountRaw) ?? BigInt.zero)}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500)),
              ),
              if (canClaim)
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: const Color(0xFF0A84FF),
                  borderRadius: BorderRadius.circular(8),
                  minSize: 0,
                  onPressed: _working ? null : () => _claim(r),
                  child:
                      const Text('Claim', style: TextStyle(fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(statusLabel,
              style: TextStyle(color: statusColor, fontSize: 12)),
          if (r.lockTxHash != null) ...[
            const SizedBox(height: 2),
            Text('Lock: ${_short(r.lockTxHash)}',
                style: const TextStyle(
                    color: Color(0xFF636366), fontSize: 11)),
          ],
          if (r.claimTxHash != null) ...[
            const SizedBox(height: 2),
            Text('Claim tx: ${_short(r.claimTxHash)}',
                style: const TextStyle(
                    color: Color(0xFF636366), fontSize: 11)),
          ],
        ],
      ),
    );
  }

  static String _short(String? s) => (s == null || s.length < 12)
      ? (s ?? '')
      : '${s.substring(0, 6)}…${s.substring(s.length - 4)}';

  static String _micro(BigInt raw) =>
      (raw.toDouble() / 1000000.0).toStringAsFixed(6);

  static String _wei(BigInt wei) =>
      (wei.toDouble() / 1e18).toStringAsFixed(5);

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('StateError: ', '')
      .replaceFirst('Exception: ', '');
}

// ---------------------------------------------------------------------------
// Gas speed picker sheet (stateful for selection highlighting)
// ---------------------------------------------------------------------------

class _GasSpeedSheet extends StatefulWidget {
  final int gasLimit;
  final BigInt? gasPrice;

  const _GasSpeedSheet({required this.gasLimit, this.gasPrice});

  @override
  State<_GasSpeedSheet> createState() => _GasSpeedSheetState();
}

class _GasSpeedSheetState extends State<_GasSpeedSheet> {
  GasSpeed _selected = GasSpeed.standard;

  String _feeLabel(GasSpeed speed) {
    final gp = widget.gasPrice;
    if (gp == null) return '';
    final scaled =
        (gp.toDouble() * speed.multiplierX10 / 10) * widget.gasLimit;
    final eth = scaled / 1e18;
    return '~${eth.toStringAsFixed(5)} ETH';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFF48484A),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Gas Speed',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
                'Higher speed = higher fee = faster Ethereum confirmation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
            const SizedBox(height: 16),
            for (final speed in GasSpeed.values) _tile(speed),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: const Text('Continue'),
              ),
            ),
            CupertinoButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(GasSpeed speed) {
    final isSelected = speed == _selected;
    final fee = _feeLabel(speed);
    return GestureDetector(
      onTap: () => setState(() => _selected = speed),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0A84FF).withValues(alpha: 0.15)
              : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF0A84FF)
                  : Colors.transparent),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(speed.label,
                      style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF0A84FF)
                              : Colors.white,
                          fontWeight: FontWeight.w600)),
                  Text(speed.timing,
                      style: const TextStyle(
                          color: Color(0xFF8E8E93), fontSize: 12)),
                ],
              ),
            ),
            if (fee.isNotEmpty)
              Text(fee,
                  style: const TextStyle(
                      color: Color(0xFF8E8E93), fontSize: 12)),
            const SizedBox(width: 10),
            Icon(
              isSelected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: isSelected
                  ? const Color(0xFF0A84FF)
                  : const Color(0xFF636366),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EVM wallet deep-link info ────────────────────────────────────────────────
class _WalletInfo {
  final String name;
  final Color color;
  final String letter;
  final String schemePrefix;
  final String? universalPrefix;
  const _WalletInfo(this.name, this.color, this.letter, this.schemePrefix, this.universalPrefix);
}

// ─── WalletConnect wallet picker sheet ────────────────────────────────────────
class _WalletPickerSheet extends StatefulWidget {
  final String wcUri;
  const _WalletPickerSheet({required this.wcUri});
  @override
  State<_WalletPickerSheet> createState() => _WalletPickerSheetState();
}

class _WalletPickerSheetState extends State<_WalletPickerSheet> {
  bool _showQr = false;

  Future<void> _openWallet(_WalletInfo info) async {
    final encoded = Uri.encodeComponent(widget.wcUri);
    final urls = [
      if (info.universalPrefix != null) '${info.universalPrefix}$encoded',
      '${info.schemePrefix}$encoded',
    ];
    for (final raw in urls) {
      final uri = Uri.tryParse(raw);
      if (uri == null) continue;
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return;
      } catch (_) {}
    }
    if (mounted) setState(() => _showQr = true);
  }

  Future<void> _copyUri() async {
    await Clipboard.setData(ClipboardData(text: widget.wcUri));
    if (mounted) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFF48484A), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              // header
              const Text('Connect EVM Wallet', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Choose a wallet app to connect', textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13.5)),
              const SizedBox(height: 24),
              if (!_showQr) ...[
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _BridgeScreenState._evmWallets.length,
                  itemBuilder: (_, i) => _WalletTile(
                    info: _BridgeScreenState._evmWallets[i],
                    onTap: () => _openWallet(_BridgeScreenState._evmWallets[i]),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => setState(() => _showQr = true),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.qrcode, color: Color(0xFF8E8E93), size: 20),
                        SizedBox(width: 8),
                        Text('Scan QR Code', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: () => setState(() => _showQr = false),
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.chevron_left, color: Color(0xFF0A84FF), size: 16),
                      SizedBox(width: 4),
                      Text('Back to wallets', style: TextStyle(color: Color(0xFF0A84FF), fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Scan with any WalletConnect wallet', textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13)),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: QrImageView(data: widget.wcUri, size: 200),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _copyUri,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF3A3A3C)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.link, color: Color(0xFF8E8E93), size: 16),
                      SizedBox(width: 8),
                      Text('Copy connection link', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletTile extends StatelessWidget {
  final _WalletInfo info;
  final VoidCallback onTap;
  const _WalletTile({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: info.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: info.color.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Center(
              child: Text(
                info.letter,
                style: TextStyle(
                  color: info.color,
                  fontSize: info.letter.length > 1 ? 13 : 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            info.name,
            style: const TextStyle(color: Color(0xFFAEAEB2), fontSize: 11.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Claim-by-lock-TX-hash sheet
// ---------------------------------------------------------------------------

class _ClaimByTxSheet extends StatelessWidget {
  final TextEditingController ctrl;
  final void Function(String) onLookup;

  const _ClaimByTxSheet({required this.ctrl, required this.onLookup});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFF48484A),
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('Recover by Lock TX Hash',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
                'Enter the Octra transaction hash from your wrap (lock). '
                'The app will search the bridge relay and surface the Claim button.',
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: ctrl,
              placeholder: 'Lock TX hash (64 hex chars or 0x…)',
              placeholderStyle: const TextStyle(color: Color(0xFF636366)),
              padding: const EdgeInsets.all(14),
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
              autocorrect: false,
              enableSuggestions: false,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: () => onLookup(ctrl.text.trim()),
                child: const Text('Look up'),
              ),
            ),
            CupertinoButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
