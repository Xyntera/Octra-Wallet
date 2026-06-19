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

// ─────────────────────────────────────────────────────────────────────────────
//  Bridge screen — OCT ↔ wOCT
// ─────────────────────────────────────────────────────────────────────────────

class BridgeScreen extends StatefulWidget {
  const BridgeScreen({super.key});
  @override
  State<BridgeScreen> createState() => _BridgeScreenState();
}

class _BridgeScreenState extends State<BridgeScreen> {
  late final WalletController _wallet;
  late final BridgeService _service;
  late final EthWalletStore _store;
  final _amountCtrl = TextEditingController();
  final _recipientCtrl = TextEditingController();
  final _txHashCtrl = TextEditingController();
  final WcService _wc = WcService();

  BridgeDirection _direction = BridgeDirection.wrap;
  bool _working = false;
  // null = no message; String = shown in status banner
  String? _status;
  // Track whether the last status is good/bad for banner type
  _StatusType _statusType = _StatusType.info;

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

  @override
  void dispose() {
    _store.removeListener(_onAccountChanged);
    _amountCtrl.dispose();
    _recipientCtrl.dispose();
    _txHashCtrl.dispose();
    _service.dispose();
    super.dispose();
  }

  // ── account management ──────────────────────────────────────────────────────

  Future<void> _manageAccount() async {
    await Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) =>
          buildEthAccountScreen(_store, onConnect: _connectWalletConnect),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _connectWalletConnect() async {
    if (!_wc.isConfigured) {
      _showInfo('WalletConnect', 'WalletConnect is not configured.');
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

  static const _evmWallets = [
    _WalletInfo('MetaMask', Color(0xFFF6851B), 'M', 'metamask://wc?uri=', 'https://metamask.app.link/wc?uri='),
    _WalletInfo('Trust',    Color(0xFF3375BB), 'T', 'trust://wc?uri=',    'https://link.trustwallet.com/wc?uri='),
    _WalletInfo('Coinbase', Color(0xFF1652F0), 'C', 'cbwallet://wc?uri=', 'https://go.cb-w.com/wc?uri='),
    _WalletInfo('Rainbow',  Color(0xFF032BEE), 'R', 'rainbow://wc?uri=',  'https://rnbwapp.com/wc?uri='),
    _WalletInfo('1inch',    Color(0xFFE62B57), '1', 'oneinch-wallet://wc?uri=', null),
    _WalletInfo('Zerion',   Color(0xFF2962FF), 'Z', 'zerion://wc?uri=',   null),
    _WalletInfo('OKX',      Color(0xFF1A1A1A), 'OK','okx://wc?uri=',      null),
    _WalletInfo('Phantom',  Color(0xFF4E44CE), 'P', 'phantom://wc?uri=',  null),
  ];

  Future<void> _showWalletPickerSheet(String wcUri) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _WalletPickerSheet(wcUri: wcUri),
    );
  }

  // ── helpers ─────────────────────────────────────────────────────────────────

  void _setStatus(String msg, _StatusType type) {
    if (mounted) setState(() { _status = msg; _statusType = type; });
  }

