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

// ============================================================================
// OCTRA WALLET - Exact HTML Design Port
// Developer: @glaqzz
// ============================================================================

class HomeTabScaffold extends StatefulWidget {
  const HomeTabScaffold({super.key});
  @override
  State<HomeTabScaffold> createState() => _HomeTabScaffoldState();
}

class _HomeTabScaffoldState extends State<HomeTabScaffold> {
  int _tab = 0;
  bool _privateMode = false;

  Color get _bg => _privateMode ? const Color(0xFF0A1F12) : Colors.white;
  Color get _fg => _privateMode ? const Color(0xFFE0E0E0) : Colors.black;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _tab == 0 ? _buildWalletTab() : _buildCryptTab()),
          _buildBottomTabs(),
        ],
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader() {
    final ctrl = context.watch<WalletController>();
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _fg.withOpacity(_privateMode ? 0.2 : 1)))),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showWalletPicker(context, ctrl),
            child: Row(
              children: [
                Text('OCTRA WALLET', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: _fg)),
                const SizedBox(width: 8),
                Icon(CupertinoIcons.chevron_down, size: 12, color: _fg),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _showMenu(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 20, height: 1.5, color: _fg, margin: const EdgeInsets.only(bottom: 5)),
                Container(width: 20, height: 1.5, color: _fg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== WALLET TAB ====================
  Widget _buildWalletTab() {
    final ctrl = context.watch<WalletController>();
    final balance = _privateMode ? ctrl.encryptedBalance : ctrl.publicBalance;
    final whole = balance.toStringAsFixed(0);
    final decimal = (balance - balance.floor()).toStringAsFixed(2).substring(1);

    return Column(
      children: [
        // Balance Container
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Balance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: _fg.withOpacity(0.6))),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(whole, style: TextStyle(fontSize: 64, fontWeight: FontWeight.w700, letterSpacing: -3, height: 0.9, color: _fg)),
                    Text(decimal, style: TextStyle(fontSize: 64, fontWeight: FontWeight.w700, letterSpacing: -3, height: 0.9, color: _fg.withOpacity(0.3))),
                  ],
                ),
                const SizedBox(height: 10),
                Text('OCT Token', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: _fg)),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
        ),

        // Action List
        _buildActionItem('Send', CupertinoIcons.arrow_right, () => _showTxSheet(context, 'SEND', isPublic: true)),
        _buildActionItem('Receive', CupertinoIcons.arrow_down, () => _showReceive(context)),
        _buildActionItem('Private Mode', null, () => setState(() => _privateMode = !_privateMode), isToggle: true, toggleValue: _privateMode),
      ],
    );
  }

  // ==================== CRYPT TAB ====================
  Widget _buildCryptTab() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SECURITY', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -2, color: _fg)),
              const SizedBox(height: 20),
              Text('Key Management', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: _fg.withOpacity(0.6))),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),

        const Spacer(),

        // Actions
        _buildActionItem('Encrypt Balance', CupertinoIcons.lock, () => _showTxSheet(context, 'ENCRYPT', isEncrypt: true)),
        _buildActionItem('Decrypt Balance', CupertinoIcons.lock_open, () => _showTxSheet(context, 'DECRYPT', isDecrypt: true)),
        _buildActionItem('Private Transfer', CupertinoIcons.arrow_right_arrow_left, () => _showTxSheet(context, 'PRIVATE TRANSFER', isPrivate: true)),
        _buildActionItem('Export Wallet', CupertinoIcons.square_arrow_up, () => _showExport(context)),
      ],
    );
  }

  // ==================== ACTION ITEM ====================
  Widget _buildActionItem(String text, IconData? icon, VoidCallback onTap, {bool isToggle = false, bool toggleValue = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: _fg.withOpacity(_privateMode ? 0.2 : 1)))),
        child: Row(
          children: [
            Text(text, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -1, color: _fg)),
            const Spacer(),
            if (isToggle)
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _fg, width: 1.5)),
                child: toggleValue ? Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: _fg))) : null,
              )
            else if (icon != null)
              Icon(icon, size: 24, color: _fg),
          ],
        ),
      ),
    );
  }

  // ==================== BOTTOM TABS ====================
  Widget _buildBottomTabs() {
    return Container(
      height: 60,
      decoration: BoxDecoration(border: Border(top: BorderSide(color: _fg.withOpacity(_privateMode ? 0.2 : 1)))),
      child: Row(
        children: [
          _buildTabBtn('WALLET', 0),
          _buildTabBtn('CRYPT', 1),
        ],
      ),
    );
  }

  Widget _buildTabBtn(String label, int index) {
    final isActive = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? _fg : _bg,
            border: index == 0 ? Border(right: BorderSide(color: _fg.withOpacity(_privateMode ? 0.2 : 1))) : null,
          ),
          child: Center(
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isActive ? _bg : _fg)),
          ),
        ),
      ),
    );
  }

  // ==================== WALLET PICKER ====================
  void _showWalletPicker(BuildContext context, WalletController ctrl) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 450, color: _bg,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _fg.withOpacity(0.2)))),
              child: Row(
                children: [
                  Text('SELECT WALLET', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1, color: _fg)),
                  const Spacer(),
                  GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close, color: _fg)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: ctrl.wallets.length + 1,
                itemBuilder: (_, i) {
                  if (i == ctrl.wallets.length) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(builder: (_) => const WalletSetupPage()));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(width: 40, height: 40, decoration: BoxDecoration(border: Border.all(color: _fg)), child: Icon(Icons.add, color: _fg)),
                            const SizedBox(width: 16),
                            Text('ADD NEW WALLET', style: TextStyle(fontWeight: FontWeight.w600, color: _fg)),
                          ],
                        ),
                      ),
                    );
                  }
                  final w = ctrl.wallets[i];
                  final isSelected = w == ctrl.currentWallet;
                  return GestureDetector(
                    onTap: () { ctrl.selectWallet(w); Navigator.pop(context); },
                    onLongPress: () { Navigator.pop(context); _editWallet(context, w, ctrl); },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _fg.withOpacity(0.1)))),
                      child: Row(
                        children: [
                          Container(width: 40, height: 40, decoration: BoxDecoration(color: Color(w.color), borderRadius: BorderRadius.circular(20))),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.name.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w600, color: _fg)),
                                Text('${w.address.substring(0, 16)}...', style: TextStyle(fontSize: 10, fontFamily: 'Courier', color: _fg.withOpacity(0.5))),
                              ],
                            ),
                          ),
                          if (isSelected) Icon(Icons.check_circle, color: _fg),
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

  void _editWallet(BuildContext ctx, Wallet w, WalletController ctrl) {
    final nameCtrl = TextEditingController(text: w.name);
    int color = w.color;
    final colors = [0xFF000000, 0xFF357AF6, 0xFF32D74B, 0xFFFF9F0A, 0xFFFF375F, 0xFFBF5AF2];
    showCupertinoDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (_, set) => CupertinoAlertDialog(
          title: const Text('EDIT WALLET'),
          content: Column(
            children: [
              const SizedBox(height: 16),
              CupertinoTextField(controller: nameCtrl, placeholder: 'Name'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: colors.map((c) => GestureDetector(
                  onTap: () => set(() => color = c),
                  child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: color == c ? Border.all(color: Colors.white, width: 3) : null)),
                )).toList(),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(isDestructiveAction: true, child: const Text('DELETE'), onPressed: () { ctrl.deleteWallet(w.address); Navigator.pop(ctx); }),
            CupertinoDialogAction(child: const Text('CANCEL'), onPressed: () => Navigator.pop(ctx)),
            CupertinoDialogAction(isDefaultAction: true, child: const Text('SAVE'), onPressed: () { ctrl.updateWallet(w.address, name: nameCtrl.text, color: color); Navigator.pop(ctx); }),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext ctx) {
    showCupertinoModalPopup(
      context: ctx,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(child: const Text('Security Settings'), onPressed: () { Navigator.pop(ctx); Navigator.push(ctx, CupertinoPageRoute(builder: (_) => const PinScreen(isSettingPin: true))); }),
          CupertinoActionSheetAction(child: const Text('Refresh'), onPressed: () { Navigator.pop(ctx); context.read<WalletController>().refresh(); }),
          CupertinoActionSheetAction(child: const Text('About @glaqzz'), onPressed: () { Navigator.pop(ctx); launchUrl(Uri.parse('https://x.com/glaqzz')); }),
        ],
        cancelButton: CupertinoActionSheetAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
      ),
    );
  }

  void _showReceive(BuildContext ctx) {
    final addr = context.read<WalletController>().currentWallet?.address ?? '';
    showCupertinoModalPopup(
      context: ctx,
      builder: (_) => Container(
        height: 500, color: _bg,
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _fg.withOpacity(0.2)))),
              child: Row(children: [Text('RECEIVE', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1, color: _fg)), const Spacer(), GestureDetector(onTap: () => Navigator.pop(ctx), child: Icon(Icons.close, color: _fg))])),
            const Spacer(),
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: _fg)), child: QrImageView(data: addr, size: 180, backgroundColor: Colors.white)),
            const SizedBox(height: 20),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text(addr, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: _fg))),
            const Spacer(),
            GestureDetector(onTap: () { Clipboard.setData(ClipboardData(text: addr)); Navigator.pop(ctx); },
              child: Container(margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(16), color: _fg, child: Center(child: Text('COPY ADDRESS', style: TextStyle(color: _bg, fontWeight: FontWeight.w700))))),
          ],
        ),
      ),
    );
  }

  void _showExport(BuildContext ctx) {
    final w = context.read<WalletController>().currentWallet;
    if (w == null) return;
    showCupertinoDialog(
      context: ctx,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('EXPORT WALLET'),
        content: Column(
          children: [
            const SizedBox(height: 16),
            if (w.mnemonic != null && w.mnemonic!.isNotEmpty) ...[
              const Text('SEED PHRASE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SelectableText(w.mnemonic!, style: const TextStyle(fontSize: 11)),
              const SizedBox(height: 16),
            ],
            const Text('PRIVATE KEY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(w.privateKeyBase64, style: const TextStyle(fontSize: 9, fontFamily: 'Courier')),
          ],
        ),
        actions: [
          CupertinoDialogAction(child: const Text('COPY SEED'), onPressed: () { if (w.mnemonic != null) Clipboard.setData(ClipboardData(text: w.mnemonic!)); Navigator.pop(ctx); }),
          CupertinoDialogAction(child: const Text('CLOSE'), onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  void _showTxSheet(BuildContext ctx, String title, {bool isPublic = false, bool isEncrypt = false, bool isDecrypt = false, bool isPrivate = false}) {
    final addrCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    bool loading = false;
    showCupertinoModalPopup(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, set) => Container(
          height: 400, color: _bg,
          child: Column(
            children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _fg.withOpacity(0.2)))),
                child: Row(children: [Text(title, style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1, color: _fg)), const Spacer(), GestureDetector(onTap: () => Navigator.pop(ctx2), child: Icon(Icons.close, color: _fg))])),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPublic || isPrivate) ...[
                        Text('ADDRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _fg)),
                        const SizedBox(height: 8),
                        Container(decoration: BoxDecoration(border: Border.all(color: _fg)), child: CupertinoTextField(controller: addrCtrl, placeholder: 'Recipient', padding: const EdgeInsets.all(12), decoration: null, style: TextStyle(color: _fg))),
                        const SizedBox(height: 16),
                      ],
                      Text('AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _fg)),
                      const SizedBox(height: 8),
                      Container(decoration: BoxDecoration(border: Border.all(color: _fg)), child: CupertinoTextField(controller: amtCtrl, placeholder: '0.00', keyboardType: const TextInputType.numberWithOptions(decimal: true), padding: const EdgeInsets.all(12), decoration: null, style: TextStyle(color: _fg))),
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
                          if (res.statusCode == 200) {
                            await ctrl.refresh();
                            Navigator.of(context).push(CupertinoPageRoute(builder: (_) => SuccessAnimation(onComplete: () => Navigator.pop(context))));
                          }
                        },
                        child: Container(width: double.infinity, padding: const EdgeInsets.all(16), color: _fg, child: Center(child: loading ? CupertinoActivityIndicator(color: _bg) : Text('CONFIRM', style: TextStyle(color: _bg, fontWeight: FontWeight.w700)))),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Legacy compatibility
class DashboardTab extends StatelessWidget { const DashboardTab({super.key}); @override Widget build(BuildContext context) => const HomeTabScaffold(); }
class PrivateTab extends StatelessWidget { const PrivateTab({super.key}); @override Widget build(BuildContext context) => const HomeTabScaffold(); }
class EncryptTab extends StatelessWidget { const EncryptTab({super.key}); @override Widget build(BuildContext context) => const HomeTabScaffold(); }
class HistoryTab extends StatelessWidget { const HistoryTab({super.key}); @override Widget build(BuildContext context) => const HomeTabScaffold(); }
class SettingsTab extends StatelessWidget { const SettingsTab({super.key}); @override Widget build(BuildContext context) => const HomeTabScaffold(); }
