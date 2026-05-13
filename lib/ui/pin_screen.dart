import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../wallet.dart';

class PinScreen extends StatefulWidget {
  final bool isSettingPin;
  final bool isChecking;

  const PinScreen({super.key, this.isSettingPin = false, this.isChecking = false});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = "";
  final int _pinLength = 4;
  UniqueKey _shakeKey = UniqueKey();
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  
  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      setState(() {
        _canCheckBiometrics = canAuthenticateWithBiometrics;
      });
      if (widget.isChecking && canAuthenticateWithBiometrics) {
         // Auto trigger for checking
         _authenticate(); 
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _authenticate() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to access Octra Wallet',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (didAuthenticate && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print(e);
    }
  }

  void _onKeyPress(String val) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += val;
      });
      if (_pin.length == _pinLength) {
        _onSubmit();
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _onSubmit() async {
    if (widget.isSettingPin) {
      if (mounted) Navigator.pop(context, _pin);
    } else {
      final wallet = context.read<WalletController>();
      final ok = await wallet.checkPin(_pin);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _pin = "";
          _shakeKey = UniqueKey();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Icon(CupertinoIcons.lock_shield, size: 60, color: CupertinoColors.systemBlue)
            .animate().scale(curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              widget.isSettingPin ? "Set 4-Digit PIN" : "Enter PIN",
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _pin.length ? CupertinoColors.systemBlue : CupertinoColors.systemGrey.withValues(alpha: 0.3),
                    boxShadow: index < _pin.length ? [BoxShadow(color: CupertinoColors.systemBlue.withValues(alpha: 0.5), blurRadius: 10)] : null,
                  ),
                );
              }),
            ).animate(key: _shakeKey).shake(duration: 400.ms, hz: 4, offset: const Offset(6, 0)),
            const Spacer(),
            // Numpad
            _buildNumpad(),
            const SizedBox(height: 20),
            if (widget.isChecking && _canCheckBiometrics)
              CupertinoButton(
                 child: const Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Icon(CupertinoIcons.checkmark_shield), 
                     SizedBox(width: 8), 
                     Text("Use Biometrics")
                   ],
                 ),
                 onPressed: _authenticate
              ).animate().fadeIn(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKey("1"), _buildKey("2"), _buildKey("3")
            ],
          ),
          const SizedBox(height: 24),
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKey("4"), _buildKey("5"), _buildKey("6")
            ],
          ),
          const SizedBox(height: 24),
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKey("7"), _buildKey("8"), _buildKey("9")
            ],
          ),
          const SizedBox(height: 24),
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 70, height: 70), // Empty for alignment or biometric icon?
              _buildKey("0"), 
              _buildDeleteKey()
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String val) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _onKeyPress(val);
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(val, style: GoogleFonts.outfit(color: Colors.white, fontSize: 28)),
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _onDelete();
      },
      child: Container(
        width: 70,
        height: 70,
        color: Colors.transparent,
        child: const Center(
          child: Icon(CupertinoIcons.delete_left, color: Colors.white),
        ),
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
  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletController>();
    
    final isEnabled = wallet.securityEnabledSync;
    return Builder(
      builder: (context) {
        
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
                 decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
                 children: [
                   CupertinoListTile(
                     title: const Text("Enable Security", style: TextStyle(color: Colors.white)),
                     trailing: CupertinoSwitch(
                       value: isEnabled,
                       onChanged: (val) async {
                         if (val) {
                           final res = await Navigator.push(context, CupertinoPageRoute(builder: (_) => const PinScreen(isSettingPin: true)));
                           if (res != null) {
                             await wallet.setPin(res as String);
                           }
                         } else {
                           // Require PIN confirmation before disabling security
                           final res = await Navigator.push(context, CupertinoPageRoute(builder: (_) => const PinScreen(isChecking: true)));
                           if (res == true) {
                             await wallet.setSecurityEnabled(false);
                           }
                         }
                         if (context.mounted) setState(() {});
                       },
                     ),
                   ),
                   if (isEnabled) ...[
                      CupertinoListTile(
                         title: const Text("Change PIN", style: TextStyle(color: Colors.white)),
                         trailing: const Icon(CupertinoIcons.chevron_right, color: Colors.grey),
                         onTap: () async {
                           final res = await Navigator.push(context, CupertinoPageRoute(builder: (_) => const PinScreen(isSettingPin: true)));
                           if (res != null) {
                              await wallet.setPin(res as String);
                           }
                         },
                      ),
                   ]
                 ],
               )
             ],
          ),
        );
      }
    );
  }
}
