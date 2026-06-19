import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        Alignment,
        Border,
        BorderRadius,
        BoxDecoration,
        Colors,
        Divider,
        Gradient,
        Icons,
        LinearGradient;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../wallet.dart';
import '../eth/eth_wallet_store.dart';
import 'bridge.dart';
import 'wallet_setup.dart';
import 'pin_screen.dart';
import 'portfolio.dart';
import 'scanner.dart';

const int _octMicro = 1000000;

String _formatOct(double value) {
  final fixed = value.toStringAsFixed(6);
  final trimmed = fixed.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.endsWith('.') ? '${trimmed}00' : trimmed;
}

/// Soft sanity check; the node remains the source of truth.
bool _looksLikeOctraAddress(String value) {
  return value.startsWith('oct') && value.length >= 40 && value.length <= 64;
}

/// Turns raw exception/RPC strings into something a person can act on.
String _friendlyError(Object error) {
  var text = error.toString();
  text = text
      .replaceFirst(RegExp(r'^(StateError|Exception|Bad state|Error)[:\s]*'), '')
      .replaceFirst(RegExp(r'^TimeoutException[:\s]*'), '')
      .trim();
  final lower = text.toLowerCase();
  if (lower.contains('timed out')) {
    return 'The operation timed out. Privacy proofs can take several minutes '
        'on slower devices — please try again and keep the app in the foreground.';
  }
  if (lower.contains('socketexception') ||
      lower.contains('connection failed') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable')) {
    return 'Could not reach the Octra network. Check your internet connection '
        'and RPC settings, then try again.';
  }
  return text.isEmpty ? 'Something went wrong. Please try again.' : text;
}

void _copyToClipboard(String value) {
  Clipboard.setData(ClipboardData(text: value));
  HapticFeedback.lightImpact();
}

Future<bool> _confirmWalletAction(BuildContext context) async {
  final wallet = context.read<WalletController>();
  if (!context.mounted) return false;

  if (!wallet.hasPinSync) {
    final String? pin = await Navigator.of(context, rootNavigator: true).push<String>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PinScreen(isSettingPin: true),
      ),
    );
    if (pin == null || pin.length < 4) return false;
    await wallet.setPin(pin);
    return true;
  }

  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    CupertinoPageRoute(
      fullscreenDialog: true,
      builder: (_) => const PinScreen(isChecking: true),
    ),
  );
  return result == true;
}

Future<bool> _confirmFeeAndSecurity(
  BuildContext context, {
  required String title,
  required String feeOperation,
  String? amountLabel,
  double? publicAmount,
}) async {
  final wallet = context.read<WalletController>();
  final feeRaw = await wallet.recommendedFeeRaw(feeOperation);
  final feeOct = (int.tryParse(feeRaw) ?? 0) / _octMicro;
  final totalLabel = publicAmount == null
      ? null
      : '${(publicAmount + feeOct).toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '')} OCT';
  if (!context.mounted) return false;

  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Column(
        children: [
          if (amountLabel != null) Text('Amount: $amountLabel'),
          Text('Network fee: ${wallet.formatFeeRaw(feeRaw)}'),
          if (totalLabel != null) Text('Total public cost: $totalLabel'),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  return true;
}

Future<void> _openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Widget _keyboardAwareSheet(
  BuildContext context, {
  required Widget child,
  double maxHeightFactor = 0.9,
}) {
  final media = MediaQuery.of(context);
  return AnimatedPadding(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
    child: Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: media.size.height * maxHeightFactor),
        child: child,
      ),
    ),
  );
}

Widget _sheetHandle() {
  return Center(
    child: Container(
      margin: const EdgeInsets.only(bottom: 18),
      height: 4,
      width: 40,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

Widget _sheetTitle(String title, {String? subtitle}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, height: 1.35),
        ),
      ],
    ],
  );
}

const BoxDecoration _sheetDecoration = BoxDecoration(
  color: Color(0xFF1C1C1E),
  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
);

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: Colors.white38),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class HomeTabScaffold extends StatelessWidget {
  const HomeTabScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            backgroundColor: const Color(0xCC1C1C1E),
            activeColor: CupertinoColors.systemBlue,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.chart_bar_alt_fill),
                label: 'Portfolio',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.time),
                label: 'History',
              ),
            ],
          ),
          tabBuilder: (context, index) {
            switch (index) {
              case 0:
                return const DashboardTab();
              case 1:
                return const PortfolioTab();
              case 2:
                return const HistoryTab();
              default:
                return const DashboardTab();
            }
          },
        ),
        const _PvacBusyOverlay(),
      ],
    );
  }
}

class _PvacBusyOverlay extends StatefulWidget {
  const _PvacBusyOverlay();

  @override
  State<_PvacBusyOverlay> createState() => _PvacBusyOverlayState();
}