  void _clearStatus() {
    if (mounted) setState(() => _status = null);
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
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // ── gas speed picker ────────────────────────────────────────────────────────

  Future<GasSpeed?> _pickGasSpeed({required int gasLimit}) async {
    BigInt? gasPrice;
    try { gasPrice = await _service.currentGasPrice(); } catch (_) {}
    if (!mounted) return null;
    return showCupertinoModalPopup<GasSpeed>(
      context: context,
      builder: (_) => _GasSpeedSheet(gasLimit: gasLimit, gasPrice: gasPrice),
    );
  }

  // ── refresh pending ─────────────────────────────────────────────────────────

  Future<void> _refreshPending() async {
    final addr = _ethAccount?.address;
    if (addr == null) {
      _setStatus('Set up an Ethereum account first.', _StatusType.warning);
      return;
    }
    setState(() { _working = true; });
    _clearStatus();
    try {
      await _service.resumePendingWraps(addr);
    } catch (e) {
      _setStatus(_friendlyError(e), _StatusType.error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // ── direction ───────────────────────────────────────────────────────────────

  void _onDirectionChanged(BridgeDirection d) {
    setState(() {
      _direction = d;
      _status = null;
      _recipientCtrl.text = d == BridgeDirection.wrap
          ? (_ethAccount?.address ?? '')
          : (_wallet.currentWallet?.address ?? '');
    });
  }

  // ── submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final micro = _microAmount();
    if (micro == null) {
      _setStatus('Enter a valid amount (up to 6 decimals).', _StatusType.error);
      return;
    }
    if (_direction == BridgeDirection.wrap && micro < EthConstants.minWrapMicroOct) {
      _setStatus('Minimum wrap amount is 1 OCT.', _StatusType.error);
      return;
    }
    final recipient = _recipientCtrl.text.trim();
    try {
      if (_direction == BridgeDirection.wrap) {
        if (!EthAccount.isValidAddress(recipient)) {
          _setStatus('Invalid Ethereum address — double-check and try again.', _StatusType.error);
          return;
        }
        final lockFee = int.tryParse(EthConstants.lockOu) ?? 1000;
        final availMicro = (_wallet.publicBalance * 1000000).round();
        if (micro + lockFee > availMicro) {
          _setStatus(
            'Not enough OCT. Need ${_microClean(BigInt.from(micro + lockFee))} '
            'OCT (incl. fee), have ${_microClean(BigInt.from(availMicro))}.',
            _StatusType.error,
          );
          return;
        }
        if (!mounted) return;
        final ok = await _confirm(
          'Lock OCT',
          'Send ${_microClean(BigInt.from(micro))} OCT to the bridge.\n'
          'wOCT will be minted to:\n$recipient\n\n'
          'Mainnet — irreversible.',
        );
        if (ok != true) return;
        setState(() { _working = true; _status = null; });
        final rec = await _service.startWrap(ethRecipient: recipient, microOct: micro);
        _setStatus(
          'OCT locked (${_short(rec.lockTxHash)}). '
          'Claim button will appear in ~30–40 min.',
          _StatusType.info,
        );
        unawaited(_service.prepareClaim(rec).then((_) {
          if (mounted) _setStatus('wOCT ready to claim — see history below.', _StatusType.success);
        }).catchError((_) {}));
      } else {
        final sender = _senderFor(_ethAccount);
        if (sender == null) {
          _setStatus('Connect a signing Ethereum wallet to unwrap.', _StatusType.warning);
          return;
        }
        try {
          if (recipient.length != 47 || !recipient.startsWith('oct')) {
            _setStatus('Invalid Octra address — must start with "oct".', _StatusType.error);
            return;
          }
          await _service.refreshBalances(sender.address);
          if (BigInt.from(micro) > _service.woctBalanceRaw) {
            _setStatus(
              'Insufficient wOCT. Have ${_micro(_service.woctBalanceRaw)}.',
              _StatusType.error,
            );
            return;
          }
          if (!mounted) return;
          final speed = await _pickGasSpeed(
            gasLimit: EthConstants.approveGasLimit + EthConstants.burnGasLimit,
          );
          if (speed == null) return;
          if (!mounted) return;
          final ok = await _confirm(
            'Unwrap wOCT',
            'Burn ${_microClean(BigInt.from(micro))} wOCT.\n'
            'OCT released to:\n$recipient\n\n'
            '2 Ethereum txs (approve + burn) · ${speed.label} gas.',
          );
          if (ok != true) return;
          setState(() { _working = true; _status = null; });
          await _service.startUnwrap(
            sender: sender,
            octraRecipient: recipient,
            microOct: micro,
            gasSpeed: speed,
          );
          _setStatus('wOCT burned. OCT will arrive in your Octra wallet shortly.', _StatusType.success);
        } finally {
          sender.dispose();
        }
      }
    } catch (e) {
      _setStatus(_friendlyError(e), _StatusType.error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // ── claim ───────────────────────────────────────────────────────────────────

  Future<void> _claim(BridgeRecord rec) async {
    final sender = _senderFor(_ethAccount);
    if (sender == null) {
      _setStatus('Connect a signing Ethereum wallet to claim.', _StatusType.warning);
      return;
    }
    try {
      final speed = await _pickGasSpeed(gasLimit: EthConstants.claimGasLimit);
      if (speed == null) return;
      final amount = BigInt.tryParse(rec.amountRaw) ?? BigInt.zero;
      final ok = await _confirm(
        'Claim wOCT',
        'Claim ${_microClean(amount)} wOCT to your Ethereum wallet.\n'
        '${speed.label} gas.',
      );
      if (ok != true) return;
      setState(() => _working = true);
      await _service.claim(rec, sender, gasSpeed: speed);
      _setStatus('${_microClean(amount)} wOCT claimed!', _StatusType.success);
    } catch (e) {
      _setStatus(_friendlyError(e), _StatusType.error);
    } finally {
      sender.dispose();
      if (mounted) setState(() => _working = false);
    }
  }

  // ── claim by tx hash ────────────────────────────────────────────────────────

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
    setState(() { _working = true; });
    _setStatus('Searching recovery feed…', _StatusType.info);
    try {
      final rec = await _service.importByLockTxHash(lockTxHash.trim());
      if (rec == null) {
        _setStatus(
          'TX not found yet. It can take ~30–40 min to appear — try again later.',
          _StatusType.warning,
        );
        return;
      }
      if (rec.status == BridgeStatus.claimable) {
        _setStatus('Wrap found — Claim button is ready below.', _StatusType.success);
      } else if (rec.status == BridgeStatus.completed) {
        _setStatus('Already claimed.', _StatusType.info);
      } else {
        _setStatus('Found, but epoch not live on Ethereum yet. Check back in ~30 min.', _StatusType.warning);
      }
    } catch (e) {
      _setStatus(_friendlyError(e), _StatusType.error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // ── error mapping ────────────────────────────────────────────────────────────

  static String _friendlyError(Object e) {
    final raw = e.toString();
    final l = raw.toLowerCase();

    // Gas / ETH balance — most common bridge failure
    if (l.contains('insufficient funds') || l.contains('balance too low') ||
        l.contains('sender balance')) {
      return 'Not enough ETH for gas fees. Add ETH to your Ethereum wallet.';
    }
    if (l.contains('gas price too low') || l.contains('fee too low') ||
        l.contains('max fee per gas less than block base fee') ||
        l.contains('underpriced')) {
      return 'Gas price too low for current network. Try a faster speed tier.';
    }
    if (l.contains('gas required exceeds') || l.contains('out of gas')) {
      return 'Transaction ran out of gas. Try a higher gas speed.';
    }

    // Already done
    if (l.contains('already_claimed') || l.contains('already claimed') || l.contains('replay')) {
      return 'Already claimed — this wrap was previously redeemed.';
    }

    // Contract reverts
    if (l.contains('execution reverted') || l.contains('revert')) {
      return 'Contract rejected the transaction. Refresh and try again.';
    }

    // Nonce / mempool
    if (l.contains('nonce too low') || l.contains('replacement transaction underpriced') ||
        l.contains('already known')) {
      return 'Transaction conflict. Wait a moment and try again.';
    }

    // Network
    if (l.contains('connection refused') || l.contains('socketexception') ||
        l.contains('failed host lookup') || l.contains('network error')) {
      return 'Network error. Check your internet connection.';
    }
    if (l.contains('timeout') || l.contains('timed out')) {
      return 'Request timed out. Please try again.';
    }
    if (l.contains('http 429') || l.contains('rate limit')) {
      return 'Rate limited. Wait a moment and try again.';
    }

    // Bridge-specific
    if (l.contains('epoch not finalized') || l.contains('claim not available') ||
        l.contains('header is not yet')) {
      return 'Bridge epoch still processing (~30–40 min). Come back soon.';
    }
    if (l.contains('approve not confirmed')) {
      return 'Approval failed. Your ETH balance may be too low for gas.';
    }
    if (l.contains('burn not confirmed')) {
      return 'Burn failed. Your ETH balance may be too low for gas.';
    }
    if (l.contains('claim not confirmed')) {
      return 'Claim failed. Your ETH balance may be too low for gas.';
    }
    if (l.contains('lock failed') || (l.contains('lock') && l.contains('failed'))) {
      return 'Failed to lock OCT. Check balance and try again.';
    }
    if (l.contains('srcnonce') || l.contains('src_nonce')) {
      return 'Missing bridge data. Tap Refresh to recover.';
    }
    if (l.contains('tx not found') || l.contains('not found in the recovery')) {
      return 'TX not visible yet — takes ~30–40 min to appear.';
    }

    // Address / amount validation (these usually surface as user messages already)
    if (l.contains('walletconnect') && l.contains('not connected')) {
      return 'Wallet disconnected. Reconnect via WalletConnect.';
    }

    // Fallback — strip exception prefixes
    return raw
        .replaceFirst('StateError: ', '')
        .replaceFirst('Exception: ', '')
        .replaceFirst('ArgumentError: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }

  // ── format helpers ───────────────────────────────────────────────────────────

  static String _short(String? s) =>
      (s == null || s.length < 12) ? (s ?? '') : '${s.substring(0, 6)}…${s.substring(s.length - 4)}';

  static String _microClean(BigInt raw) {
    final d = raw.toDouble() / 1000000.0;
    if (d == d.floorToDouble() && d < 1e12) return d.toInt().toString();
    final s = d.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '');
    return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
  }

  static String _micro(BigInt raw) => (raw.toDouble() / 1000000.0).toStringAsFixed(6);
  static String _wei(BigInt wei) => (wei.toDouble() / 1e18).toStringAsFixed(5);

  static String _modeLabel(EthAccountMode mode) => switch (mode) {
    EthAccountMode.derived => 'Seed wallet',
    EthAccountMode.imported => 'Imported key',
    EthAccountMode.walletConnect => 'WalletConnect',
    EthAccountMode.manual => 'Watch address',
  };

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Bridge  OCT ⇄ wOCT'),
        backgroundColor: Color(0xCC000000),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _betaBanner(),
            const SizedBox(height: 12),

            // Direction selector
            CupertinoSlidingSegmentedControl<BridgeDirection>(
              groupValue: _direction,
              onValueChanged: (v) { if (v != null) _onDirectionChanged(v); },
              children: const {
                BridgeDirection.wrap: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Wrap  OCT→wOCT', style: TextStyle(fontSize: 13.5)),
                ),
                BridgeDirection.unwrap: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Unwrap  wOCT→OCT', style: TextStyle(fontSize: 13.5)),
                ),
              },
            ),
            const SizedBox(height: 12),

            // EVM account row
            _ethAccountCard(),
            const SizedBox(height: 12),

            // Form card (amount + recipient)
            _formCard(),
            const SizedBox(height: 12),

            // Submit button
            _SubmitButton(
              label: _direction == BridgeDirection.wrap ? 'Lock OCT' : 'Burn wOCT',
              loading: _working,
              onPressed: _working ? null : _submit,
            ),
            const SizedBox(height: 4),
            const Text(
              '0 protocol fee · 1:1 rate',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF636366), fontSize: 11.5),
            ),

            // Animated status banner
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(sizeFactor: anim, axisAlignment: -1, child: child),
              ),
              child: _status == null
                  ? const SizedBox.shrink(key: ValueKey('_none'))
                  : Padding(
                      key: ValueKey(_status),
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _StatusBanner(_status!, type: _statusType),
                    ),
            ),

            const SizedBox(height: 20),
            _historySection(),
          ],
        ),
      ),
    );
  }

  // ── sub-widgets ──────────────────────────────────────────────────────────────

  Widget _betaBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9F0A).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF9F0A).withValues(alpha: 0.35)),
      ),
      child: const Row(
        children: [
          Icon(CupertinoIcons.exclamationmark_triangle_fill,
              color: Color(0xFFFF9F0A), size: 12),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Beta · Mainnet bridge. Try a small amount first.',
              style: TextStyle(color: Color(0xFFFF9F0A), fontSize: 12, height: 1.2),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.link_circle_fill,
                    size: 18, color: Color(0xFF0A84FF)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: acc == null
                    ? const Text('No EVM wallet connected',
                        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_modeLabel(acc.mode),
                              style: const TextStyle(
                                  color: Color(0xFF8E8E93), fontSize: 11)),
                          Text(_short(acc.address),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'monospace')),
                        ],
                      ),
              ),
              if (acc != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_wei(_service.ethBalanceWei),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                    Text('ETH',
                        style: const TextStyle(color: Color(0xFF636366), fontSize: 10)),
                  ],
                ),
                const SizedBox(width: 12),
              ],
              _SmallButton(
                label: acc == null ? 'Set up' : 'Manage',
                onTap: _manageAccount,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _formCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Amount row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: CupertinoTextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              placeholder: _direction == BridgeDirection.wrap ? 'Amount in OCT' : 'Amount in wOCT',
              placeholderStyle: const TextStyle(color: Color(0xFF48484A), fontSize: 15),
              padding: const EdgeInsets.symmetric(vertical: 14),
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              decoration: const BoxDecoration(),
              suffix: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  _direction == BridgeDirection.wrap ? 'OCT' : 'wOCT',
                  style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(height: 1, child: ColoredBox(color: Color(0xFF2C2C2E))),
          ),
          // Recipient row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: CupertinoTextField(
              controller: _recipientCtrl,
              placeholder: _direction == BridgeDirection.wrap ? 'Ethereum address (0x…)' : 'Octra address (oct…)',
              placeholderStyle: const TextStyle(color: Color(0xFF48484A), fontSize: 13),
              padding: const EdgeInsets.symmetric(vertical: 12),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
              decoration: const BoxDecoration(),
              autocorrect: false,
              enableSuggestions: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historySection() {
    return AnimatedBuilder(
      animation: _service,
      builder: (_, __) {
        if (_service.history.isEmpty) return _emptyHistory();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('History',
                    style: TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                _SmallButton(
                  label: 'Refresh',
                  icon: CupertinoIcons.arrow_clockwise,
                  onTap: _working ? null : _refreshPending,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._service.history.map(_historyTile),
            const SizedBox(height: 10),
            _RecoverLink(onTap: _working ? null : _showClaimByTxSheet),
          ],
        );
      },
    );
  }

  Widget _emptyHistory() {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Text('No bridge activity yet.',
            style: TextStyle(color: Color(0xFF636366), fontSize: 13)),
        const SizedBox(height: 6),
        _RecoverLink(onTap: _working ? null : _showClaimByTxSheet),
      ],
    );
  }

  Widget _historyTile(BridgeRecord r) {
    final isWrap = r.direction == BridgeDirection.wrap;
    final canClaim = isWrap &&
        r.status == BridgeStatus.claimable &&
        (_ethAccount?.canSign ?? false);

    final statusColor = switch (r.status) {
      BridgeStatus.completed  => const Color(0xFF30D158),
      BridgeStatus.failed     => const Color(0xFFFF453A),
      BridgeStatus.claimable  => const Color(0xFFFF9F0A),
      BridgeStatus.submitting => const Color(0xFF0A84FF),
      BridgeStatus.pending    => const Color(0xFF8E8E93),
    };

    final statusIcon = switch (r.status) {
      BridgeStatus.completed  => CupertinoIcons.checkmark_circle_fill,
      BridgeStatus.failed     => CupertinoIcons.xmark_circle_fill,
      BridgeStatus.claimable  => CupertinoIcons.arrow_down_circle_fill,
      BridgeStatus.submitting => CupertinoIcons.clock_fill,
      BridgeStatus.pending    => CupertinoIcons.clock,
    };

    final statusLabel = switch (r.status) {
      BridgeStatus.claimable  => 'Ready to claim',
      BridgeStatus.pending    => r.epoch != null ? 'Pending · epoch ${r.epoch}' : 'Pending',
      BridgeStatus.submitting => 'Submitting…',
      BridgeStatus.completed  => 'Completed',
      BridgeStatus.failed     => r.error != null ? _friendlyError(r.error!) : 'Failed',
    };

    final amount = BigInt.tryParse(r.amountRaw) ?? BigInt.zero;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: r.status == BridgeStatus.claimable
            ? Border.all(color: const Color(0xFFFF9F0A).withValues(alpha: 0.55), width: 1.5)
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isWrap ? 'OCT→wOCT' : 'wOCT→OCT',
                      style: const TextStyle(color: Color(0xFF636366), fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _microClean(amount),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12)),
                if (r.claimTxHash != null || r.lockTxHash != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    r.claimTxHash != null
                        ? 'Claim: ${_short(r.claimTxHash)}'
                        : 'Lock: ${_short(r.lockTxHash)}',
                    style: const TextStyle(color: Color(0xFF48484A), fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          if (canClaim)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _ClaimChip(onTap: _working ? null : () => _claim(r)),
            ),
        ],
      ),
    );
  }
}

