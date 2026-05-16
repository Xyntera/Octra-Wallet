import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../wallet.dart';

class PinScreen extends StatefulWidget {
  final bool isSettingPin;
  final bool isChecking;

  const PinScreen({
    super.key,
    this.isSettingPin = false,
    this.isChecking = false,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  static const int _pinLength = 4;

  String _enteredPin = '';
  String _firstPin = '';
  String? _errorText;
  bool _awaitingConfirmation = false;
  bool _isBusy = false;
  UniqueKey _shakeKey = UniqueKey();

  String get _titleText {
    if (widget.isSettingPin) {
      return _awaitingConfirmation ? 'Confirm PIN' : 'Set PIN';
    }
    return 'Enter PIN';
  }

  String get _subtitleText {
    if (widget.isSettingPin) {
      return _awaitingConfirmation
          ? 'Re-enter the same 4 digits to confirm.'
          : 'Create a 4-digit PIN to unlock the vault and approve sensitive actions.';
    }
    return 'Enter your PIN to unlock the wallet.';
  }

  void _setError(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _errorText = message;
      _enteredPin = '';
      _firstPin = '';
      _awaitingConfirmation = false;
      _shakeKey = UniqueKey();
    });
  }

  void _onKeyPress(String value) {
    if (_isBusy || _enteredPin.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin += value;
      _errorText = null;
    });
    if (_enteredPin.length == _pinLength) {
      _submitPin();
    }
  }

  void _onDelete() {
    if (_isBusy || _enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorText = null;
    });
  }

  Future<void> _submitPin() async {
    if (_isBusy) return;
    if (widget.isSettingPin) {
      if (!_awaitingConfirmation) {
        setState(() {
          _firstPin = _enteredPin;
          _awaitingConfirmation = true;
          _enteredPin = '';
          _errorText = null;
          _shakeKey = UniqueKey();
        });
        HapticFeedback.selectionClick();
        return;
      }

      if (_enteredPin.length != _pinLength) return;
      if (_firstPin.isEmpty) {
        _setError('Enter a valid PIN');
        return;
      }

      final confirmPin = _enteredPin;
      if (_firstPin == confirmPin) {
        HapticFeedback.mediumImpact();
        if (!mounted) return;
        Navigator.pop(context, confirmPin);
      } else {
        _setError('PINs do not match');
      }
      return;
    }

    setState(() => _isBusy = true);
    try {
      final wallet = context.read<WalletController>();
      final ok = await wallet.checkPin(_enteredPin);
      if (!mounted) return;
      if (ok) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true);
        return;
      }
      _setError('Wrong PIN');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: CupertinoPageScaffold(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF061229), Color(0xFF000000)],
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 56),
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(color: CupertinoColors.systemBlue.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.systemBlue.withValues(alpha: 0.18),
                        blurRadius: 26,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.lock_shield_fill,
                    size: 44,
                    color: CupertinoColors.systemBlue,
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.0, 1.0), duration: 1400.ms, curve: Curves.easeInOut),
                ),
                const SizedBox(height: 24),
                Text(
                  _titleText,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _subtitleText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (index) {
                    final filled = index < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? CupertinoColors.systemBlue
                            : CupertinoColors.systemGrey.withValues(alpha: 0.25),
                        boxShadow: filled
                            ? [
                                BoxShadow(
                                  color: CupertinoColors.systemBlue.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                )
                    .animate(key: _shakeKey)
                    .shake(duration: 420.ms, hz: 4, offset: const Offset(6, 0)),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: 220.ms,
                  child: _errorText == null
                      ? Text(
                          widget.isSettingPin && _awaitingConfirmation
                              ? 'Re-enter the same PIN'
                              : ' ',
                          key: const ValueKey('hint'),
                          style: GoogleFonts.outfit(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        )
                      : Text(
                          _errorText!,
                          key: const ValueKey('error'),
                          style: GoogleFonts.outfit(
                            color: CupertinoColors.systemRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const Spacer(),
                _buildNumpad(),
                const SizedBox(height: 18),
                Text(
                  'PIN lock is mandatory on this wallet.',
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    final keyStyle = GoogleFonts.outfit(
      color: Colors.white,
      fontSize: 27,
      fontWeight: FontWeight.w600,
    );

    Widget key(String value) {
      return GestureDetector(
        onTap: () => _onKeyPress(value),
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Center(child: Text(value, style: keyStyle)),
        ),
      );
    }

    Widget blank() {
      return const SizedBox(width: 74, height: 74);
    }

    Widget delete() {
      return GestureDetector(
        onTap: _onDelete,
        child: Container(
          width: 74,
          height: 74,
          color: Colors.transparent,
          child: const Center(
            child: Icon(CupertinoIcons.delete_left, color: Colors.white),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [key('1'), key('2'), key('3')],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [key('4'), key('5'), key('6')],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [key('7'), key('8'), key('9')],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [blank(), key('0'), delete()],
          ),
        ],
      ),
    );
  }
}

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  Future<void> _changePin(BuildContext context, WalletController wallet) async {
    final verified = await Navigator.of(context, rootNavigator: true).push<bool>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PinScreen(isChecking: true),
      ),
    );
    if (verified != true || !context.mounted) return;

    final newPin = await Navigator.of(context, rootNavigator: true).push<String>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PinScreen(isSettingPin: true),
      ),
    );
    if (newPin == null || newPin.length < 4 || !context.mounted) return;
    await wallet.setPin(newPin);
    if (context.mounted) {
      setState(() {});
    }
  }

  Future<void> _lockNow(WalletController wallet) async {
    await wallet.lockVault();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletController>();

    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Security", style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xCC1C1C1E),
      ),
      child: ListView(
        children: [
          const SizedBox(height: 20),
          CupertinoListSection.insetGrouped(
            backgroundColor: const Color(0xFF1C1C1E),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
            ),
            children: [
              CupertinoListTile(
                title: const Text("PIN Lock", style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  "Always enabled for wallet unlock and sensitive actions",
                  style: TextStyle(color: Colors.white54),
                ),
                trailing: const Icon(CupertinoIcons.lock_fill, color: CupertinoColors.systemBlue),
              ),
              CupertinoListTile(
                title: const Text("Change PIN", style: TextStyle(color: Colors.white)),
                trailing: const Icon(CupertinoIcons.chevron_right, color: Colors.grey),
                onTap: () => _changePin(context, wallet),
              ),
              CupertinoListTile(
                title: const Text("Lock Now", style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  "Clear decrypted wallet data from memory",
                  style: TextStyle(color: Colors.white54),
                ),
                trailing: const Icon(CupertinoIcons.lock_rotation, color: CupertinoColors.systemBlue),
                onTap: () => _lockNow(wallet),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
