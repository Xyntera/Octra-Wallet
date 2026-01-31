import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Icons, Scaffold;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:local_auth/local_auth.dart';

import '../wallet.dart';
import '../models.dart';
import '../rpc.dart';
import 'wallet_setup.dart';
import 'scanner.dart';
import 'success_animation.dart';
import 'pin_screen.dart';

// ============================================================================
// OCTRA WALLET - SWISS MINIMALIST DESIGN
// Developer: @glaqzz on X
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
              children: const [WalletTab(), EncryptTab(), HistoryTab(), SettingsTab()],
            ),
          ),
          _buildTabBar(),
          // Developer Credit Watermark
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: GestureDetector(
              onTap: () => launchUrl(Uri.parse('https://x.com/glaqzz')),
              child: Text('DEV @GLAQZZ', style: TextStyle(fontFamily: 'Courier New', fontSize: 8, letterSpacing: 1, color: Colors.grey[400])),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black, width: 1))),
      height: 56,
      child: Row(children: [
        _buildTab('WALLET', 0, CupertinoIcons.creditcard),
        _buildTab('ENCRYPT', 1, CupertinoIcons.lock),
        _buildTab('HISTORY', 2, CupertinoIcons.time),
        _buildTab('SETTINGS', 3, CupertinoIcons.gear),
      ]),
    );
  }

  Widget _buildTab(String label, int index, IconData icon) {
    final isActive = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isActive ? Colors.black : Colors.grey),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontFamily: 'Helvetica Neue', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1, color: isActive ? Colors.black : Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WALLET TAB - Clean Dashboard
