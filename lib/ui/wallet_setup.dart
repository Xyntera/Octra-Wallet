import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Icons;
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../wallet.dart';
import 'home.dart';
import 'pin_screen.dart';
import 'video_logo.dart';

// ============================================================================
// WALLET SETUP - Swiss Minimalist
// Developer: @glaqzz
// ============================================================================

class WalletSetupPage extends StatefulWidget {
  const WalletSetupPage({super.key});
  @override
  State<WalletSetupPage> createState() => _WalletSetupPageState();
}

class _WalletSetupPageState extends State<WalletSetupPage> {
  bool _importing = false;
  bool _loading = false;
  final _seedCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
              child: const Row(children: [Text('OCTRA', style: TextStyle(fontFamily: 'Helvetica Neue', fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 3))]),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Video Logo
                    const VideoLogo(size: 120),
                    
                    const SizedBox(height: 32),
                    
                    const Text('OCTRA WALLET', style: TextStyle(fontFamily: 'Helvetica Neue', fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 4))
                        .animate().fadeIn(),
                    
                    const SizedBox(height: 8),
                    
                    const Text('SECURE · PRIVATE · FAST', style: TextStyle(fontFamily: 'Helvetica Neue', fontSize: 11, letterSpacing: 2, color: Colors.grey))
                        .animate().fadeIn(delay: 100.ms),
                    
                    const SizedBox(height: 48),
                    
                    if (_importing) ...[
                      Container(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SEED PHRASE OR PRIVATE KEY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                              child: CupertinoTextField(
                                controller: _seedCtrl,
                                placeholder: 'Enter 12/24 words or base64 key',
                                maxLines: 4,
                                padding: const EdgeInsets.all(12),
                                decoration: null,
                                style: const TextStyle(fontFamily: 'Courier New', fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildBtn('IMPORT', true, _import),
                            const SizedBox(height: 12),
                            _buildBtn('BACK', false, () => setState(() => _importing = false)),
                          ],
                        ),
                      ).animate().fadeIn(),
                    ] else ...[
                      _buildBtn('CREATE NEW WALLET', true, _create).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 12),
                      _buildBtn('IMPORT EXISTING', false, () => setState(() => _importing = true)).animate().fadeIn(delay: 300.ms),
                    ],
                    
                    if (_loading) ...[
                      const SizedBox(height: 24),
                      const CupertinoActivityIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            
            // Footer Credit
            Padding(
              padding: const EdgeInsets.all(16),
              child: const Text('DEV @GLAQZZ', style: TextStyle(fontFamily: 'Courier New', fontSize: 9, color: Colors.grey, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBtn(String label, bool primary, VoidCallback onTap) {
    return GestureDetector(
      onTap: _loading ? null : onTap,
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          color: primary ? Colors.black : Colors.white,
          border: Border.all(color: Colors.black),
        ),
        child: Center(
          child: Text(label, style: TextStyle(
            fontFamily: 'Helvetica Neue',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: primary ? Colors.white : Colors.black,
          )),
        ),
      ),
    );
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    try {
      final ctrl = context.read<WalletController>();
      
      // Force Security Setup
      if (!await ctrl.isSecurityEnabled) {
         final res = await Navigator.push(context, CupertinoPageRoute(builder: (_) => const PinScreen(isSettingPin: true)));
         if (res != null && res is String) {
           await ctrl.setPin(res);
         } else {
           return; // Cancelled
         }
      }

      final data = await ctrl.generateNewWalletData();
      await ctrl.addWallet(data['address']!, data['privateKeyBase64']!, data['mnemonic']);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute(builder: (_) => const HomeTabScaffold()),
          (route) => false,
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    final input = _seedCtrl.text.trim();
    if (input.isEmpty) {
      _showError('Please enter seed phrase or private key');
      return;
    }
    
    setState(() => _loading = true);
    try {
      final ctrl = context.read<WalletController>();

      // Force Security Setup
      if (!await ctrl.isSecurityEnabled) {
         final res = await Navigator.push(context, CupertinoPageRoute(builder: (_) => const PinScreen(isSettingPin: true)));
         if (res != null && res is String) {
           await ctrl.setPin(res);
         } else {
           _loading = false; // Reset loading if cancelled
           setState(() {});
           return; // Cancelled
         }
      }

      final data = await ctrl.processInput(input);
      if (data == null) {
        _showError('Invalid input');
        return;
      }
      await ctrl.addWallet(data['address']!, data['privateKeyBase64']!, data['mnemonic']?.isEmpty == true ? null : data['mnemonic']);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute(builder: (_) => const HomeTabScaffold()),
          (route) => false,
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) => showCupertinoDialog(
    context: context,
    builder: (_) => CupertinoAlertDialog(
      title: const Text('ERROR'),
      content: Text(msg),
      actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(context))],
    ),
  );
}
