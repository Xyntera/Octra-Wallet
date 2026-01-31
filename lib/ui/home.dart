import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, Colors, Icons, LinearGradient, Alignment, Scaffold, SelectableText;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../wallet.dart';
import '../models.dart';
import '../rpc.dart';
import 'wallet_setup.dart';
import 'scanner.dart';
import 'success_animation.dart';
import 'pin_screen.dart';

// ============================================================================
// SWISS MINIMALIST DESIGN - BLACK & WHITE MODERN UI
// ============================================================================

class HomeTabScaffold extends StatefulWidget {
  const HomeTabScaffold({super.key});

  @override
  State<HomeTabScaffold> createState() => _HomeTabScaffoldState();
}

class _HomeTabScaffoldState extends State<HomeTabScaffold> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: const [
                WalletTab(),
                EncryptTab(),
                KeysTab(),
              ],
            ),
          ),
          // Swiss Tab Bar
          _buildTabBar(),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black, width: 1)),
      ),
      height: 60,
      child: Row(
        children: [
          _buildTab('WALLET', 0),
          _buildTab('ENCRYPT', 1),
          _buildTab('KEYS', 2),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Helvetica Neue',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: isActive ? Colors.black : const Color(0xFF999999),
              ),
            ),
            if (isActive)
              Positioned(
                bottom: 8,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WALLET TAB - Main Dashboard
// ============================================================================

class WalletTab extends StatefulWidget {
  const WalletTab({super.key});

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  bool _isPrivateVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletController>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletCtrl = context.watch<WalletController>();
    final wallet = walletCtrl.currentWallet;

    if (wallet == null) {
      return const Center(child: CupertinoActivityIndicator());
    }

    // Format balance
    final balance = walletCtrl.publicBalance;
    final balanceUsd = (balance * 2.97).toStringAsFixed(0); // Mock USD conversion
    final balanceOct = balance.toStringAsFixed(2);

    return SafeArea(
      child: Column(
        children: [
          // Header
          _buildHeader(context),
          
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    
                    // Balance Label
                    const Text(
                      'CURRENT BALANCE',
                      style: TextStyle(
                        fontFamily: 'Helvetica Neue',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.black,
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                    
                    const SizedBox(height: 20),
                    
                    // Hero Balance
                    Text(
                      '\$$balanceUsd',
                      style: const TextStyle(
                        fontFamily: 'Helvetica Neue',
                        fontSize: 64,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -2,
                        color: Colors.black,
                        height: 1,
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 10),
                    
                    // OCT Balance
                    Text(
                      '$balanceOct OCT',
                      style: const TextStyle(
                        fontFamily: 'Helvetica Neue',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF555555),
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                    
                    const SizedBox(height: 30),
                    
                    // Private Card
                    _buildPrivateCard(walletCtrl),
                    
                    const SizedBox(height: 20),
                    
                    // Send Button
                    _buildPrimaryButton(
                      'SEND OCTRA',
                      Icons.arrow_forward,
                      () => _showSendSheet(context),
                    ),
                    
                    const SizedBox(height: 15),
                    
                    // Secondary Actions Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildSecondaryButton(
                            'RECEIVE',
                            () => _showReceiveSheet(context, wallet.address),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildSecondaryButton(
                            'SCAN',
                            () => _openScanner(context),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
      ),
      height: 70,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'OCTRA',
            style: TextStyle(
              fontFamily: 'Helvetica Neue',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: Colors.black,
            ),
          ),
          GestureDetector(
            onTap: () => _showAccountMenu(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline, size: 16, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateCard(WalletController walletCtrl) {
    return GestureDetector(
      onTap: () => setState(() => _isPrivateVisible = !_isPrivateVisible),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.black),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label Row
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white30, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PRIVATE STASH',
                    style: TextStyle(
                      fontFamily: 'Courier New',
                      fontSize: 10,
                      letterSpacing: 0.5,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 10, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        'ENCRYPTED',
                        style: TextStyle(
                          fontFamily: 'Courier New',
                          fontSize: 10,
                          letterSpacing: 0.5,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 15),
            
            // Private Balance
            Text(
              _isPrivateVisible 
                  ? '${walletCtrl.encryptedBalance.toStringAsFixed(2)} OCT'
                  : '••••••••',
              style: const TextStyle(
                fontFamily: 'Helvetica Neue',
                fontSize: 24,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 15),
            
            // ID
            Text(
              'ID: ${walletCtrl.currentWallet?.address.substring(0, 10) ?? "---"}',
              style: TextStyle(
                fontFamily: 'Courier New',
                fontSize: 9,
                letterSpacing: 0.5,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1));
  }

  Widget _buildPrimaryButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 340),
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Helvetica Neue',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            Container(
              width: 56,
              height: double.infinity,
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Colors.black, width: 1)),
              ),
              child: Icon(icon, size: 16, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Helvetica Neue',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // SHEET METHODS
  // ============================================================================

  void _showAccountMenu(BuildContext context) {
    final walletCtrl = context.read<WalletController>();
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
          border: Border(top: BorderSide(color: Colors.black, width: 1)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuHeader(),
              _buildMenuItem('SWITCH WALLET', Icons.swap_horiz, () {
                Navigator.pop(context);
                _showWalletsSheet(context);
              }),
              _buildMenuItem('EXPORT WALLET', Icons.file_upload_outlined, () {
                Navigator.pop(context);
                _exportWallet(context);
              }),
              _buildMenuItem('SECURITY', Icons.shield_outlined, () {
                Navigator.pop(context);
                Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SecuritySettingsPage()));
              }),
              _buildMenuItem('ABOUT', Icons.info_outline, () {
                Navigator.pop(context);
                _showAbout(context);
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
      ),
      child: Row(
        children: [
          const Text(
            'MENU',
            style: TextStyle(
              fontFamily: 'Helvetica Neue',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: Colors.black,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, size: 20, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.black),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Helvetica Neue',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF999999)),
          ],
        ),
      ),
    );
  }

  void _showWalletsSheet(BuildContext context) {
    final walletCtrl = context.read<WalletController>();
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 400,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black, width: 1)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
              ),
              child: Row(
                children: [
                  const Text(
                    'WALLETS',
                    style: TextStyle(
                      fontFamily: 'Helvetica Neue',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 20, color: Colors.black),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: walletCtrl.wallets.length + 1,
                itemBuilder: (ctx, idx) {
                  if (idx == walletCtrl.wallets.length) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context, rootNavigator: true).push(
                          CupertinoPageRoute(builder: (_) => const WalletSetupPage()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: const [
                            Icon(Icons.add, size: 18, color: Colors.black),
                            SizedBox(width: 16),
                            Text(
                              'ADD WALLET',
                              style: TextStyle(
                                fontFamily: 'Helvetica Neue',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final w = walletCtrl.wallets[idx];
                  final isSelected = w == walletCtrl.currentWallet;
                  return GestureDetector(
                    onTap: () {
                      walletCtrl.selectWallet(w);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF5F5F5) : Colors.white,
                        border: const Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 18,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.name.toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'Helvetica Neue',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${w.address.substring(0, 12)}...',
                                  style: const TextStyle(
                                    fontFamily: 'Courier New',
                                    fontSize: 10,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSendSheet(BuildContext context) {
    _showTransactionForm(context, title: 'SEND', buttonText: 'SEND', isPublic: true);
  }

  void _showReceiveSheet(BuildContext context, String address) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black, width: 1)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
              ),
              child: Row(
                children: [
                  const Text(
                    'RECEIVE',
                    style: TextStyle(
                      fontFamily: 'Helvetica Neue',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 20, color: Colors.black),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    child: QrImageView(
                      data: address,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      address,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Courier New',
                        fontSize: 11,
                        color: Color(0xFF555555),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: address));
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      decoration: const BoxDecoration(color: Colors.black),
                      child: const Text(
                        'COPY ADDRESS',
                        style: TextStyle(
                          fontFamily: 'Helvetica Neue',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openScanner(BuildContext context) async {
    final result = await Navigator.of(context).push<String>(
      CupertinoPageRoute(builder: (_) => const ScannerPage()),
    );
    if (result != null && result.isNotEmpty) {
      _showTransactionForm(context, title: 'SEND', buttonText: 'SEND', isPublic: true, prefillAddress: result);
    }
  }

  void _exportWallet(BuildContext context) {
    final walletCtrl = context.read<WalletController>();
    final wallet = walletCtrl.currentWallet;
    if (wallet == null) return;
    
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Export Wallet'),
        content: Column(
          children: [
            const SizedBox(height: 16),
            if (wallet.mnemonic != null && wallet.mnemonic!.isNotEmpty) ...[
              const Text('SEED PHRASE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 8),
              SelectableText(wallet.mnemonic!, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
            ],
            const Text('PRIVATE KEY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            SelectableText(wallet.privateKeyBase64, style: const TextStyle(fontSize: 10)),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Copy Seed'),
            onPressed: () {
              if (wallet.mnemonic != null) {
                Clipboard.setData(ClipboardData(text: wallet.mnemonic!));
              }
              Navigator.pop(ctx);
            },
          ),
          CupertinoDialogAction(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('OCTRA WALLET'),
        content: const Column(
          children: [
            SizedBox(height: 16),
            Text('Built by ouqro.tech'),
            Text('Code by Xyntera'),
            SizedBox(height: 8),
            Text('v1.0.0', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ENCRYPT TAB
// ============================================================================

class EncryptTab extends StatelessWidget {
  const EncryptTab({super.key});

  @override
  Widget build(BuildContext context) {
    final walletCtrl = context.watch<WalletController>();
    
    return SafeArea(
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
                  'ENCRYPT',
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
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encrypted Balance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(color: Colors.black),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ENCRYPTED BALANCE',
                          style: TextStyle(
                            fontFamily: 'Courier New',
                            fontSize: 10,
                            letterSpacing: 0.5,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${walletCtrl.encryptedBalance.toStringAsFixed(6)} OCT',
                          style: const TextStyle(
                            fontFamily: 'Helvetica Neue',
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          'ENCRYPT',
                          () => _showTransactionForm(context, title: 'ENCRYPT', buttonText: 'ENCRYPT', isEncrypt: true),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildActionButton(
                          'DECRYPT',
                          () => _showTransactionForm(context, title: 'DECRYPT', buttonText: 'DECRYPT', isDecrypt: true),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 15),
                  
                  _buildActionButton(
                    'PRIVATE TRANSFER',
                    () => _showTransactionForm(context, title: 'PRIVATE TRANSFER', buttonText: 'SEND', isPrivateTransfer: true),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Pending Claims
                  const Text(
                    'PENDING CLAIMS',
                    style: TextStyle(
                      fontFamily: 'Helvetica Neue',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Colors.black,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  if (walletCtrl.pendingPrivateTransfers.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
                      ),
                      child: const Center(
                        child: Text(
                          'NO PENDING TRANSFERS',
                          style: TextStyle(
                            fontFamily: 'Helvetica Neue',
                            fontSize: 11,
                            letterSpacing: 1,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ),
                    )
                  else
                    ...walletCtrl.pendingPrivateTransfers.map((tx) => _buildClaimTile(context, tx, walletCtrl)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Helvetica Neue',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClaimTile(BuildContext context, dynamic tx, WalletController wallet) {
    final id = tx['id'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_open, size: 18, color: Colors.black),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'TRANSFER #$id',
              style: const TextStyle(
                fontFamily: 'Helvetica Neue',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: Colors.black,
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              final ephKey = tx['ephemeral_public_key'];
              final encAmt = tx['encrypted_amount'];
              final success = await wallet.claimTransfer(id.toString(), ephKey, encAmt);
              showCupertinoDialog(
                context: context,
                builder: (ctx) => CupertinoAlertDialog(
                  title: Text(success ? 'CLAIMED' : 'FAILED'),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('OK'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(color: Colors.black),
              child: const Text(
                'CLAIM',
                style: TextStyle(
                  fontFamily: 'Helvetica Neue',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// KEYS TAB (History)
// ============================================================================

class KeysTab extends StatelessWidget {
  const KeysTab({super.key});

  @override
  Widget build(BuildContext context) {
    final walletCtrl = context.watch<WalletController>();
    
    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
            ),
            height: 70,
            child: Row(
              children: [
                const Text(
                  'HISTORY',
                  style: TextStyle(
                    fontFamily: 'Helvetica Neue',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => walletCtrl.refresh(),
                  child: const Icon(Icons.refresh, size: 20, color: Colors.black),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: walletCtrl.history.isEmpty
                ? const Center(
                    child: Text(
                      'NO TRANSACTIONS',
                      style: TextStyle(
                        fontFamily: 'Helvetica Neue',
                        fontSize: 11,
                        letterSpacing: 1,
                        color: Color(0xFF999999),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: walletCtrl.history.length,
                    itemBuilder: (ctx, idx) {
                      final tx = walletCtrl.history[idx];
                      return _buildTransactionRow(context, tx);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(BuildContext context, Map<String, dynamic> tx) {
    final hash = tx['hash'] ?? '';
    final direction = tx['direction'] ?? 'IN';
    final isIn = direction == 'IN';
    final amountStr = tx['amount'] ?? '0';
    double amt = double.tryParse(amountStr.toString()) ?? 0.0;
    
    return GestureDetector(
      onTap: () => _showTransactionDetails(context, tx),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: Icon(
                isIn ? Icons.arrow_downward : Icons.arrow_upward,
                size: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isIn ? 'RECEIVED' : 'SENT',
                    style: const TextStyle(
                      fontFamily: 'Helvetica Neue',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hash.length > 16 ? '${hash.substring(0, 16)}...' : hash,
                    style: const TextStyle(
                      fontFamily: 'Courier New',
                      fontSize: 10,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isIn ? '+' : '-'}${amt.toStringAsFixed(2)} OCT',
              style: TextStyle(
                fontFamily: 'Helvetica Neue',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isIn ? const Color(0xFF00AA00) : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, Map<String, dynamic> tx) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _TransactionDetailsSheet(initialTx: tx),
    );
  }
}

// ============================================================================
// TRANSACTION DETAILS SHEET
// ============================================================================

class _TransactionDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> initialTx;
  const _TransactionDetailsSheet({required this.initialTx});

  @override
  State<_TransactionDetailsSheet> createState() => _TransactionDetailsSheetState();
}

class _TransactionDetailsSheetState extends State<_TransactionDetailsSheet> {
  Map<String, dynamic>? fullTx;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final wallet = context.read<WalletController>();
    final hash = widget.initialTx['hash'];
    if (hash != null && hash.isNotEmpty) {
      final res = await wallet.getTransactionFullDetails(hash);
      if (mounted) {
        setState(() {
          if (res != null) fullTx = res;
          loading = false;
        });
      }
    } else {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTx = fullTx != null ? (fullTx!['parsed_tx'] ?? fullTx!) : widget.initialTx;
    final meta = fullTx ?? widget.initialTx;
    final hash = displayTx['hash'] ?? displayTx['tx_hash'] ?? widget.initialTx['hash'] ?? '';
    final direction = widget.initialTx['direction'] ?? 'IN';
    final isIn = direction == 'IN';
    final amountStr = displayTx['amount'] ?? '0';
    double amt = double.tryParse(amountStr.toString()) ?? 0.0;
    final status = meta['status'] ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black, width: 1)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'TRANSACTION',
                  style: TextStyle(
                    fontFamily: 'Helvetica Neue',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 20, color: Colors.black),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            if (loading)
              const CupertinoActivityIndicator()
            else ...[
              // Amount
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: Icon(
                  isIn ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 24,
                  color: Colors.black,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                '${isIn ? '+' : '-'}${amt.toStringAsFixed(6)} OCT',
                style: const TextStyle(
                  fontFamily: 'Helvetica Neue',
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: Text(
                  status.toString().toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Helvetica Neue',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.black,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              _buildDetailRow('FROM', displayTx['from'] ?? ''),
              _buildDetailRow('TO', displayTx['to'] ?? displayTx['to_'] ?? ''),
              _buildDetailRow('HASH', hash),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Helvetica Neue',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Color(0xFF666666),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => Clipboard.setData(ClipboardData(text: value)),
              child: Text(
                value.length > 24 ? '${value.substring(0, 12)}...${value.substring(value.length - 8)}' : value,
                style: const TextStyle(
                  fontFamily: 'Courier New',
                  fontSize: 11,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TRANSACTION FORM (Shared)
// ============================================================================

void _showTransactionForm(
  BuildContext context, {
  required String title,
  required String buttonText,
  bool isPublic = false,
  bool isEncrypt = false,
  bool isDecrypt = false,
  bool isPrivateTransfer = false,
  String? prefillAddress,
}) {
  showCupertinoModalPopup(
    context: context,
    builder: (context) => _TransactionFormSheet(
      title: title,
      buttonText: buttonText,
      isPublic: isPublic,
      isEncrypt: isEncrypt,
      isDecrypt: isDecrypt,
      isPrivateTransfer: isPrivateTransfer,
      prefillAddress: prefillAddress,
    ),
  );
}

class _TransactionFormSheet extends StatefulWidget {
  final String title;
  final String buttonText;
  final bool isPublic;
  final bool isEncrypt;
  final bool isDecrypt;
  final bool isPrivateTransfer;
  final String? prefillAddress;

  const _TransactionFormSheet({
    required this.title,
    required this.buttonText,
    this.isPublic = false,
    this.isEncrypt = false,
    this.isDecrypt = false,
    this.isPrivateTransfer = false,
    this.prefillAddress,
  });

  @override
  State<_TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<_TransactionFormSheet> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillAddress != null) {
      _addressController.text = widget.prefillAddress!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsAddress = widget.isPublic || widget.isPrivateTransfer;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black, width: 1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
            ),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontFamily: 'Helvetica Neue',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 20, color: Colors.black),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (needsAddress) ...[
                    const Text(
                      'RECIPIENT ADDRESS',
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
                        controller: _addressController,
                        placeholder: 'Enter address',
                        padding: const EdgeInsets.all(16),
                        decoration: null,
                        style: const TextStyle(fontFamily: 'Courier New', fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  const Text(
                    'AMOUNT',
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
                      controller: _amountController,
                      placeholder: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      padding: const EdgeInsets.all(16),
                      decoration: null,
                      style: const TextStyle(fontFamily: 'Helvetica Neue', fontSize: 24, fontWeight: FontWeight.w500),
                      suffix: const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Text('OCT', style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Submit Button
                  GestureDetector(
                    onTap: _isLoading ? null : _submit,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: const BoxDecoration(color: Colors.black),
                      child: Center(
                        child: _isLoading
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : Text(
                                widget.buttonText,
                                style: const TextStyle(
                                  fontFamily: 'Helvetica Neue',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final walletCtrl = context.read<WalletController>();
    final amount = double.tryParse(_amountController.text) ?? 0;
    final address = _addressController.text.trim();
    
    if (amount <= 0) {
      _showError('Invalid amount');
      return;
    }
    
    if ((widget.isPublic || widget.isPrivateTransfer) && address.isEmpty) {
      _showError('Address required');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      RpcResponse? res;
      bool success = false;
      
      if (widget.isPublic) {
        res = await walletCtrl.sendTransaction(address, amount, null);
        success = res.statusCode == 200;
      } else if (widget.isEncrypt) {
        res = await walletCtrl.encryptMoney(amount);
        success = res.statusCode == 200;
      } else if (widget.isDecrypt) {
        res = await walletCtrl.decryptMoney(amount);
        success = res.statusCode == 200;
      } else if (widget.isPrivateTransfer) {
        res = await walletCtrl.makePrivateTransfer(address, amount);
        success = res.statusCode == 200;
      }
      
      if (mounted) {
        Navigator.pop(context);
        if (success) {
          await walletCtrl.refresh();
          Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => SuccessAnimation(message: '${widget.title} Successful')),
          );
        } else {
          _showError(res?.body ?? 'Transaction failed');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
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

// ============================================================================
// SECURITY SETTINGS PAGE
// ============================================================================

class SecuritySettingsPage extends StatelessWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white,
        border: const Border(bottom: BorderSide(color: Colors.black, width: 1)),
        middle: const Text(
          'SECURITY',
          style: TextStyle(
            fontFamily: 'Helvetica Neue',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: Colors.black,
          ),
        ),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSecurityOption(
                'CHANGE PIN',
                Icons.lock_outline,
                () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const PinScreen(isSetup: true)),
                ),
              ),
              _buildSecurityOption(
                'BIOMETRICS',
                Icons.fingerprint,
                () {},
              ),
              _buildSecurityOption(
                'AUTO-LOCK',
                Icons.timer_outlined,
                () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityOption(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Helvetica Neue',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF999999)),
          ],
        ),
      ),
    );
  }
}

// Legacy aliases for compatibility
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});
  @override
  Widget build(BuildContext context) => const WalletTab();
}

class PrivateTab extends StatelessWidget {
  const PrivateTab({super.key});
  @override
  Widget build(BuildContext context) => const EncryptTab();
}

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});
  @override
  Widget build(BuildContext context) => const KeysTab();
}

// Edit Wallet Sheet (kept for compatibility)
class _EditWalletSheet extends StatelessWidget {
  final Wallet wallet;
  const _EditWalletSheet({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black, width: 1)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'EDIT WALLET',
              style: TextStyle(
                fontFamily: 'Helvetica Neue',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            Text(wallet.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(wallet.address, style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
                child: const Text(
                  'CLOSE',
                  style: TextStyle(
                    fontFamily: 'Helvetica Neue',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
