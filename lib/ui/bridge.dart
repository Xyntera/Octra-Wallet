import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
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

  BridgeDirection _direction = BridgeDirection.wrap;
  final EthWalletStore _store = EthWalletStore();
  final WcService _wc = WcService();
  bool _working = false;
  String? _status;

  EthAccount? get _ethAccount => _store.account;

  /// Builds a transaction sender for the active account, or null if it cannot
  /// sign (no account / watch-only address / WalletConnect not yet paired).
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
    _store.addListener(_onAccountChanged);
    _service.loadHistory();
    _store.load();
  }

  void _onAccountChanged() {
    if (!mounted) return;
    _syncRecipientField();
    final addr = _store.account?.address;
    if (addr != null) _service.refreshBalances(addr);
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
          'Set a WalletConnect project id at build time:\n'
          'flutter build … --dart-define=WC_PROJECT_ID=<id from cloud.reown.com>');
      return;
    }
    final uri = await _wc.beginConnect(
      onConnected: (addr) async {
        await _store.setWalletConnect(addr);
      },
    );
    if (uri.isEmpty || !mounted) return;
    await _showWcSheet(uri);
  }

  Future<void> _showWcSheet(String uri) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
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
              const Text('Connect a wallet',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Scan with MetaMask or another WalletConnect wallet',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13)),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14)),
                child: QrImageView(data: uri, size: 220),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () async {
                    final u = Uri.tryParse(uri);
                    if (u != null) {
                      await launchUrl(u, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text('Open in wallet app'),
                ),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
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
    _service.dispose();
    super.dispose();
  }

  int? _microAmount() {
    final v = double.tryParse(_amountCtrl.text.trim());
    if (v == null || v <= 0) return null;
    return (v * 1000000).round();
  }

  void _onDirectionChanged(BridgeDirection d) {
    setState(() {
      _direction = d;
      _status = null;
      _recipientCtrl.text = d == BridgeDirection.wrap
          ? (_ethAccount?.address ?? '')
          : (_wallet.currentWallet?.address ?? '');
    });
  }

  Future<void> _submit() async {
    final micro = _microAmount();
    if (micro == null) {
      setState(() => _status = 'Enter a valid amount.');
      return;
    }
    if (micro < EthConstants.minWrapMicroOct &&
        _direction == BridgeDirection.wrap) {
      setState(() => _status = 'Minimum is 1 OCT.');
      return;
    }
    final recipient = _recipientCtrl.text.trim();
    setState(() {
      _working = true;
      _status = null;
    });
    try {
      if (_direction == BridgeDirection.wrap) {
        if (!EthAccount.isValidAddress(recipient)) {
          throw StateError('Enter a valid Ethereum recipient.');
        }
        final rec = await _service.startWrap(
          ethRecipient: recipient,
          microOct: micro,
        );
        setState(() => _status =
            'Locked OCT (${_short(rec.lockTxHash)}). Waiting for the epoch — '
            'this can take ~30–40 min. Then claim from history.');
        unawaited(_service.prepareClaim(rec).then((r) {
          if (mounted) {
            setState(() => _status = 'Ready to claim wOCT in history.');
          }
        }).catchError((_) {/* stays pending in history */}));
      } else {
        final sender = _senderFor(_ethAccount);
        if (sender == null) {
          throw StateError(
              'Unwrap needs an Ethereum account that can sign. Tap Manage to '
              'create, import, or connect one.');
        }
        if (recipient.length != 47 || !recipient.startsWith('oct')) {
          throw StateError('Enter a valid Octra recipient.');
        }
        try {
          await _service.startUnwrap(
            sender: sender,
            octraRecipient: recipient,
            microOct: micro,
          );
        } finally {
          sender.dispose();
        }
        setState(() => _status =
            'Burned wOCT. OCT will be released to your Octra address shortly.');
      }
    } catch (e) {
      setState(() => _status = _clean(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _claim(BridgeRecord rec) async {
    final sender = _senderFor(_ethAccount);
    if (sender == null) {
      setState(() =>
          _status = 'Set up a signing Ethereum account to claim (Manage).');
      return;
    }
    setState(() => _working = true);
    try {
      await _service.claim(rec, sender);
      setState(() => _status = 'Claimed wOCT.');
    } catch (e) {
      setState(() => _status = _clean(e));
    } finally {
      sender.dispose();
      if (mounted) setState(() => _working = false);
    }
  }

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
          return const Text('No bridge activity yet.',
              style: TextStyle(color: Color(0xFF636366), fontSize: 13));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('History',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._service.history.map(_historyTile),
          ],
        );
      },
    );
  }

  Widget _historyTile(BridgeRecord r) {
    final isWrap = r.direction == BridgeDirection.wrap;
    final canClaim = isWrap &&
        r.status == BridgeStatus.claimable &&
        (_ethAccount?.canSign ?? false);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${isWrap ? 'Wrap' : 'Unwrap'}  ${_micro(BigInt.parse(r.amountRaw))}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(r.status.name,
                    style: const TextStyle(
                        color: Color(0xFF8E8E93), fontSize: 12)),
              ],
            ),
          ),
          if (canClaim)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              color: const Color(0xFF0A84FF),
              borderRadius: BorderRadius.circular(8),
              onPressed: _working ? null : () => _claim(r),
              child: const Text('Claim', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  static String _short(String? s) =>
      (s == null || s.length < 12) ? (s ?? '') : '${s.substring(0, 6)}…${s.substring(s.length - 4)}';

  static String _micro(BigInt raw) =>
      (raw.toDouble() / 1000000.0).toStringAsFixed(6);

  static String _wei(BigInt wei) => (wei.toDouble() / 1e18).toStringAsFixed(5);

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('StateError: ', '')
      .replaceFirst('Exception: ', '');
}