// ─── Small utility button ─────────────────────────────────────────────────────

class _SmallButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const _SmallButton({required this.label, this.icon, this.onTap});
  @override
  State<_SmallButton> createState() => _SmallButtonState();
}

class _SmallButtonState extends State<_SmallButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) { setState(() => _pressed = false); widget.onTap!(); } : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 12,
                    color: enabled ? const Color(0xFF0A84FF) : const Color(0xFF48484A)),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: enabled ? const Color(0xFF0A84FF) : const Color(0xFF48484A),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Submit button with press animation ──────────────────────────────────────

class _SubmitButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const _SubmitButton({required this.label, required this.loading, this.onPressed});
  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) { setState(() => _pressed = false); widget.onPressed!(); } : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 50,
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFF0A84FF)
                : const Color(0xFF0A84FF).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: widget.loading
                ? const CupertinoActivityIndicator(color: Colors.white, radius: 9)
                : Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Claim chip ───────────────────────────────────────────────────────────────

class _ClaimChip extends StatefulWidget {
  final VoidCallback? onTap;
  const _ClaimChip({this.onTap});
  @override
  State<_ClaimChip> createState() => _ClaimChipState();
}

class _ClaimChipState extends State<_ClaimChip> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) { setState(() => _pressed = false); widget.onTap!(); } : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFF0A84FF)
                : const Color(0xFF0A84FF).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Claim',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ─── Recover link ─────────────────────────────────────────────────────────────