// ============================================================================
class WalletTab extends StatefulWidget {
  const WalletTab({super.key});
  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  bool _showPrivate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<WalletController>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<WalletController>();
    final wallet = ctrl.currentWallet;
    if (wallet == null) return const Center(child: CupertinoActivityIndicator());

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(context, ctrl),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Balance Card
                  _buildBalanceCard(ctrl),
                  const SizedBox(height: 24),
                  // Actions
                  _buildActionButton('SEND', CupertinoIcons.arrow_up_circle, () => _showSendSheet(context)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _buildSecondaryBtn('RECEIVE', () => _showReceiveSheet(context, wallet.address))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSecondaryBtn('SCAN', () => _openScanner(context))),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WalletController ctrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showWalletPicker(context, ctrl),
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: Color(ctrl.currentWallet?.color ?? 0xFF000000), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(ctrl.currentWallet?.name.toUpperCase() ?? 'WALLET', style: const TextStyle(fontFamily: 'Helvetica Neue', fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2)),
              const SizedBox(width: 4),
              const Icon(CupertinoIcons.chevron_down, size: 14),
            ]),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => ctrl.refresh(),
            child: ctrl.isLoading ? const CupertinoActivityIndicator(radius: 10) : const Icon(CupertinoIcons.refresh, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(WalletController ctrl) {
    return GestureDetector(
      onTap: () => setState(() => _showPrivate = !_showPrivate),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_showPrivate ? 'PRIVATE BALANCE' : 'PUBLIC BALANCE', style: TextStyle(fontFamily: 'Courier New', fontSize: 10, color: Colors.white.withOpacity(0.6), letterSpacing: 1)),
                Icon(_showPrivate ? CupertinoIcons.lock_fill : CupertinoIcons.lock_open, size: 14, color: Colors.white54),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _showPrivate ? '${ctrl.encryptedBalance.toStringAsFixed(6)} OCT' : '${ctrl.publicBalance.toStringAsFixed(6)} OCT',
              style: const TextStyle(fontFamily: 'Helvetica Neue', fontSize: 32, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: -1),
            ),
            const SizedBox(height: 8),
            Text('TAP TO ${_showPrivate ? 'SHOW PUBLIC' : 'SHOW PRIVATE'}', style: TextStyle(fontFamily: 'Courier New', fontSize: 9, color: Colors.white.withOpacity(0.4))),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(border: Border.all(color: Colors.black)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontFamily: 'Helvetica Neue', fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(border: Border.all(color: Colors.black)),
        child: Center(child: Text(label, style: const TextStyle(fontFamily: 'Helvetica Neue', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5))),
      ),
    );
  }

  void _showWalletPicker(BuildContext context, WalletController ctrl) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 400,
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
              child: Row(children: [
                const Text('SELECT WALLET', style: TextStyle(fontFamily: 'Helvetica Neue', fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2)),
                const Spacer(),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, size: 20)),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: ctrl.wallets.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == ctrl.wallets.length) {
                    return ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('ADD WALLET'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(builder: (_) => const WalletSetupPage()));
                      },
                    );
                  }
                  final w = ctrl.wallets[i];
                  return ListTile(
                    leading: Container(width: 24, height: 24, decoration: BoxDecoration(color: Color(w.color), shape: BoxShape.circle)),
                    title: Text(w.name.toUpperCase()),
                    subtitle: Text('${w.address.substring(0, 12)}...', style: const TextStyle(fontFamily: 'Courier New', fontSize: 10)),
                    trailing: w == ctrl.currentWallet ? const Icon(Icons.check, color: Colors.green) : null,
                    onTap: () {
                      ctrl.selectWallet(w);
                      Navigator.pop(context);
                    },
                    onLongPress: () {
                      Navigator.pop(context);
                      _showEditWallet(context, w, ctrl);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditWallet(BuildContext context, Wallet w, WalletController ctrl) {
    final nameCtrl = TextEditingController(text: w.name);
    int selectedColor = w.color;
    final colors = [0xFF000000, 0xFF357AF6, 0xFF32D74B, 0xFFFF9F0A, 0xFFFF375F, 0xFFBF5AF2, 0xFFFFD60A, 0xFF64D2FF];

    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState2) => CupertinoAlertDialog(
          title: const Text('EDIT WALLET'),
          content: Column(
            children: [
              const SizedBox(height: 16),
              CupertinoTextField(controller: nameCtrl, placeholder: 'Wallet Name'),
              const SizedBox(height: 16),
              const Text('COLOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: colors.map((c) => GestureDetector(
                  onTap: () => setState2(() => selectedColor = c),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: selectedColor == c ? Border.all(color: Colors.white, width: 3) : null),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(child: const Text('DELETE', style: TextStyle(color: Colors.red)), onPressed: () {
              ctrl.deleteWallet(w.address);
              Navigator.pop(ctx);
            }),
            CupertinoDialogAction(child: const Text('CANCEL'), onPressed: () => Navigator.pop(ctx)),
            CupertinoDialogAction(child: const Text('SAVE'), isDefaultAction: true, onPressed: () {
              ctrl.updateWallet(w.address, name: nameCtrl.text, color: selectedColor);
              Navigator.pop(ctx);
            }),
          ],
        ),
      ),
    );
  }

  void _showSendSheet(BuildContext context) => _showTxForm(context, title: 'SEND', isPublic: true);
  void _showReceiveSheet(BuildContext ctx, String addr) {
    showCupertinoModalPopup(context: ctx, builder: (_) => Container(
      height: 500, color: Colors.white,
      child: Column(children: [
        Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
          child: Row(children: [const Text('RECEIVE', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2)), const Spacer(), GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close))])),
        const SizedBox(height: 24),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.black)), child: QrImageView(data: addr, size: 180)),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Text(addr, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Courier New', fontSize: 10))),
        const SizedBox(height: 16),
        GestureDetector(onTap: () { Clipboard.setData(ClipboardData(text: addr)); Navigator.pop(ctx); },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), color: Colors.black, child: const Text('COPY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1)))),
      ]),
    ));
  }
  void _openScanner(BuildContext ctx) async {
    final result = await Navigator.of(ctx).push<String>(CupertinoPageRoute(builder: (_) => const ScannerPage()));
    if (result != null) _showTxForm(ctx, title: 'SEND', isPublic: true, prefill: result);
  }
}

// ============================================================================
// ENCRYPT TAB
// ============================================================================
class EncryptTab extends StatelessWidget {
  const EncryptTab({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<WalletController>();
    return SafeArea(
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
            child: const Row(children: [Text('PRIVATE OPERATIONS', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2))])),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(20), color: Colors.black,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('ENCRYPTED', style: TextStyle(fontFamily: 'Courier New', fontSize: 10, color: Colors.white.withOpacity(0.6))),
                      const SizedBox(height: 8),
                      Text('${ctrl.encryptedBalance.toStringAsFixed(6)} OCT', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _btn('ENCRYPT', () => _showTxForm(context, title: 'ENCRYPT', isEncrypt: true))),
                    const SizedBox(width: 12),
                    Expanded(child: _btn('DECRYPT', () => _showTxForm(context, title: 'DECRYPT', isDecrypt: true))),
                  ]),
                  const SizedBox(height: 12),
                  _btn('PRIVATE TRANSFER', () => _showTxForm(context, title: 'PRIVATE TRANSFER', isPrivate: true)),
                  const SizedBox(height: 24),
                  const Align(alignment: Alignment.centerLeft, child: Text('PENDING CLAIMS', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1))),
                  const SizedBox(height: 12),
                  if (ctrl.pendingPrivateTransfers.isEmpty)
                    Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!)),
                      child: const Center(child: Text('NO PENDING', style: TextStyle(color: Colors.grey))))
                  else
                    ...ctrl.pendingPrivateTransfers.map((tx) => _claimTile(context, tx, ctrl)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(height: 48, decoration: BoxDecoration(border: Border.all(color: Colors.black)),
      child: Center(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)))),
  );

  Widget _claimTile(BuildContext ctx, dynamic tx, WalletController ctrl) {
    final id = tx['id'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.black)),
      child: Row(children: [
        const Icon(CupertinoIcons.gift, size: 18),
        const SizedBox(width: 12),
        Expanded(child: Text('TRANSFER #$id', style: const TextStyle(fontWeight: FontWeight.w600))),
        GestureDetector(
          onTap: () async {
            final ok = await ctrl.claimTransfer(id.toString(), tx['ephemeral_public_key'], tx['encrypted_amount']);
            showCupertinoDialog(context: ctx, builder: (_) => CupertinoAlertDialog(title: Text(ok ? 'CLAIMED' : 'FAILED'), actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(ctx))]));
          },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), color: Colors.black, child: const Text('CLAIM', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
        ),
      ]),
    );
  }
}

