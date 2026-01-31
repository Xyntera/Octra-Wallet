import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Icons;
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../wallet.dart';
import 'home.dart';

// ============================================================================
// SWISS MINIMALIST WALLET SETUP
// ============================================================================

class WalletSetupPage extends StatefulWidget {
  const WalletSetupPage({super.key});

  @override
  State<WalletSetupPage> createState() => _WalletSetupPageState();
}

class _WalletSetupPageState extends State<WalletSetupPage> {
  bool _isImporting = false;
  bool _isLoading = false;
  final TextEditingController _seedController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
              ),
              height: 70,
              child: const Row(
                children: [
                  Text(
                    'OCTRA',
                    style: TextStyle(
                      fontFamily: 'Helvetica Neue',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, size: 40, color: Colors.black),
                    ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                    
                    const SizedBox(height: 32),
                    
                    // Title
                    const Text(
                      'OCTRA WALLET',
                      style: TextStyle(
                        fontFamily: 'Helvetica Neue',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        color: Colors.black,
                      ),
                    ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 12),
                    
                    const Text(
                      'SECURE · PRIVATE · FAST',
                      style: TextStyle(
                        fontFamily: 'Helvetica Neue',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                        color: Color(0xFF666666),
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                    
                    const SizedBox(height: 48),
                    
                    if (_isImporting) ...[
                      // Import Form
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SEED PHRASE',
                              style: TextStyle(
                                fontFamily: 'Helvetica Neue',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black, width: 1),
                              ),
                              child: CupertinoTextField(
                                controller: _seedController,
                                placeholder: 'Enter 12 or 24 word seed phrase',
                                padding: const EdgeInsets.all(16),
                                maxLines: 4,
                                decoration: null,
                                style: const TextStyle(fontFamily: 'Courier New', fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildButton('IMPORT WALLET', true, _importWallet),
                            const SizedBox(height: 12),
                            _buildButton('BACK', false, () => setState(() => _isImporting = false)),
                          ],
                        ),
                      ).animate().fadeIn(),
                    ] else ...[
                      // Main Options
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: Column(
                          children: [
                            _buildButton('CREATE NEW WALLET', true, _createWallet),
                            const SizedBox(height: 16),
                            _buildButton('IMPORT EXISTING', false, () => setState(() => _isImporting = true)),
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
                    ],
                    
                    if (_isLoading) ...[
                      const SizedBox(height: 32),
                      const CupertinoActivityIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              child: const Text(
                'BY XYNTERA',
                style: TextStyle(
                  fontFamily: 'Courier New',
                  fontSize: 9,
                  letterSpacing: 1,
                  color: Color(0xFF999999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String label, bool isPrimary, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: isPrimary ? Colors.black : Colors.white,
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Helvetica Neue',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: isPrimary ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createWallet() async {
    setState(() => _isLoading = true);
    try {
      final walletCtrl = context.read<WalletController>();
      // Generate wallet data
      final walletData = await walletCtrl.generateNewWalletData();
      // Add wallet to storage
      await walletCtrl.addWallet(
        walletData['address']!,
        walletData['privateKeyBase64']!,
        walletData['mnemonic'],
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute(builder: (_) => const HomeTabScaffold()),
          (route) => false,
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importWallet() async {
    final seed = _seedController.text.trim();
    if (seed.isEmpty) {
      _showError('Please enter your seed phrase');
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final walletCtrl = context.read<WalletController>();
      // Process input (seed phrase or private key)
      final walletData = await walletCtrl.processInput(seed);
      if (walletData == null) {
        _showError('Invalid seed phrase or private key');
        return;
      }
      // Add wallet to storage
      await walletCtrl.addWallet(
        walletData['address']!,
        walletData['privateKeyBase64']!,
        walletData['mnemonic']?.isEmpty == true ? null : walletData['mnemonic'],
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute(builder: (_) => const HomeTabScaffold()),
          (route) => false,
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('ERROR'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }
}