class _RecoverLink extends StatelessWidget {
  final VoidCallback? onTap;
  const _RecoverLink({this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.search, size: 13,
              color: onTap != null ? const Color(0xFF0A84FF) : const Color(0xFF48484A)),
          const SizedBox(width: 5),
          Text(
            'Recover by lock TX hash',
            style: TextStyle(
              color: onTap != null ? const Color(0xFF0A84FF) : const Color(0xFF48484A),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status banner ────────────────────────────────────────────────────────────

enum _StatusType { success, info, warning, error }

class _StatusBanner extends StatelessWidget {
  final String message;
  final _StatusType type;
  const _StatusBanner(this.message, {required this.type});

  @override
  Widget build(BuildContext context) {
    final (textColor, bgColor, icon) = switch (type) {
      _StatusType.success => (
          const Color(0xFF30D158), const Color(0xFF0A2215),
          CupertinoIcons.checkmark_circle_fill,
        ),
      _StatusType.error => (
          const Color(0xFFFF6B6B), const Color(0xFF2A0D0D),
          CupertinoIcons.xmark_circle_fill,
        ),
      _StatusType.warning => (
          const Color(0xFFFF9F0A), const Color(0xFF2A1C0A),
          CupertinoIcons.exclamationmark_triangle_fill,
        ),
      _StatusType.info => (
          const Color(0xFF64A8FF), const Color(0xFF0A1828),
          CupertinoIcons.info_circle_fill,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: textColor, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gas speed sheet ─────────────────────────────────────────────────────────

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
    if (gp == null) return '—';
    final eth = (gp.toDouble() * speed.multiplierX10 / 10) * widget.gasLimit / 1e18;
    return '${eth.toStringAsFixed(5)} ETH';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFF48484A),
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Text('Gas Speed', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                Spacer(),
                Text('Fee estimate', style: TextStyle(color: Color(0xFF636366), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            for (final speed in GasSpeed.values) _tile(speed),
            const SizedBox(height: 6),
            _SubmitButton(
              label: 'Continue',
              loading: false,
              onPressed: () => Navigator.of(context).pop(_selected),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(GasSpeed speed) {
    final isSelected = speed == _selected;
    return GestureDetector(
      onTap: () => setState(() => _selected = speed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0A84FF).withValues(alpha: 0.12)
              : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isSelected ? const Color(0xFF0A84FF) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              color: isSelected ? const Color(0xFF0A84FF) : const Color(0xFF48484A),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                speed.label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF0A84FF) : Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            Text(speed.timing,
                style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
            const SizedBox(width: 10),
            Text(_feeLabel(speed),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
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

// ─── WalletConnect wallet picker sheet ───────────────────────────────────────

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
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFF48484A), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              const Text('Connect EVM Wallet',
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Choose your wallet app',
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13)),
              const SizedBox(height: 20),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _showQr ? _qrView() : _walletGrid(),
              ),

              const SizedBox(height: 14),
              // Copy link
              GestureDetector(
                onTap: _copyUri,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF3A3A3C)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.doc_on_doc, color: Color(0xFF8E8E93), size: 14),
                      SizedBox(width: 7),
                      Text('Copy connection link',
                          style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13.5)),
                    ],
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _walletGrid() {
    return Column(
      key: const ValueKey('grid'),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 14,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: _BridgeScreenState._evmWallets.length,
          itemBuilder: (_, i) => _WalletTile(
            info: _BridgeScreenState._evmWallets[i],
            onTap: () => _openWallet(_BridgeScreenState._evmWallets[i]),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _showQr = true),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.qrcode, color: Color(0xFF8E8E93), size: 18),
                SizedBox(width: 8),
                Text('Show QR Code',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _qrView() {
    return Column(
      key: const ValueKey('qr'),
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _showQr = false),
              child: const Row(
                children: [
                  Icon(CupertinoIcons.chevron_left, color: Color(0xFF0A84FF), size: 15),
                  SizedBox(width: 3),
                  Text('Back', style: TextStyle(color: Color(0xFF0A84FF), fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: QrImageView(data: widget.wcUri, size: 200),
        ),
        const SizedBox(height: 8),
        const Text('Scan with any WalletConnect wallet',
            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12.5)),
      ],
    );
  }
}

class _WalletTile extends StatefulWidget {
  final _WalletInfo info;
  final VoidCallback onTap;
  const _WalletTile({required this.info, required this.onTap});
  @override
  State<_WalletTile> createState() => _WalletTileState();
}

class _WalletTileState extends State<_WalletTile> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                color: widget.info.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.info.color.withValues(alpha: 0.28), width: 1.5),
              ),
              child: Center(
                child: Text(
                  widget.info.letter,
                  style: TextStyle(
                    color: widget.info.color,
                    fontSize: widget.info.letter.length > 1 ? 12 : 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(widget.info.name,
                style: const TextStyle(color: Color(0xFFAEAEB2), fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Claim by TX hash sheet ───────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFF48484A), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            const Text('Recover by TX Hash',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'Paste your Octra lock TX hash to find and claim wOCT.',
              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: CupertinoTextField(
                controller: ctrl,
                placeholder: '64 hex chars or 0x…',
                placeholderStyle: const TextStyle(color: Color(0xFF48484A), fontSize: 13),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontFamily: 'monospace'),
                decoration: const BoxDecoration(),
                autocorrect: false,
                enableSuggestions: false,
              ),
            ),
            const SizedBox(height: 14),
            _SubmitButton(
              label: 'Look up',
              loading: false,
              onPressed: () => onLookup(ctrl.text.trim()),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