// ============================================================================
// HISTORY TAB
// ============================================================================
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<WalletController>();
    return SafeArea(
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
            child: Row(children: [const Text('TRANSACTION HISTORY', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2)), const Spacer(), GestureDetector(onTap: () => ctrl.refresh(), child: const Icon(CupertinoIcons.refresh, size: 18))])),
          Expanded(
            child: ctrl.history.isEmpty
              ? const Center(child: Text('NO TRANSACTIONS', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: ctrl.history.length,
                  itemBuilder: (_, i) {
                    final tx = ctrl.history[i];
                    final isIn = tx['direction'] == 'IN';
                    final amt = double.tryParse(tx['amount'].toString()) ?? 0;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
                      child: Row(children: [
                        Container(width: 36, height: 36, decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                          child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, size: 16)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isIn ? 'RECEIVED' : 'SENT', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${(tx['hash'] ?? '').toString().substring(0, 12)}...', style: const TextStyle(fontFamily: 'Courier New', fontSize: 10, color: Colors.grey)),
                        ])),
                        Text('${isIn ? '+' : '-'}${amt.toStringAsFixed(2)} OCT', style: TextStyle(fontWeight: FontWeight.w600, color: isIn ? Colors.green : Colors.black)),
                      ]),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SETTINGS TAB
// ============================================================================
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<WalletController>();
    return SafeArea(
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
            child: const Row(children: [Text('SETTINGS', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2))])),
          Expanded(
            child: ListView(
              children: [
                _settingItem('SECURITY & BIOMETRICS', CupertinoIcons.lock_shield, () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const SecurityPage()))),
                _settingItem('EXPORT WALLET', CupertinoIcons.square_arrow_up, () => _exportWallet(context, ctrl)),
                _settingItem('ABOUT', CupertinoIcons.info, () => _showAbout(context)),
                const Divider(),
                Padding(padding: const EdgeInsets.all(20), child: Center(child: GestureDetector(
                  onTap: () => launchUrl(Uri.parse('https://x.com/glaqzz')),
                  child: const Text('DEVELOPED BY @GLAQZZ', style: TextStyle(fontFamily: 'Courier New', fontSize: 10, color: Colors.grey, letterSpacing: 1)),
                ))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingItem(String label, IconData icon, VoidCallback onTap) => ListTile(leading: Icon(icon, size: 20), title: Text(label, style: const TextStyle(letterSpacing: 1)), trailing: const Icon(Icons.chevron_right, size: 18), onTap: onTap);

  void _exportWallet(BuildContext ctx, WalletController ctrl) {
    final w = ctrl.currentWallet;
    if (w == null) return;
    showCupertinoDialog(context: ctx, builder: (_) => CupertinoAlertDialog(
      title: const Text('EXPORT WALLET'),
      content: Column(children: [
        const SizedBox(height: 16),
        if (w.mnemonic != null && w.mnemonic!.isNotEmpty) ...[const Text('SEED PHRASE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(height: 8), SelectableText(w.mnemonic!, style: const TextStyle(fontSize: 11)), const SizedBox(height: 16)],
        const Text('PRIVATE KEY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SelectableText(w.privateKeyBase64, style: const TextStyle(fontSize: 9)),
      ]),
      actions: [
        CupertinoDialogAction(child: const Text('COPY SEED'), onPressed: () { if (w.mnemonic != null) Clipboard.setData(ClipboardData(text: w.mnemonic!)); Navigator.pop(ctx); }),
        CupertinoDialogAction(child: const Text('CLOSE'), onPressed: () => Navigator.pop(ctx)),
      ],
    ));
  }

  void _showAbout(BuildContext ctx) => showCupertinoDialog(context: ctx, builder: (_) => CupertinoAlertDialog(
    title: const Text('OCTRA WALLET'),
    content: const Column(children: [SizedBox(height: 16), Text('Built by ouqro.tech'), Text('Developer: @glaqzz'), SizedBox(height: 8), Text('v1.0.0', style: TextStyle(fontSize: 12, color: Colors.grey))]),
    actions: [CupertinoDialogAction(child: const Text('CLOSE'), onPressed: () => Navigator.pop(ctx))],
  ));
}

// ============================================================================
// SECURITY PAGE - Biometrics / PIN
// ============================================================================
class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});
  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final _auth = LocalAuthentication();
  bool _canBiometric = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    try {
      _canBiometric = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.white,
      navigationBar: const CupertinoNavigationBar(middle: Text('SECURITY'), backgroundColor: Colors.white),
      child: SafeArea(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.lock),
              title: const Text('CHANGE PIN'),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const PinScreen(isSetup: true))),
            ),
            if (_canBiometric)
              SwitchListTile(
                secondary: const Icon(CupertinoIcons.hand_raised),
                title: const Text('BIOMETRICS'),
                subtitle: const Text('Fingerprint / Face ID', style: TextStyle(fontSize: 12)),
                value: _biometricEnabled,
                onChanged: (v) async {
                  if (v) {
                    final ok = await _auth.authenticate(localizedReason: 'Enable biometric login');
                    if (ok) setState(() => _biometricEnabled = true);
                  } else {
                    setState(() => _biometricEnabled = false);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TRANSACTION FORM
// ============================================================================
void _showTxForm(BuildContext context, {required String title, bool isPublic = false, bool isEncrypt = false, bool isDecrypt = false, bool isPrivate = false, String? prefill}) {
  showCupertinoModalPopup(context: context, builder: (_) => _TxFormSheet(title: title, isPublic: isPublic, isEncrypt: isEncrypt, isDecrypt: isDecrypt, isPrivate: isPrivate, prefill: prefill));
}

class _TxFormSheet extends StatefulWidget {
  final String title;
  final bool isPublic, isEncrypt, isDecrypt, isPrivate;
  final String? prefill;
  const _TxFormSheet({required this.title, this.isPublic = false, this.isEncrypt = false, this.isDecrypt = false, this.isPrivate = false, this.prefill});
  @override
  State<_TxFormSheet> createState() => _TxFormSheetState();
}

class _TxFormSheetState extends State<_TxFormSheet> {
  final _addrCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefill != null) _addrCtrl.text = widget.prefill!;
  }

  @override
  Widget build(BuildContext context) {
    final needsAddr = widget.isPublic || widget.isPrivate;
    return Container(
      height: 400, color: Colors.white,
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
            child: Row(children: [Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2)), const Spacer(), GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close))])),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (needsAddr) ...[
                    const Text('ADDRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(decoration: BoxDecoration(border: Border.all(color: Colors.black)), child: CupertinoTextField(controller: _addrCtrl, placeholder: 'Recipient address', padding: const EdgeInsets.all(12), decoration: null)),
                    const SizedBox(height: 16),
                  ],
                  const Text('AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(decoration: BoxDecoration(border: Border.all(color: Colors.black)), child: CupertinoTextField(controller: _amtCtrl, placeholder: '0.00', keyboardType: const TextInputType.numberWithOptions(decimal: true), padding: const EdgeInsets.all(12), decoration: null)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _loading ? null : _submit,
                    child: Container(
                      width: double.infinity, height: 48, color: Colors.black,
                      child: Center(child: _loading ? const CupertinoActivityIndicator(color: Colors.white) : Text('CONFIRM', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1))),
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
    final ctrl = context.read<WalletController>();
    final amt = double.tryParse(_amtCtrl.text) ?? 0;
    if (amt <= 0) return;
    final addr = _addrCtrl.text.trim();
    if ((widget.isPublic || widget.isPrivate) && addr.isEmpty) return;

    setState(() => _loading = true);
    try {
      RpcResponse res;
      if (widget.isPublic) res = await ctrl.sendTransaction(addr, amt, null);
      else if (widget.isEncrypt) res = await ctrl.encryptMoney(amt);
      else if (widget.isDecrypt) res = await ctrl.decryptMoney(amt);
      else res = await ctrl.makePrivateTransfer(addr, amt);

      Navigator.pop(context);
      if (res.statusCode == 200) {
        await ctrl.refresh();
        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => SuccessAnimation(message: '${widget.title} Success')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// Legacy aliases
class DashboardTab extends StatelessWidget { const DashboardTab({super.key}); @override Widget build(BuildContext context) => const WalletTab(); }
class PrivateTab extends StatelessWidget { const PrivateTab({super.key}); @override Widget build(BuildContext context) => const EncryptTab(); }