class _PvacBusyOverlayState extends State<_PvacBusyOverlay> {
  Timer? _ticker;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker(bool busy) {
    if (busy && _ticker == null) {
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _startedAt == null) return;
        setState(() => _elapsed = DateTime.now().difference(_startedAt!));
      });
    } else if (!busy && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
      _startedAt = null;
      _elapsed = Duration.zero;
    }
  }

  String get _elapsedLabel {
    final m = _elapsed.inMinutes;
    final s = _elapsed.inSeconds % 60;
    return m > 0 ? '${m}m ${s.toString().padLeft(2, '0')}s' : '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletController>();
    final busy = wallet.isPvacBusy;
    _syncTicker(busy);

    return IgnorePointer(
      ignoring: !busy,
      child: AnimatedOpacity(
        opacity: busy ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: !busy
            ? const SizedBox.expand()
            : SizedBox.expand(
                child: ColoredBox(
                  color: const Color(0xCC000000),
                  child: SafeArea(
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 32,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CupertinoActivityIndicator(radius: 16),
                            const SizedBox(height: 16),
                            Text(
                              wallet.pvacStatus ?? 'Running PVAC operation',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                _elapsedLabel,
                                key: ValueKey(_elapsedLabel),
                                style: GoogleFonts.outfit(
                                  color: CupertinoColors.systemBlue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Generating zero-knowledge proofs on this device. '
                              'This can take a few minutes — keep the app open.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
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

    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle:
                Text('Octra', style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: const Color(0xCC1C1C1E),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showSideMenu(context),
              child: const Icon(CupertinoIcons.bars,
                  color: CupertinoColors.systemBlue),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showWalletsSheet(context),
              child: const Icon(CupertinoIcons.square_list,
                  color: CupertinoColors.systemBlue),
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              await walletCtrl.refresh();
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildBalanceCard(
                    title: 'Public Balance',
                    balance: walletCtrl.publicBalance,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    icon: CupertinoIcons.globe,
                  ).animate(key: ValueKey('pub-${wallet.address}')).scale(delay: 100.ms),
                  const SizedBox(height: 12),
                  _buildBalanceCard(
                    title: 'Private Balance',
                    balance: walletCtrl.encryptedBalance,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF103B2F), Color(0xFF00A86B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    icon: CupertinoIcons.lock_shield,
                  ).animate(key: ValueKey('priv-${wallet.address}')).scale(delay: 140.ms),
                  const SizedBox(height: 12),
                  Text(
                    walletCtrl.nativeCore.isAvailable
                        ? 'Native PVAC core active'
                        : 'Native PVAC core unavailable: '
                            '${walletCtrl.nativeCore.unavailableReason ?? 'unknown loader error'}',
                    style:
                        GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildStatusChip(
                        icon: CupertinoIcons.globe,
                        label: walletCtrl.activeNetworkLabelSync,
                      ),
                      _buildStatusChip(
                        icon: Icons.link,
                        label: Uri.tryParse(walletCtrl.rpcBaseUrlSync)?.host ??
                            walletCtrl.rpcBaseUrlSync,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  RepaintBoundary(
                    child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 22,
                    runSpacing: 20,
                    children: [
                      _buildActionButton(
                        context,
                        icon: CupertinoIcons.arrow_up_right,
                        label: 'Send',
                        onTap: () => _showPublicSendSheet(context),
                      ),
                      _buildActionButton(
                        context,
                        icon: CupertinoIcons.arrow_down_doc,
                        label: 'Receive',
                        onTap: () => _showReceiveSheet(context, wallet.address),
                      ),
                      _buildActionButton(
                        context,
                        icon: CupertinoIcons.lock_rotation,
                        label: 'Encrypt',
                        onTap: () =>
                            _showPrivacyAmountSheet(context, encrypt: true),
                      ),
                      _buildActionButton(
                        context,
                        icon: CupertinoIcons.lock_open,
                        label: 'Decrypt',
                        onTap: () =>
                            _showPrivacyAmountSheet(context, encrypt: false),
                      ),
                      _buildActionButton(
                        context,
                        icon: CupertinoIcons.paperplane,
                        label: 'Private Send',
                        onTap: () => _showPrivateSendSheet(context),
                      ),
                      _buildActionButton(
                        context,
                        icon: CupertinoIcons.tray_arrow_down,
                        label: 'Claims',
                        onTap: () => _showStealthClaimsSheet(context),
                      ),
                      _buildActionButton(
                        context,
                        icon: CupertinoIcons.person_3,
                        label: 'Bulk',
                        onTap: () => _showBulkSendSheet(context),
                      ),
                      _buildActionButton(
                        context,
                        icon: CupertinoIcons.square_list,
                        label: 'Wallets',
                        onTap: () => _showWalletsSheet(context),
                      ),
                      _buildActionButton(
                        context,
                        icon: CupertinoIcons.arrow_2_squarepath,
                        label: 'Bridge',
                        onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute(
                              builder: (_) => const BridgeScreen()),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms),
                  ), // RepaintBoundary
                  const SizedBox(height: 12),
                  _EvmWalletCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required double balance,
    required Gradient gradient,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(end: balance),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              '${_formatOct(value)} OCT',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _ActionButton(icon: icon, label: label, onTap: onTap);
  }

  void _showSideMenu(BuildContext context) {
    final rootContext = context;
    final walletCtrl = context.read<WalletController>();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close menu',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, _, __) {
        return Align(
          alignment: Alignment.centerLeft,
          child: SafeArea(
            child: Container(
              width: MediaQuery.of(dialogContext).size.width * 0.88,
              constraints: const BoxConstraints(maxWidth: 360),
              height: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF111114),
                borderRadius:
                    BorderRadius.horizontal(right: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 28,
                      offset: Offset(12, 0)),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Octra Wallet',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Icon(CupertinoIcons.xmark_circle_fill,
                              color: Colors.white54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (walletCtrl.hasWallet) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(walletCtrl.currentWallet!.color)
                                  .withValues(alpha: 0.26),
                              Colors.white.withValues(alpha: 0.06),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Color(walletCtrl.currentWallet!.color)
                                .withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Color(walletCtrl.currentWallet!.color),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    walletCtrl.currentWallet!.name,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${walletCtrl.currentWallet!.address.substring(0, 10)}...'
                                    '${walletCtrl.currentWallet!.address.substring(walletCtrl.currentWallet!.address.length - 6)}',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 13),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildStatusChip(
                                        icon: CupertinoIcons.globe,
                                        label: walletCtrl.activeNetworkLabelSync,
                                      ),
                                      _buildStatusChip(
                                        icon: Icons.link,
                                        label: Uri.tryParse(
                                                    walletCtrl.rpcBaseUrlSync)
                                                ?.host ??
                                            walletCtrl.rpcBaseUrlSync,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMenuItem(dialogContext, 'Switch Wallet',
                          CupertinoIcons.rectangle_stack_person_crop, () {
                        Navigator.pop(dialogContext);
                        _showWalletsSheet(rootContext);
                      }),
                      _buildMenuItem(dialogContext, 'Export Wallet',
                          CupertinoIcons.doc_text, () {
                        Navigator.pop(dialogContext);
                        _showExportWalletSheet(rootContext);
                      }),
                      _buildMenuItem(dialogContext, 'Public Send',
                          CupertinoIcons.arrow_up_right, () {
                        Navigator.pop(dialogContext);
                        _showPublicSendSheet(rootContext);
                      }),
                      _buildMenuItem(
                          dialogContext, 'Bulk Send', CupertinoIcons.person_3,
                          () {
                        Navigator.pop(dialogContext);
                        _showBulkSendSheet(rootContext);
                      }),
                      _buildMenuItem(
                          dialogContext, 'Tokens', CupertinoIcons.cube_box, () {
                        Navigator.pop(dialogContext);
                        _showTokensSheet(rootContext);
                      }),
                      _buildMenuItem(dialogContext, 'Register PVAC Key',
                          CupertinoIcons.lock_shield, () async {
                        Navigator.pop(dialogContext);
                        await _registerPvacKey(rootContext);
                      }),
                      _buildMenuItem(dialogContext, 'Private Send',
                          CupertinoIcons.paperplane, () {
                        Navigator.pop(dialogContext);
                        _showPrivateSendSheet(rootContext);
                      }),
                      _buildMenuItem(dialogContext, 'Scan Claims',
                          CupertinoIcons.tray_arrow_down, () {
                        Navigator.pop(dialogContext);
                        _showStealthClaimsSheet(rootContext);
                      }),
                      const SizedBox(
                        height: 28,
                        child: Center(
                            child: Divider(color: Colors.white12, height: 1)),
                      ),
                    ],
                    _buildMenuItem(
                        dialogContext, 'Settings', CupertinoIcons.settings,
                        () {
                      Navigator.pop(dialogContext);
                      Navigator.of(rootContext).push(
                        CupertinoPageRoute(
                            builder: (_) => const SecuritySettingsPage()),
                      );
                    }),
                    _buildMenuItem(dialogContext, 'About', CupertinoIcons.info,
                        () {
                      Navigator.pop(dialogContext);
                      _showAboutDialog(rootContext);
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('About Octra Wallet'),
        content: const Text(
          'Octra Wallet\n'
          'octrawallet.app\n'
          'By Glaqz\n\n'
          'OCT metadata: CoinGecko octra\n'
          'Contract: 0x4647e1fe715c9e23959022c2416c71867f5a6e80',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => _openExternalUrl('https://octrawallet.app'),
            child: const Text('Website'),
          ),
          CupertinoDialogAction(
            onPressed: () =>
                _openExternalUrl('https://www.coingecko.com/en/coins/octra'),
            child: const Text('Price'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showExportWalletSheet(BuildContext context) async {
    final walletCtrl = context.read<WalletController>();
    final wallet = walletCtrl.currentWallet;
    if (wallet == null) return;
    final confirmed = await _confirmWalletAction(context);
    if (!confirmed || !context.mounted) return;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => _keyboardAwareSheet(
        context,
        child: Container(
          decoration: _sheetDecoration,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sheetHandle(),
                  _sheetTitle('Export Wallet'),
                  const SizedBox(height: 8),
                  const Text(
                    'Keep this offline. Anyone with these secrets can spend the wallet.',
                    style: TextStyle(color: CupertinoColors.systemRed),
                  ),
                  const SizedBox(height: 20),
                  _secretBlock(
                    title: 'Seed Phrase',
                    value: (wallet.mnemonic ?? '').trim().isEmpty
                        ? 'No seed phrase stored for this wallet.'
                        : wallet.mnemonic!.trim(),
                    copyable: (wallet.mnemonic ?? '').trim().isNotEmpty,
                  ),
                  const SizedBox(height: 16),
                  _secretBlock(
                    title: 'Private Key',
                    value: wallet.privateKeyBase64,
                    copyable: true,
                  ),
                  const SizedBox(height: 16),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _secretBlock({
    required String title,
    required String value,
    required bool copyable,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.sourceCodePro(
                color: Colors.white, fontSize: 13, height: 1.35),
          ),
          if (copyable) ...[
            const SizedBox(height: 10),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _copyToClipboard(value),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.doc_on_doc, size: 18),
                  SizedBox(width: 8),
                  Text('Copy'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return CupertinoButton(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 16),
            Text(title,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
            const Spacer(),
            const Icon(CupertinoIcons.chevron_right,
                color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  void _showWalletsSheet(BuildContext context) {
    final rootContext = context;
    final walletCtrl = context.read<WalletController>();
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        final walletCount = walletCtrl.wallets.length;
        final maxHeight = MediaQuery.of(context).size.height * 0.6;
        final contentHeight = 88.0 + (walletCount + 1) * 64.0;
        final sheetHeight = contentHeight.clamp(220.0, maxHeight);
        return Container(
          height: sheetHeight,
          decoration: _sheetDecoration,
          child: Column(
            children: [
              const SizedBox(height: 14),
              _sheetHandle(),
              Text(
                'Wallets',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
              child: ListView.builder(
                itemCount: walletCtrl.wallets.length + 1,
                itemBuilder: (ctx, idx) {
                  if (idx == walletCtrl.wallets.length) {
                    return CupertinoButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(rootContext, rootNavigator: true).push(
                          CupertinoPageRoute(
                              builder: (_) => const WalletSetupPage()),
                        );
                      },
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.add),
                          SizedBox(width: 8),
                          Text('Add Wallet'),
                        ],
                      ),
                    );
                  }

                  final w = walletCtrl.wallets[idx];
                  final isSelected = w == walletCtrl.currentWallet;
                  return CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    onPressed: () {
                      walletCtrl.selectWallet(w);
                      Navigator.pop(context);
                    },
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.circle,
                          color: isSelected ? Colors.green : Colors.grey,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Color(w.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w.name,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${w.address.substring(0, 10)}...',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        );
      },
    );
  }

  void _showReceiveSheet(BuildContext context, String address) {
    final walletName = context.read<WalletController>().currentWallet?.name;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _ReceiveSheet(address: address, name: walletName),
    );
  }

  void _showPublicSendSheet(BuildContext context) {
    final parentContext = context;
    final addressController = TextEditingController();
    final amountController = TextEditingController();
    final messageController = TextEditingController();
    var isSubmitting = false;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => _keyboardAwareSheet(
          context,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            decoration: _sheetDecoration,
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sheetHandle(),
                    _sheetTitle('Public Send',
                        subtitle:
                            'Transfer OCT from your public balance on-chain.'),
                    const SizedBox(height: 20),
                    _walletTextField(
                      addressController,
                      'Recipient Octra address',
                      suffix: _scanSuffix(context, addressController),
                    ),
                    const SizedBox(height: 12),
                    _walletTextField(
                      amountController,
                      'Amount in OCT',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    _walletTextField(messageController, 'Message optional'),
                    const SizedBox(height: 20),
                    CupertinoButton.filled(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final to = addressController.text.trim();
                              final amount =
                                  double.tryParse(amountController.text.trim());
                              if (to.isEmpty || amount == null || amount <= 0) {
                                _showResultDialog(context,
                                    'Enter a recipient address and valid amount');
                                return;
                              }
                              if (!_looksLikeOctraAddress(to)) {
                                _showResultDialog(context,
                                    'That does not look like an Octra address. Addresses start with "oct".');
                                return;
                              }
                              final wallet = context.read<WalletController>();
                              setState(() {
                                isSubmitting = true;
                              });
                              try {
                                final confirmed = await _confirmFeeAndSecurity(
                                  parentContext,
                                  title: 'Confirm Public Send',
                                  feeOperation: 'standard',
                                  amountLabel: '$amount OCT',
                                  publicAmount: amount,
                                );
                                if (!confirmed) {
                                  setState(() {
                                    isSubmitting = false;
                                  });
                                  return;
                                }
                                final res = await wallet.sendTransaction(
                                  to,
                                  amount,
                                  messageController.text.trim(),
                                );
                                final err = wallet.rpc.rpcError(res);
                                if (err != null) {
                                  // Keep the sheet open so the input survives a retry.
                                  if (!context.mounted) return;
                                  setState(() => isSubmitting = false);
                                  _showResultDialog(context, _friendlyError(err));
                                  return;
                                }
                                if (context.mounted) Navigator.pop(context);
                                if (parentContext.mounted) {
                                  _showRpcResult(parentContext, wallet, res);
                                }
                              } catch (e) {
                                if (!context.mounted) return;
                                setState(() => isSubmitting = false);
                                _showResultDialog(context, _friendlyError(e));
                              }
                            },
                      child: isSubmitting
                          ? const CupertinoActivityIndicator()
                          : const Text('Send'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivacyAmountSheet(BuildContext context, {required bool encrypt}) {
    final parentContext = context;
    final controller = TextEditingController();
    var isSubmitting = false;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => _keyboardAwareSheet(
          context,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            decoration: _sheetDecoration,
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sheetHandle(),
                    _sheetTitle(
                      encrypt ? 'Encrypt Public OCT' : 'Decrypt Private OCT',
                      subtitle: encrypt
                          ? 'Move public balance into encrypted private balance.'
                          : 'Move encrypted private balance back to public balance. '
                              'Building the proof takes a few minutes on-device.',
                    ),
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final wallet = context.read<WalletController>();
                      final available = encrypt
                          ? wallet.publicBalance
                          : wallet.encryptedBalance;
                      return Text(
                        'Available: ${_formatOct(available)} OCT',
                        style: GoogleFonts.outfit(
                            color: Colors.white38, fontSize: 13),
                      );
                    }),
                    const SizedBox(height: 10),
                    CupertinoTextField(
                      controller: controller,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      placeholder: 'Amount in OCT',
                      style: const TextStyle(color: Colors.white),
                      placeholderStyle: const TextStyle(color: Colors.white38),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      padding: const EdgeInsets.all(16),
                    ),
                    const SizedBox(height: 20),
                    CupertinoButton.filled(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final amount =
                                  double.tryParse(controller.text.trim());
                              if (amount == null || amount <= 0) {
                                _showResultDialog(context, 'Invalid amount');
                                return;
                              }
                              final wallet = context.read<WalletController>();
                              setState(() {
                                isSubmitting = true;
                              });
                              try {
                                final confirmed = await _confirmFeeAndSecurity(
                                  parentContext,
                                  title: encrypt
                                      ? 'Confirm Encrypt'
                                      : 'Confirm Decrypt',
                                  feeOperation: encrypt ? 'encrypt' : 'decrypt',
                                  amountLabel: '$amount OCT',
                                  publicAmount: encrypt ? amount : null,
                                );
                                if (!confirmed) {
                                  setState(() {
                                    isSubmitting = false;
                                  });
                                  return;
                                }
                                final res = encrypt
                                    ? await wallet.encryptMoney(amount)
                                    : await wallet.decryptMoney(amount);
                                final err = wallet.rpc.rpcError(res);
                                if (err != null) {
                                  // Keep the sheet open so the input survives a retry.
                                  if (!context.mounted) return;
                                  setState(() => isSubmitting = false);
                                  _showResultDialog(context, _friendlyError(err));
                                  return;
                                }
                                if (context.mounted) Navigator.pop(context);
                                final result = wallet.rpc.rpcResult(res);
                                final msg =
                                    result is Map && result['tx_hash'] != null
                                        ? 'Submitted: ${result['tx_hash']}'
                                        : res.text;
                                if (parentContext.mounted) {
                                  _showResultDialog(parentContext, msg,
                                      isError: false);
                                }
                              } catch (e) {
                                if (!context.mounted) return;
                                setState(() => isSubmitting = false);
                                _showResultDialog(context, _friendlyError(e));
                              }
                            },
                      child: isSubmitting
                          ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                          : Text(encrypt ? 'Encrypt' : 'Decrypt'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivateSendSheet(BuildContext context) {
    final parentContext = context;
    final addressController = TextEditingController();
    final amountController = TextEditingController();
    var isSubmitting = false;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => _keyboardAwareSheet(
          context,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            decoration: _sheetDecoration,
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sheetHandle(),
                    _sheetTitle(
                      'Private Send',
                      subtitle:
                          'Send from your encrypted balance with a stealth transfer. '
                          'Proof generation runs on-device and takes a few minutes.',
                    ),
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final wallet = context.read<WalletController>();
                      return Text(
                        'Available: ${_formatOct(wallet.encryptedBalance)} private OCT',
                        style: GoogleFonts.outfit(
                            color: Colors.white38, fontSize: 13),
                      );
                    }),
                    const SizedBox(height: 10),
                    _walletTextField(
                      addressController,
                      'Recipient Octra address',
                      suffix: _scanSuffix(context, addressController),
                    ),
                    const SizedBox(height: 12),
                    _walletTextField(
                      amountController,
                      'Amount in OCT',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 20),
                    CupertinoButton.filled(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final to = addressController.text.trim();
                              final amount =
                                  double.tryParse(amountController.text.trim());
                              if (to.isEmpty || amount == null || amount <= 0) {
                                _showResultDialog(context,
                                    'Enter a recipient address and valid amount');
                                return;
                              }
                              if (!_looksLikeOctraAddress(to)) {
                                _showResultDialog(context,
                                    'That does not look like an Octra address. Addresses start with "oct".');
                                return;
                              }
                              final wallet = context.read<WalletController>();
                              setState(() {
                                isSubmitting = true;
                              });
                              try {
                                final confirmed = await _confirmFeeAndSecurity(
                                  parentContext,
                                  title: 'Confirm Private Send',
                                  feeOperation: 'stealth',
                                  amountLabel: '$amount private OCT',
                                );
                                if (!confirmed) {
                                  setState(() {
                                    isSubmitting = false;
                                  });
                                  return;
                                }
                                final res = await wallet.makePrivateTransfer(
                                    to, amount);
                                final err = wallet.rpc.rpcError(res);
                                if (err != null) {
                                  // RPC-level error: keep sheet open so user can retry
                                  if (!context.mounted) return;
                                  setState(() => isSubmitting = false);
                                  _showResultDialog(context, _friendlyError(err));
                                  return;
                                }
                                if (context.mounted) Navigator.pop(context);
                                final result = wallet.rpc.rpcResult(res);
                                final msg = result is Map &&
                                        result['tx_hash'] != null
                                    ? 'Submitted: ${result['tx_hash']}'
                                    : res.text;
                                if (parentContext.mounted) {
                                  _showResultDialog(parentContext, msg,
                                      isError: false);
                                }
                              } catch (e) {
                                // PVAC or other exception: keep sheet open so user can retry
                                if (!context.mounted) return;
                                setState(() => isSubmitting = false);
                                _showResultDialog(context, _friendlyError(e));
                              }
                            },
                      child: isSubmitting
                          ? const CupertinoActivityIndicator()
                          : const Text('Send Privately'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showStealthClaimsSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => const _StealthClaimsSheet(),
    );
  }

  void _showTokensSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => const _TokensSheet(),
    );
  }

  void _showBulkSendSheet(BuildContext context) {
    final parentContext = context;
    final rows = List.generate(
      5,
      (_) => {
        'to': TextEditingController(),
        'amount': TextEditingController(),
      },
    );
    var isSubmitting = false;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => _keyboardAwareSheet(
          context,
          maxHeightFactor: 0.92,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.84,
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            decoration: _sheetDecoration,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sheetHandle(),
                  _sheetTitle('Bulk Public Send',
                      subtitle:
                          'Submit up to 5 public transfers with sequential nonces.'),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recipient ${index + 1}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              const SizedBox(height: 8),
                              _walletTextField(row['to']!, 'Address'),
                              const SizedBox(height: 8),
                              _walletTextField(
                                row['amount']!,
                                'Amount in OCT',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoButton.filled(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final recipients = rows
                                .map((row) => {
                                      'to': row['to']!.text.trim(),
                                      'amount': row['amount']!.text.trim(),
                                    })
                                .where((item) =>
                                    item['to']!.isNotEmpty ||
                                    item['amount']!.isNotEmpty)
                                .toList();
                            if (recipients.isEmpty) {
                              _showResultDialog(
                                  context, 'Enter at least one recipient');
                              return;
                            }
                            for (var i = 0; i < recipients.length; i++) {
                              final item = recipients[i];
                              final amount =
                                  double.tryParse(item['amount'] ?? '');
                              if (!_looksLikeOctraAddress(item['to'] ?? '') ||
                                  amount == null ||
                                  amount <= 0) {
                                _showResultDialog(context,
                                    'Recipient ${i + 1} needs a valid Octra address and amount.');
                                return;
                              }
                            }
                            final wallet = context.read<WalletController>();
                            setState(() {
                              isSubmitting = true;
                            });
                            try {
                              final totalAmount = recipients.fold<double>(
                                0,
                                (sum, item) =>
                                    sum +
                                    (double.tryParse(item['amount'] ?? '') ??
                                        0),
                              );
                              final confirmed = await _confirmFeeAndSecurity(
                                parentContext,
                                title: 'Confirm Bulk Send',
                                feeOperation: 'standard',
                                amountLabel:
                                    '$totalAmount OCT across ${recipients.length} recipient(s)',
                                publicAmount: totalAmount,
                              );
                              if (!confirmed) {
                                setState(() {
                                  isSubmitting = false;
                                });
                                return;
                              }
                              final responses = await wallet
                                  .sendBulkPublicTransfers(recipients);
                              if (context.mounted) Navigator.pop(context);
                              final okCount = responses
                                  .where((res) =>
                                      wallet.rpc.rpcError(res) == null &&
                                      res.statusCode != 0)
                                  .length;
                              final firstError = responses
                                  .map((res) => wallet.rpc.rpcError(res))
                                  .whereType<String>()
                                  .cast<String?>()
                                  .firstWhere((err) => err != null,
                                      orElse: () => null);
                              final msg = firstError == null
                                  ? 'Submitted $okCount transaction(s)'
                                  : 'Submitted $okCount transaction(s), then failed: $firstError';
                              if (parentContext.mounted) {
                                _showResultDialog(parentContext, msg,
                                    isError: firstError != null);
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              setState(() => isSubmitting = false);
                              _showResultDialog(context, _friendlyError(e));
                            }
                          },
                    child: isSubmitting
                        ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                        : const Text('Submit Bulk'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _registerPvacKey(BuildContext context) async {
    final wallet = context.read<WalletController>();
    wallet.registerCurrentPvacInBackground();
    if (context.mounted) {
      _showResultDialog(
        context,
        'PVAC registration is running in the background. It is required once per wallet address.',
      );
    }
  }

  void _showResultDialog(BuildContext context, String message, {bool isError = true}) {
    if (isError) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? CupertinoIcons.xmark_circle_fill : CupertinoIcons.checkmark_circle_fill,
              color: isError ? CupertinoColors.destructiveRed : CupertinoColors.activeGreen,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(isError ? 'Error' : 'Success'),
          ],
        ),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  CupertinoTextField _walletTextField(
    TextEditingController controller,
    String placeholder, {
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return CupertinoTextField(
      controller: controller,
      keyboardType: keyboardType,
      placeholder: placeholder,
      style: const TextStyle(color: Colors.white),
      placeholderStyle: const TextStyle(color: Colors.white38),
      suffix: suffix,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
    );
  }

  /// QR-scan affordance for address fields. Hidden on platforms where the
  /// camera plugin has no implementation (Windows/Linux desktop).
  Widget? _scanSuffix(BuildContext context, TextEditingController controller) {
    if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      return null;
    }
    return CupertinoButton(
      padding: const EdgeInsets.only(right: 8),
      minimumSize: Size.zero,
      onPressed: () async {
        final scanned = await Navigator.of(context, rootNavigator: true)
            .push<String>(
          CupertinoPageRoute(builder: (_) => const ScannerPage()),
        );
        if (scanned != null && scanned.trim().isNotEmpty) {
          controller.text = scanned.trim();
          HapticFeedback.lightImpact();
        }
      },
      child: const Icon(CupertinoIcons.qrcode_viewfinder,
          color: Colors.white54, size: 22),
    );
  }

  void _showRpcResult(
      BuildContext context, WalletController wallet, dynamic res) {
    final err = wallet.rpc.rpcError(res);
    final result = wallet.rpc.rpcResult(res);
    final msg = err ??
        (result is Map && result['tx_hash'] != null
            ? 'Submitted: ${result['tx_hash']}'
            : res.text);
    if (context.mounted) _showResultDialog(context, msg, isError: err != null);
  }
}

class _ReceiveSheet extends StatefulWidget {
  final String address;
  final String? name;

  const _ReceiveSheet({required this.address, this.name});

  @override
  State<_ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<_ReceiveSheet> {
  bool _copied = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _copy() {
    _copyToClipboard(widget.address);
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final address = widget.address;
    return Container(
      decoration: _sheetDecoration,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sheetHandle(),
              _sheetTitle(
                'Receive OCT',
                subtitle: widget.name == null
                    ? 'Share this address to receive OCT.'
                    : 'Share this address to receive OCT in "${widget.name}".',
              ),
              const SizedBox(height: 22),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: address,
                    size: 220,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: _copy,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    address,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sourceCodePro(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: _copy,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _copied
                      ? const Row(
                          key: ValueKey('copied'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.checkmark_circle_fill,
                                size: 18, color: CupertinoColors.white),
                            SizedBox(width: 8),
                            Text('Copied'),
                          ],
                        )
                      : const Row(
                          key: ValueKey('copy'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.doc_on_doc,
                                size: 18, color: CupertinoColors.white),
                            SizedBox(width: 8),
                            Text('Copy Address'),
                          ],
                        ),
                ),
              ),
              CupertinoButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StealthClaimsSheet extends StatefulWidget {
  const _StealthClaimsSheet();

  @override
  State<_StealthClaimsSheet> createState() => _StealthClaimsSheetState();
}

class _StealthClaimsSheetState extends State<_StealthClaimsSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _claims = const [];
  final Set<String> _claiming = {};

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final claims =
          await context.read<WalletController>().scanStealthTransfers();
      if (!mounted) return;
      setState(() {
        _claims = claims;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _claim(Map<String, dynamic> claim) async {
    final id = claim['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final amountRaw = int.tryParse(claim['amount_raw']?.toString() ?? '0') ?? 0;
    final confirmed = await _confirmFeeAndSecurity(
      context,
      title: 'Confirm Stealth Claim',
      feeOperation: 'claim',
      amountLabel: '${_formatOct(amountRaw / _octMicro)} private OCT',
    );
    if (!confirmed) return;
    if (!mounted) return;

    setState(() {
      _claiming.add(id);
      _error = null;
    });

    try {
      final wallet = context.read<WalletController>();
      final res = await wallet.claimStealthTransfer(claim);
      final err = wallet.rpc.rpcError(res);
      if (err != null) {
        throw StateError(err);
      }
      await _scan();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _claiming.remove(id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      decoration: _sheetDecoration,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetHandle(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Stealth Claims',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _loading ? null : _scan,
                  child: const Icon(CupertinoIcons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan stealth outputs with your local view key and claim matching transfers.',
              style: TextStyle(color: Colors.white54),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_friendlyError(_error!),
                  style: const TextStyle(color: CupertinoColors.systemRed)),
            ],
            const SizedBox(height: 20),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _claims.isEmpty
                      ? const _EmptyState(
                          icon: CupertinoIcons.tray,
                          message:
                              'No claimable stealth transfers found.\nIncoming private transfers appear here.',
                        )
                      : ListView.separated(
                          itemCount: _claims.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final claim = _claims[index];
                            final id = claim['id']?.toString() ?? '';
                            final amountRaw = int.tryParse(
                                    claim['amount_raw']?.toString() ?? '0') ??
                                0;
                            final amount = amountRaw / 1000000.0;
                            final isClaiming = _claiming.contains(id);

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_formatOct(amount)} OCT',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    id.length > 20
                                        ? '${id.substring(0, 10)}...${id.substring(id.length - 8)}'
                                        : id,
                                    style:
                                        const TextStyle(color: Colors.white54),
                                  ),
                                  const SizedBox(height: 12),
                                  CupertinoButton.filled(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    onPressed:
                                        isClaiming ? null : () => _claim(claim),
                                    child: isClaiming
                                        ? const CupertinoActivityIndicator()
                                        : const Text('Claim'),
                                  ),
                                ],
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
}

class _TokensSheet extends StatefulWidget {
  const _TokensSheet();

  @override
  State<_TokensSheet> createState() => _TokensSheetState();
}

class _TokensSheetState extends State<_TokensSheet> {
  final TextEditingController _importController = TextEditingController();
  bool _loading = true;
  bool _importing = false;
  String? _error;
  List<Map<String, dynamic>> _tokens = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tokens = await context.read<WalletController>().loadTokens();
      if (!mounted) return;
      setState(() {
        _tokens = tokens;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _importToken() async {
    final address = _importController.text.trim();
    if (address.isEmpty || _importing) return;
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final token =
          await context.read<WalletController>().importCustomToken(address);
      if (!mounted) return;
      if (token == null) {
        setState(() {
          _error = 'Token contract not found or missing symbol metadata';
        });
        return;
      }
      _importController.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
      });
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _transferToken(Map<String, dynamic> token) async {
    final parentContext = context;
    final toController = TextEditingController();
    final amountController = TextEditingController();
    var isSubmitting = false;

    await showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          decoration: _sheetDecoration,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sheetHandle(),
                _sheetTitle('Send ${token['symbol'] ?? 'Token'}'),
                const SizedBox(height: 20),
                CupertinoTextField(
                  controller: toController,
                  placeholder: 'Recipient Octra address',
                  style: const TextStyle(color: Colors.white),
                  placeholderStyle: const TextStyle(color: Colors.white38),
                  decoration: _fieldDecoration(),
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  placeholder: 'Amount',
                  style: const TextStyle(color: Colors.white),
                  placeholderStyle: const TextStyle(color: Colors.white38),
                  decoration: _fieldDecoration(),
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 20),
                CupertinoButton.filled(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final to = toController.text.trim();
                          final amountText = amountController.text.trim();
                          if (to.isEmpty || amountText.isEmpty) {
                            _showTokenDialog(context,
                                'Enter a recipient address and amount.');
                            return;
                          }
                          if (!_looksLikeOctraAddress(to)) {
                            _showTokenDialog(context,
                                'That does not look like an Octra address. Addresses start with "oct".');
                            return;
                          }
                          final wallet =
                              parentContext.read<WalletController>();
                          setState(() {
                            isSubmitting = true;
                          });
                          try {
                            final confirmed = await _confirmFeeAndSecurity(
                              parentContext,
                              title: 'Confirm Token Send',
                              feeOperation: 'call',
                              amountLabel:
                                  '$amountText ${token['symbol'] ?? 'Token'}',
                            );
                            if (!confirmed) {
                              setState(() {
                                isSubmitting = false;
                              });
                              return;
                            }
                            final res = await wallet.transferToken(
                              token,
                              to,
                              amountText,
                            );
                            final err = wallet.rpc.rpcError(res);
                            if (err != null) {
                              // Keep the sheet open so the input survives a retry.
                              if (!context.mounted) return;
                              setState(() => isSubmitting = false);
                              _showTokenDialog(context, _friendlyError(err));
                              return;
                            }
                            if (context.mounted) Navigator.pop(context);
                            final result = wallet.rpc.rpcResult(res);
                            final msg =
                                result is Map && result['tx_hash'] != null
                                    ? 'Submitted: ${result['tx_hash']}'
                                    : res.text;
                            if (parentContext.mounted) {
                              _showTokenDialog(parentContext, msg);
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            setState(() => isSubmitting = false);
                            _showTokenDialog(context, _friendlyError(e));
                          }
                        },
                  child: isSubmitting
                      ? const CupertinoActivityIndicator()
                      : const Text('Send Token'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      decoration: _sheetDecoration,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetHandle(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tokens',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _loading ? null : _load,
                  child: const Icon(CupertinoIcons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: _importController,
                    placeholder: 'Import token contract address',
                    style: const TextStyle(color: Colors.white),
                    placeholderStyle: const TextStyle(color: Colors.white38),
                    decoration: _fieldDecoration(),
                    padding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton.filled(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  onPressed: _importing ? null : _importToken,
                  child: _importing
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white)
                      : const Text('Import'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: CupertinoColors.systemRed)),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _tokens.isEmpty
                      ? const _EmptyState(
                          icon: CupertinoIcons.cube_box,
                          message:
                              'No tokens found.\nImport a token contract address above.',
                        )
                      : ListView.separated(
                          itemCount: _tokens.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final token = _tokens[index];
                            final balance = _formatTokenBalance(token);
                            return Dismissible(
                              key: ValueKey(token['address'].toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemRed
                                      .withValues(alpha: 0.24),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  CupertinoIcons.delete,
                                  color: CupertinoColors.systemRed,
                                ),
                              ),
                              onDismissed: (_) {
                                final address = token['address'].toString();
                                setState(() {
                                  _tokens = _tokens
                                      .where((item) =>
                                          item['address'].toString() != address)
                                      .toList();
                                });
                                context
                                    .read<WalletController>()
                                    .removeCustomToken(address);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${token['symbol']}',
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${token['name']} - $balance',
                                            style: const TextStyle(
                                                color: Colors.white54),
                                          ),
                                        ],
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _transferToken(token),
                                      child: const Text('Send'),
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

  BoxDecoration _fieldDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white10),
    );
  }

  String _formatTokenBalance(Map<String, dynamic> token) {
    final raw = token['balance']?.toString() ?? '0';
    final decimals = int.tryParse(token['decimals']?.toString() ?? '0') ?? 0;
    if (decimals <= 0) return '$raw ${token['symbol']}';
    var padded = raw.padLeft(decimals + 1, '0');
    final split = padded.length - decimals;
    final whole = padded.substring(0, split);
    var frac = padded.substring(split).replaceFirst(RegExp(r'0+$'), '');
    return frac.isEmpty
        ? '$whole ${token['symbol']}'
        : '$whole.$frac ${token['symbol']}';
  }

  void _showTokenDialog(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Tokens'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

String? _timeAgoForTransaction(Map<String, dynamic> tx) {
  final ts = double.tryParse(tx['timestamp']?.toString() ?? '');
  if (ts == null || ts <= 0) return null;
  final when = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
  final diff = DateTime.now().difference(when);
  if (diff.isNegative) return null;
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}';
}

Widget _buildTransactionRow(BuildContext context, Map<String, dynamic> tx) {
  final hash = (tx['hash'] ?? tx['tx_hash'] ?? '').toString();
  final direction = tx['direction'] ?? 'IN';
  final opType = (tx['op_type'] ?? 'standard').toString();
  final isIn = direction == 'IN';
  final isPrivate =
      opType == 'stealth' || opType == 'claim' || opType == 'private';
  final title = (tx['tx_title'] ?? _titleForTransaction(tx)).toString();
  final amountLabel =
      (tx['amount_label'] ?? _amountLabelForTransaction(tx)).toString();
  final color = _colorForTransaction(tx, isIn);
  final icon = _iconForTransaction(tx, isIn);
  final timeAgo = _timeAgoForTransaction(tx);

  return GestureDetector(
    onTap: () => _showTransactionDetails(context, tx),
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  hash.length > 16
                      ? '${hash.substring(0, 8)}...${hash.substring(hash.length - 6)}'
                      : hash,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIn && !isPrivate ? '+' : direction == 'OUT' && amountLabel != '0 OCT' ? '-' : ''}$amountLabel',
                style: GoogleFonts.outfit(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              if (timeAgo != null) ...[
                const SizedBox(height: 2),
                Text(
                  timeAgo,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

String _titleForTransaction(Map<String, dynamic> tx) {
  final op = (tx['op_type'] ?? 'standard').toString();
  if (op == 'standard' || op.isEmpty) {
    return tx['direction'] == 'IN' ? 'Received OCT' : 'Sent OCT';
  }
  if (op == 'call') {
    final method = tx['encrypted_data']?.toString();
    if (method == 'transfer') return 'Token Transfer';
    if (method != null && method.isNotEmpty) return '$method()';
    return 'Program Call';
  }
  const labels = {
    'stealth': 'Stealth Transfer',
    'claim': 'Stealth Claim',
    'encrypt': 'Encrypt Balance',
    'decrypt': 'Decrypt Balance',
    'private': 'Private Transfer',
    'recrypt': 'Recrypt',
    'deploy': 'Program Deploy',
    'upgrade': 'Program Upgrade',
  };
  return labels[op] ?? op.replaceAll('_', ' ');
}

String _amountLabelForTransaction(Map<String, dynamic> tx) {
  final op = (tx['op_type'] ?? '').toString();
  if (op == 'stealth' || op == 'claim' || op == 'private') return 'Private';
  final rawText = (tx['amount_raw'] ?? tx['amount'] ?? '0').toString();
  final raw = double.tryParse(rawText) ?? 0;
  final amount = raw.abs() >= _octMicro ? raw / _octMicro : raw;
  if (amount == 0) return '0 OCT';
  if (amount > 0 && amount < 0.001) return '< 0.001 OCT';
  return '${amount.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '')} OCT';
}

Color _colorForTransaction(Map<String, dynamic> tx, bool isIn) {
  final op = (tx['op_type'] ?? 'standard').toString();
  if (op == 'deploy' || op == 'call' || op == 'upgrade') {
    return CupertinoColors.systemPurple;
  }
  if (op == 'encrypt' ||
      op == 'decrypt' ||
      op == 'stealth' ||
      op == 'claim' ||
      op == 'private') {
    return CupertinoColors.systemTeal;
  }
  return isIn ? Colors.green : Colors.red;
}

IconData _iconForTransaction(Map<String, dynamic> tx, bool isIn) {
  final op = (tx['op_type'] ?? 'standard').toString();
  if (op == 'deploy') return CupertinoIcons.cube_box_fill;
  if (op == 'call' || op == 'upgrade') {
    return CupertinoIcons.chevron_left_slash_chevron_right;
  }
  if (op == 'encrypt') return CupertinoIcons.lock_rotation;
  if (op == 'decrypt') return CupertinoIcons.lock_open;
  if (op == 'stealth' || op == 'claim' || op == 'private') {
    return CupertinoIcons.eye_slash_fill;
  }
  return isIn ? CupertinoIcons.arrow_down_left : CupertinoIcons.arrow_up_right;
}

void _showTransactionDetails(BuildContext context, Map<String, dynamic> tx) {
  showCupertinoModalPopup(
    context: context,
    builder: (context) => _TransactionDetailsSheet(initialTx: tx),
  );
}

class _TransactionDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> initialTx;

  const _TransactionDetailsSheet({required this.initialTx});

  @override
  State<_TransactionDetailsSheet> createState() =>
      _TransactionDetailsSheetState();
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
          if (res != null) {
            fullTx = res;
          }
          loading = false;
        });
      }
    } else {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTx =
        fullTx != null ? (fullTx!['parsed_tx'] ?? fullTx!) : widget.initialTx;
    final meta = fullTx ?? widget.initialTx;

    final hash = displayTx['hash'] ??
        displayTx['tx_hash'] ??
        widget.initialTx['hash'] ??
        '';
    final direction = widget.initialTx['direction'] ?? 'IN';
    final isIn = direction == 'IN';
    final title =
        widget.initialTx['tx_title'] ?? _titleForTransaction(displayTx);
    final amountLabel = displayTx['amount_raw'] != null
        ? _amountLabelForTransaction(displayTx)
        : (widget.initialTx['amount_label'] ??
            _amountLabelForTransaction(displayTx));
    final status = meta['status'] ?? 'Unknown';
    final epoch = meta['epoch'];
    final color = _colorForTransaction(displayTx, isIn);
    final icon = _iconForTransaction(displayTx, isIn);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: CupertinoActivityIndicator(),
              ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title.toString(),
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              amountLabel.toString(),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isIn
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == 'confirmed')
                    const Icon(Icons.check, size: 14, color: Colors.green)
                  else
                    const Icon(Icons.access_time,
                        size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color:
                          status == 'confirmed' ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildDetailRow(context, 'From', displayTx['from'] ?? ''),
            _buildDetailRow(
                context, 'To', displayTx['to'] ?? displayTx['to_'] ?? ''),
            _buildDetailRow(context, 'Hash', hash),
            if (epoch != null)
              _buildDetailRow(context, 'Epoch', epoch.toString()),
            if (displayTx['timestamp'] != null)
              Builder(
                builder: (_) {
                  final ts =
                      double.tryParse(displayTx['timestamp'].toString()) ?? 0;
                  if (ts > 0) {
                    final dt = DateTime.fromMillisecondsSinceEpoch(
                        (ts * 1000).toInt());
                    return _buildDetailRow(
                        context, 'Time', dt.toString().split('.')[0]);
                  }
                  return const SizedBox.shrink();
                },
              ),
            if (displayTx['ou'] != null)
              _buildDetailRow(context, 'Fee', '${displayTx['ou']} OU'),
            if (displayTx['nonce'] != null)
              _buildDetailRow(context, 'Nonce', displayTx['nonce'].toString()),
            if (displayTx['message'] != null)
              _buildDetailRow(
                  context, 'Message', displayTx['message'].toString()),
            if (hash.toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () {
                    var explorerUrl =
                        displayTx['explorer_url']?.toString().trim() ?? '';
                    if (explorerUrl.isEmpty) {
                      final base =
                          context.read<WalletController>().explorerBaseUrlSync;
                      explorerUrl = '$base/tx.html?hash=$hash';
                    }
                    _openExternalUrl(explorerUrl);
                  },
                  child: const Text('View on Explorer'),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
        ),
      ),
    );
  }
}

Widget _buildDetailRow(BuildContext context, String label, String value) {
  if (value.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => _copyToClipboard(value),
            child: Text(
              value.length > 20
                  ? '${value.substring(0, 8)}...${value.substring(value.length - 8)}'
                  : value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(CupertinoIcons.doc_on_doc, size: 14, color: Colors.blueGrey),
      ],
    ),
  );
}

Widget _buildStatusChip({
  required IconData icon,
  required String label,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: CupertinoColors.systemBlue),
        const SizedBox(width: 8),
        Text(
          label.isEmpty ? 'Unknown' : label,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final walletCtrl = context.watch<WalletController>();
    final currentAddress = walletCtrl.currentWallet?.address;
    final visibleHistory = walletCtrl.historyWalletAddress == currentAddress
        ? walletCtrl.history
        : <Map<String, dynamic>>[];
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('History'),
            backgroundColor: Color(0xCC1C1C1E),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              await walletCtrl.refresh();
            },
          ),
          if (walletCtrl.isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (visibleHistory.isEmpty)
            const SliverFillRemaining(
              child: _EmptyState(
                icon: CupertinoIcons.time,
                message:
                    'No transactions yet.\nPull down to refresh your history.',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final tx = visibleHistory[index];
                  return _buildTransactionRow(context, tx);
                },
                childCount: visibleHistory.length,
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: Icon(widget.icon, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(widget.label,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── EVM Wallet quick card ─────────────────────────────────────────────────────
class _EvmWalletCard extends StatelessWidget {
  const _EvmWalletCard();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EthWalletStore>();
    final acc = store.account;
    const brand = Color(0xFF0A84FF);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const BridgeScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0A84FF).withValues(alpha: 0.12),
              const Color(0xFF5E5CE6).withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF0A84FF).withValues(alpha: 0.25)),
        ),
        child: acc == null
            ? Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _brand.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(CupertinoIcons.link_circle_fill, color: _brand, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EVM Wallet', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text('Set up to bridge OCT ↔ wOCT', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_right, color: Color(0xFF48484A), size: 16),
                ],
              )
            : Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _brand.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(CupertinoIcons.link_circle_fill, color: _brand, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('EVM Wallet', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                            Text(
                              '${acc.address.substring(0, 6)}…${acc.address.substring(acc.address.length - 4)}',
                              style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      const Icon(CupertinoIcons.chevron_right, color: Color(0xFF48484A), size: 16),
                    ],
                  ),
                  if (store.ethBalanceWei > BigInt.zero || store.woctBalanceRaw > BigInt.zero) ...[
                    const SizedBox(height: 12),
                    Container(height: 1, color: Colors.white10),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ETH', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11)),
                              Text(
                                (store.ethBalanceWei.toDouble() / 1e18).toStringAsFixed(5),
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 30, color: Colors.white10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('wOCT', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11)),
                                Text(
                                  (store.woctBalanceRaw.toDouble() / 1e6).toStringAsFixed(4),
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
