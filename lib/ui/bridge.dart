import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:provider/provider.dart';

import '../eth/bridge_models.dart';
import '../eth/bridge_service.dart';
import '../eth/eth_account.dart';
import '../eth/eth_constants.dart';
import '../wallet.dart';

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
  EthAccount? _ethAccount;
  bool _working = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _wallet = context.read<WalletController>();
    _service = BridgeService(wallet: _wallet);
    _ethAccount = _deriveEthAccount();
    _recipientCtrl.text = _direction == BridgeDirection.wrap
        ? (_ethAccount?.address ?? '')
        : (_wallet.currentWallet?.address ?? '');
    _service.loadHistory();
    if (_ethAccount != null) {
      _service.refreshBalances(_ethAccount!.address);
    }
  }

  EthAccount? _deriveEthAccount() {
    final mnemonic = _wallet.currentWallet?.mnemonic;
    if (mnemonic == null || mnemonic.trim().isEmpty) return null;
    try {
      return EthAccount.fromMnemonic(mnemonic.trim());
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
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
        final account = _ethAccount;
        if (account == null || !account.canSign) {
          throw StateError(
              'Unwrap needs the in-app Ethereum account (this wallet has no '
              'recovery phrase to derive it).');
        }
        if (recipient.length != 47 || !recipient.startsWith('oct')) {
          throw StateError('Enter a valid Octra recipient.');
        }
        await _service.startUnwrap(
          account: account,
          octraRecipient: recipient,
          microOct: micro,
        );
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
    final account = _ethAccount;
    if (account == null || !account.canSign) {
      setState(() => _status = 'No in-app Ethereum account to claim with.');
      return;
    }
    setState(() => _working = true);
    try {
      await _service.claim(rec, account);
      setState(() => _status = 'Claimed wOCT.');
    } catch (e) {
      setState(() => _status = _clean(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Bridge  ·  OCT ⇄ wOCT'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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

  Widget _ethAccountCard() {
    return AnimatedBuilder(
      animation: _service,
      builder: (_, __) {
        final addr = _ethAccount?.address;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                addr == null
                    ? 'No in-app Ethereum account (import a wallet with a '
                        'recovery phrase to enable it).'
                    : 'Ethereum account (derived): ${_short(addr)}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              if (addr != null) ...[
                const SizedBox(height: 8),
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
