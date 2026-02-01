import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Icons, Scaffold, ListTile, Divider, SelectableText, SwitchListTile;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../wallet.dart';
import '../models.dart';
import '../rpc.dart';
import 'wallet_setup.dart';
import 'scanner.dart';
import 'success_animation.dart';
import 'pin_screen.dart';
import 'legal_pages.dart';
import 'video_logo.dart';

// ============================================================================
// OCTRA WALLET - PREMIUM ANIMATED UI
// Developer: @glaqzz on X
// Package: com.octrawallet.app
// ============================================================================

class HomeTabScaffold extends StatefulWidget {
  const HomeTabScaffold({super.key});
  @override
  State<HomeTabScaffold> createState() => _HomeTabScaffoldState();
}

class _HomeTabScaffoldState extends State<HomeTabScaffold> with TickerProviderStateMixin {
  int _tab = 0;
  bool _privateMode = false;
  late AnimationController _rollController;

  Color get _bg => _privateMode ? const Color(0xFF0A1F12) : Colors.white;
  Color get _fg => _privateMode ? const Color(0xFFE0E0E0) : Colors.black;
  Color get _accent => _privateMode ? const Color(0xFF4ADE80) : Colors.black;

  @override
  void initState() {
    super.initState();
    _rollController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<WalletController>().refresh());
  }

  @override
  void dispose() {
    _rollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        color: _bg,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _tab == 0 ? _buildWalletTab() : _buildCryptTab()),
            _buildBottomTabs(),
            // Developer Credit
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: GestureDetector(
                onTap: () => launchUrl(Uri.parse('https://x.com/glaqzz')),
                child: Text('BUILT BY @GLAQZZ', style: TextStyle(fontFamily: 'Courier', fontSize: 9, letterSpacing: 1, color: _fg.withOpacity(0.3))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ANIMATED HEADER ====================
  Widget _buildHeader() {
    final ctrl = context.watch<WalletController>();
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _fg.withOpacity(_privateMode ? 0.15 : 1)))),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Animated Logo
            // Animated Video Logo
            VideoLogo(size: 30),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _showWalletPicker(context, ctrl),
              child: Row(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OCTRA WALLET', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: _fg)),
                      if (ctrl.currentWallet != null)
                        Text(ctrl.currentWallet!.name.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: _fg.withOpacity(0.5))),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(CupertinoIcons.chevron_down, size: 12, color: _fg.withOpacity(0.5)),
                ],
              ),
            ),
            const Spacer(),
            // Refresh with loading animation
            GestureDetector(
              onTap: () => ctrl.refresh(),
              child: ctrl.isLoading
                ? CupertinoActivityIndicator(color: _fg)
                : Icon(CupertinoIcons.refresh, size: 20, color: _fg),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => _showMenu(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 18, height: 2, color: _fg, margin: const EdgeInsets.only(bottom: 4)),
                  Container(width: 18, height: 2, color: _fg),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  // ==================== WALLET TAB - Premium Hero ====================
  Widget _buildWalletTab() {
    final ctrl = context.watch<WalletController>();
    final balance = _privateMode ? ctrl.encryptedBalance : ctrl.publicBalance;
    
    // Split balance for styling
    final parts = balance.toStringAsFixed(6).split('.');
    final whole = parts[0];
    final decimal = parts.length > 1 ? '.${parts[1]}' : '';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Hero Balance Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Balance Label with endless scroll
                SizedBox(
                  height: 20,
                  child: AnimatedBuilder(
                    animation: _rollController,
                    builder: (_, __) {
                      final offset = (_rollController.value * 200) % 200;
                      return Stack(
                        children: [
                          Transform.translate(
                            offset: Offset(-offset, 0),
                            child: Row(children: List.generate(10, (_) => Padding(
                              padding: const EdgeInsets.only(right: 24),
                              child: Text(_privateMode ? 'ENCRYPTED BALANCE' : 'TOTAL BALANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2, color: _fg.withOpacity(0.4))),
                            ))),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Big Balance Number
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(whole, style: TextStyle(fontSize: 72, fontWeight: FontWeight.w800, letterSpacing: -4, height: 0.85, color: _fg)).animate().fadeIn().slideX(begin: -0.1),
                    Text(decimal, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, letterSpacing: -1, height: 1.5, color: _fg.withOpacity(0.25))).animate().fadeIn(delay: 100.ms),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Token Label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(border: Border.all(color: _fg.withOpacity(0.2))),
                  child: Text('OCT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: _fg)),
                ).animate().fadeIn(delay: 200.ms),
              ],
            ),
          ),
          
          // Action Items
          _buildActionItem('Send', CupertinoIcons.arrow_up_right, () => _showTxSheet(context, 'SEND', isPublic: true)),
          _buildActionItem('Receive', CupertinoIcons.arrow_down_left, () => _showReceive(context)),
          _buildActionItem('Scan QR', CupertinoIcons.qrcode_viewfinder, () => _openScanner(context)),
          _buildActionItem('Private Mode', _privateMode ? CupertinoIcons.lock_fill : CupertinoIcons.lock_open, 
            () => setState(() => _privateMode = !_privateMode), isToggle: true, toggleValue: _privateMode),
        ],
      ),
    );
  }

  // ==================== CRYPT TAB ====================
  Widget _buildCryptTab() {
    final ctrl = context.watch<WalletController>();
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CRYPTOGRAPHY', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1, color: _fg)).animate().fadeIn().slideX(begin: -0.05),
                const SizedBox(height: 8),
                Text('PRIVATE OPERATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2, color: _fg.withOpacity(0.4))).animate().fadeIn(delay: 100.ms),
                
                const SizedBox(height: 24),
                
                // Encrypted Balance Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ENCRYPTED BALANCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1, color: _bg.withOpacity(0.7))),
                      const SizedBox(height: 8),
                      Text('${ctrl.encryptedBalance.toStringAsFixed(6)} OCT', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _bg)),
                    ],
                  ),
                ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
              ],
            ),
          ),
          
          _buildActionItem('Encrypt Balance', CupertinoIcons.lock, () => _showTxSheet(context, 'ENCRYPT', isEncrypt: true)),
          _buildActionItem('Decrypt Balance', CupertinoIcons.lock_open, () => _showTxSheet(context, 'DECRYPT', isDecrypt: true)),
          _buildActionItem('Private Transfer', CupertinoIcons.arrow_right_arrow_left, () => _showTxSheet(context, 'PRIVATE TRANSFER', isPrivate: true)),
          _buildActionItem('Export Wallet', CupertinoIcons.square_arrow_up, () => _showExport(context)),
          
          // Pending Claims
          if (ctrl.pendingPrivateTransfers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('PENDING CLAIMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2, color: _fg)),
            ),
            ...ctrl.pendingPrivateTransfers.map((tx) => _buildClaimTile(tx, ctrl)),
          ],
        ],
      ),
    );
  }

  // ==================== ACTION ITEM ====================
  Widget _buildActionItem(String text, IconData icon, VoidCallback onTap, {bool isToggle = false, bool toggleValue = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: _fg.withOpacity(_privateMode ? 0.1 : 0.15)))),
        child: Row(
          children: [
            Icon(icon, size: 22, color: _fg.withOpacity(0.7)),
            const SizedBox(width: 16),
            Text(text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: _fg)),
            const Spacer(),
            if (isToggle)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22, height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _fg, width: 2), color: toggleValue ? _fg : Colors.transparent),
                child: toggleValue ? Icon(Icons.check, size: 14, color: _bg) : null,
              )
            else
              Icon(CupertinoIcons.chevron_right, size: 18, color: _fg.withOpacity(0.4)),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.02);
  }

  Widget _buildClaimTile(dynamic tx, WalletController ctrl) {
    final id = tx['id'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: _fg.withOpacity(0.2))),
      child: Row(
        children: [
          Icon(CupertinoIcons.gift, size: 20, color: _accent),
          const SizedBox(width: 12),
          Expanded(child: Text('TRANSFER #$id', style: TextStyle(fontWeight: FontWeight.w600, color: _fg))),
          GestureDetector(
            onTap: () async {
              final ok = await ctrl.claimTransfer(id.toString(), tx['ephemeral_public_key'], tx['encrypted_amount']);
              if (ok) ctrl.refresh();
            },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: _accent, child: Text('CLAIM', style: TextStyle(color: _bg, fontWeight: FontWeight.w700, fontSize: 11))),
          ),
        ],
      ),
    );
  }

  // ==================== BOTTOM TABS ====================
  Widget _buildBottomTabs() {
    return Container(
      height: 60,
      decoration: BoxDecoration(border: Border(top: BorderSide(color: _fg.withOpacity(_privateMode ? 0.1 : 1)))),
      child: Row(children: [_buildTabBtn('WALLET', 0), _buildTabBtn('CRYPT', 1)]),
    );
  }

  Widget _buildTabBtn(String label, int index) {
    final isActive = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isActive ? _fg : _bg,
            border: index == 0 ? Border(right: BorderSide(color: _fg.withOpacity(_privateMode ? 0.1 : 1))) : null,
          ),
          child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1, color: isActive ? _bg : _fg))),
        ),
      ),
    );
  }

  // ==================== DIALOGS & SHEETS ====================
  void _showWalletPicker(BuildContext context, WalletController ctrl) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 450, color: _bg,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _fg.withOpacity(0.15)))),
              child: Row(children: [
                Text('SELECT WALLET', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1, color: _fg)),
                const Spacer(),
                GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close, color: _fg)),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: ctrl.wallets.length + 1,
                itemBuilder: (_, i) {
                  if (i == ctrl.wallets.length) {
                    return GestureDetector(
                      onTap: () { Navigator.pop(context); Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(builder: (_) => const WalletSetupPage())); },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: Row(children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(border: Border.all(color: _fg)), child: Icon(Icons.add, color: _fg)),
                          const SizedBox(width: 16),
                          Text('ADD NEW WALLET', style: TextStyle(fontWeight: FontWeight.w600, color: _fg)),
                        ]),
                      ),
                    );
                  }
                  final w = ctrl.wallets[i];
                  return GestureDetector(
                    onTap: () { ctrl.selectWallet(w); Navigator.pop(context); },
                    onLongPress: () { Navigator.pop(context); _editWallet(context, w, ctrl); },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _fg.withOpacity(0.08)))),
                      child: Row(children: [
                        Container(width: 44, height: 44, decoration: BoxDecoration(color: Color(w.color), borderRadius: BorderRadius.circular(22))),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(w.name.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w600, color: _fg)),
                          Text('${w.address.substring(0, 18)}...', style: TextStyle(fontSize: 10, fontFamily: 'Courier', color: _fg.withOpacity(0.4))),
                        ])),
                        if (w == ctrl.currentWallet) Icon(Icons.check_circle, color: _accent),
                      ]),
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

  void _editWallet(BuildContext ctx, Wallet w, WalletController ctrl) {
    final nameCtrl = TextEditingController(text: w.name);
    int color = w.color;
    final colors = [0xFF000000, 0xFF357AF6, 0xFF32D74B, 0xFFFF9F0A, 0xFFFF375F, 0xFFBF5AF2, 0xFF5856D6, 0xFF64D2FF];
    showCupertinoDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (_, set) => CupertinoAlertDialog(
        title: const Text('EDIT WALLET'),
        content: Column(children: [
          const SizedBox(height: 16),
          CupertinoTextField(controller: nameCtrl, placeholder: 'Wallet Name'),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: colors.map((c) => GestureDetector(
            onTap: () => set(() => color = c),
            child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: color == c ? Border.all(color: Colors.white, width: 3) : null)),
          )).toList()),
        ]),
        actions: [
          CupertinoDialogAction(isDestructiveAction: true, child: const Text('DELETE'), onPressed: () { ctrl.deleteWallet(w.address); Navigator.pop(ctx); }),
          CupertinoDialogAction(child: const Text('CANCEL'), onPressed: () => Navigator.pop(ctx)),
          CupertinoDialogAction(isDefaultAction: true, child: const Text('SAVE'), onPressed: () { ctrl.updateWallet(w.address, name: nameCtrl.text, color: color); Navigator.pop(ctx); }),
        ],
      )),
    );
  }

  void _showMenu(BuildContext ctx) {
    showCupertinoModalPopup(
      context: ctx,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Security Settings', style: TextStyle(color: Colors.black)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(ctx, CupertinoPageRoute(builder: (_) => const PinScreen(isSettingPin: true)));
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Privacy Policy', style: TextStyle(color: Colors.black)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(ctx, CupertinoPageRoute(builder: (_) => const PrivacyPolicyPage()));
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Terms & Conditions', style: TextStyle(color: Colors.black)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(ctx, CupertinoPageRoute(builder: (_) => const TermsPage()));
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Website: octrawallet.app', style: TextStyle(color: Colors.black)),
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse('https://octrawallet.app'), mode: LaunchMode.externalApplication);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Refresh Data', style: TextStyle(color: Colors.black)),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<WalletController>().refresh();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Developer @glaqzz', style: TextStyle(color: Colors.grey, fontSize: 12)),
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse('https://x.com/glaqzz'));
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _showReceive(BuildContext ctx) {
    final addr = context.read<WalletController>().currentWallet?.address ?? '';
    showCupertinoModalPopup(context: ctx, builder: (_) => Container(
      height: 520, color: _bg,
      child: Column(children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _fg.withOpacity(0.15)))),
          child: Row(children: [Text('RECEIVE', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1, color: _fg)), const Spacer(), GestureDetector(onTap: () => Navigator.pop(ctx), child: Icon(Icons.close, color: _fg))])),
        const Spacer(),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: _fg)), child: QrImageView(data: addr, size: 200, backgroundColor: Colors.white)),
        const SizedBox(height: 20),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Text(addr, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: _fg))),
        const Spacer(),
        GestureDetector(onTap: () { Clipboard.setData(ClipboardData(text: addr)); Navigator.pop(ctx); },
          child: Container(margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(18), color: _fg, child: Center(child: Text('COPY ADDRESS', style: TextStyle(color: _bg, fontWeight: FontWeight.w700, letterSpacing: 1))))),
      ]),
    ));
  }

  void _showExport(BuildContext ctx) {
    final w = context.read<WalletController>().currentWallet;
    if (w == null) return;
    showCupertinoDialog(context: ctx, builder: (_) => CupertinoAlertDialog(
      title: const Text('EXPORT WALLET'),
      content: Column(children: [
        const SizedBox(height: 16),
        if (w.mnemonic != null && w.mnemonic!.isNotEmpty) ...[const Text('SEED PHRASE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(height: 8), SelectableText(w.mnemonic!, style: const TextStyle(fontSize: 11)), const SizedBox(height: 16)],
        const Text('PRIVATE KEY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        SelectableText(w.privateKeyBase64, style: const TextStyle(fontSize: 9, fontFamily: 'Courier')),
      ]),
      actions: [
        CupertinoDialogAction(child: const Text('COPY SEED'), onPressed: () { if (w.mnemonic != null) Clipboard.setData(ClipboardData(text: w.mnemonic!)); Navigator.pop(ctx); }),
        CupertinoDialogAction(child: const Text('CLOSE'), onPressed: () => Navigator.pop(ctx)),
      ],
    ));
  }

  void _openScanner(BuildContext ctx) async {
    final result = await Navigator.of(ctx).push<String>(CupertinoPageRoute(builder: (_) => const ScannerPage()));
    if (result != null) _showTxSheet(ctx, 'SEND', isPublic: true, prefill: result);
  }

  void _showTxSheet(BuildContext ctx, String title, {bool isPublic = false, bool isEncrypt = false, bool isDecrypt = false, bool isPrivate = false, String? prefill}) {
    final addrCtrl = TextEditingController(text: prefill);
    final amtCtrl = TextEditingController();
    bool loading = false;
    showCupertinoModalPopup(context: ctx, builder: (_) => StatefulBuilder(builder: (ctx2, set) => Container(
      height: 420, color: _bg,
      child: Column(children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _fg.withOpacity(0.15)))),
          child: Row(children: [Text(title, style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1, color: _fg)), const Spacer(), GestureDetector(onTap: () => Navigator.pop(ctx2), child: Icon(Icons.close, color: _fg))])),
        Expanded(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (isPublic || isPrivate) ...[Text('ADDRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _fg)), const SizedBox(height: 8),
            Container(decoration: BoxDecoration(border: Border.all(color: _fg)), child: CupertinoTextField(controller: addrCtrl, placeholder: 'Recipient address', padding: const EdgeInsets.all(14), decoration: null, style: TextStyle(color: _fg))), const SizedBox(height: 20)],
          Text('AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _fg)), const SizedBox(height: 8),
          Container(decoration: BoxDecoration(border: Border.all(color: _fg)), child: CupertinoTextField(controller: amtCtrl, placeholder: '0.00', keyboardType: const TextInputType.numberWithOptions(decimal: true), padding: const EdgeInsets.all(14), decoration: null, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: _fg))),
          const Spacer(),
          GestureDetector(
            onTap: loading ? null : () async {
              final amt = double.tryParse(amtCtrl.text) ?? 0;
              if (amt <= 0) return;
              set(() => loading = true);
              final ctrl = context.read<WalletController>();
              RpcResponse res;
              if (isPublic) res = await ctrl.sendTransaction(addrCtrl.text.trim(), amt, null);
              else if (isEncrypt) res = await ctrl.encryptMoney(amt);
              else if (isDecrypt) res = await ctrl.decryptMoney(amt);
              else res = await ctrl.makePrivateTransfer(addrCtrl.text.trim(), amt);
              Navigator.pop(ctx2);
              if (res.statusCode == 200) { await ctrl.refresh(); Navigator.of(context).push(CupertinoPageRoute(builder: (_) => SuccessAnimation(onComplete: () => Navigator.pop(context)))); }
            },
            child: Container(width: double.infinity, padding: const EdgeInsets.all(18), color: _fg, child: Center(child: loading ? CupertinoActivityIndicator(color: _bg) : Text('CONFIRM', style: TextStyle(color: _bg, fontWeight: FontWeight.w700, letterSpacing: 1)))),
          ),
        ]))),
      ]),
    )));
  }
}

// Legacy compatibility aliases
class DashboardTab extends StatelessWidget { const DashboardTab({super.key}); @override Widget build(BuildContext context) => const HomeTabScaffold(); }
class PrivateTab extends StatelessWidget { const PrivateTab({super.key}); @override Widget build(BuildContext context) => const HomeTabScaffold(); }
class EncryptTab extends StatelessWidget { const EncryptTab({super.key}); @override Widget build(BuildContext context) => const HomeTabScaffold(); }
class HistoryTab extends StatelessWidget { const HistoryTab({super.key}); @override Widget build(BuildContext context) => const HomeTabScaffold(); }
class SettingsTab extends StatelessWidget { const SettingsTab({super.key}); @override Widget build(BuildContext context) => const HomeTabScaffold(); }
