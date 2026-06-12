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
                colors: [Color(0xFF03057C), Color(0xFF000000)],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Column(
                      children: [
                        _buildHeaderCard(),
                        const SizedBox(height: 16),
                        _buildPinCard(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: CupertinoColors.systemBlue.withValues(alpha: 0.32),
              ),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemBlue.withValues(alpha: 0.16),
                  blurRadius: 24,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(
              CupertinoIcons.lock_shield_fill,
              size: 42,
              color: CupertinoColors.systemBlue,
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.92, 0.92),
                  end: const Offset(1.0, 1.0),
                  duration: 1400.ms,
                  curve: Curves.easeInOut,
                ),
          ),
          const SizedBox(height: 18),
          Text(
            _titleText,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _subtitleText,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildStatusChip(
                icon: CupertinoIcons.lock_fill,
                label: 'PIN locked',
              ),
              _buildStatusChip(
                icon: CupertinoIcons.shield_fill,
                label: widget.isSettingPin ? 'Setup mode' : 'Unlock mode',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPinCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF121216),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
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
                      : CupertinoColors.systemGrey.withValues(alpha: 0.22),
                  boxShadow: filled
                      ? [
                          BoxShadow(
                            color: CupertinoColors.systemBlue.withValues(alpha: 0.35),
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
          const SizedBox(height: 20),
          _buildNumpad(),
          const SizedBox(height: 14),
          Text(
            'PIN lock is mandatory on this wallet.',
            style: GoogleFonts.outfit(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 6),
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
  final TextEditingController _rpcController = TextEditingController();
  final TextEditingController _explorerController = TextEditingController();

  String _selectedProfile = 'mainnet';
  String _mainnetRpcUrl = '';
  String _mainnetExplorerUrl = '';
  String _devnetRpcUrl = '';
  String _devnetExplorerUrl = '';
  bool _initialized = false;
  bool _savingNetwork = false;
  String? _networkMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _syncFromWallet(context.read<WalletController>());
    _initialized = true;
  }

  @override
  void dispose() {
    _rpcController.dispose();
    _explorerController.dispose();
    super.dispose();
  }

  void _syncFromWallet(WalletController wallet) {
    _selectedProfile = wallet.networkProfileSync;
    _mainnetRpcUrl = wallet.mainnetRpcBaseUrlSync;
    _mainnetExplorerUrl = wallet.mainnetExplorerBaseUrlSync;
    _devnetRpcUrl = wallet.devnetRpcBaseUrlSync;
    _devnetExplorerUrl = wallet.devnetExplorerBaseUrlSync;
    _syncControllersForProfile();
  }

  void _syncControllersForProfile() {
    final isDevnet = _selectedProfile == 'devnet';
    _rpcController.text = isDevnet ? _devnetRpcUrl : _mainnetRpcUrl;
    _explorerController.text = isDevnet ? _devnetExplorerUrl : _mainnetExplorerUrl;
  }

  void _stashCurrentFields() {
    final rpcValue = _rpcController.text.trim();
    final explorerValue = _explorerController.text.trim();
    if (_selectedProfile == 'devnet') {
      _devnetRpcUrl = rpcValue;
      _devnetExplorerUrl = explorerValue;
    } else {
      _mainnetRpcUrl = rpcValue;
      _mainnetExplorerUrl = explorerValue;
    }
  }

  void _onProfileChanged(String profile) {
    if (_selectedProfile == profile) return;
    setState(() {
      _stashCurrentFields();
      _selectedProfile = profile;
      _syncControllersForProfile();
      _networkMessage = profile == 'devnet'
          ? 'Devnet uses its own RPC and explorer settings.'
          : 'Mainnet uses the production RPC and explorer settings.';
    });
  }

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
    if (!mounted) return;
    // Immediately re-engage the PIN gate; PinScreen cannot be dismissed
    // without the correct PIN, so this acts as the lock screen.
    await Navigator.of(context, rootNavigator: true).push<bool>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PinScreen(isChecking: true),
      ),
    );
    if (!wallet.hasWallet) {
      await wallet.loadWallets();
    }
    if (mounted) setState(() {});
  }

  Future<void> _applyNetwork(WalletController wallet) async {
    final rpcUrl = _rpcController.text.trim();
    final explorerUrl = _explorerController.text.trim();

    if (_selectedProfile == 'devnet' && rpcUrl.isEmpty) {
      setState(() {
        _networkMessage = 'Enter a devnet RPC URL before applying devnet.';
      });
      return;
    }

    setState(() {
      _savingNetwork = true;
      _networkMessage = null;
      _stashCurrentFields();
    });

    try {
      await wallet.setNetworkProfile(
        _selectedProfile,
        rpcUrl: rpcUrl,
        explorerUrl: explorerUrl,
      );

      if (wallet.hasWallet) {
        await wallet.refresh();
      }

      if (!mounted) return;
      setState(() {
        _syncFromWallet(wallet);
        _networkMessage =
            'Saved ${wallet.activeNetworkLabelSync.toLowerCase()} settings.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _networkMessage = 'Unable to save network settings: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingNetwork = false;
        });
      }
    }
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121216),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: CupertinoColors.systemBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    required String helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          placeholderStyle: const TextStyle(color: Colors.white38),
          style: const TextStyle(color: Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          onChanged: (_) => setState(() => _networkMessage = null),
        ),
        const SizedBox(height: 6),
        Text(
          helper,
          style: GoogleFonts.outfit(
            color: Colors.white38,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletController>();

    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Settings", style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xCC1C1C1E),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0C1730), Color(0xFF111114)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Security and network control',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'PIN is mandatory, and the active RPC / explorer profile is stored locally on device.',
                    style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusChip(
                        icon: CupertinoIcons.lock_fill,
                        label: 'PIN required',
                      ),
                      _buildStatusChip(
                        icon: CupertinoIcons.globe,
                        label: wallet.activeNetworkLabelSync,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              icon: CupertinoIcons.shield_fill,
              title: 'Security',
              subtitle: 'Unlock the vault and approve sensitive actions with a PIN.',
              children: [
                _buildMenuTile(
                  title: 'PIN Lock',
                  subtitle: 'Always enabled for wallet unlock and protected actions',
                  trailing: const Icon(
                    CupertinoIcons.lock_fill,
                    color: CupertinoColors.systemBlue,
                  ),
                ),
                const SizedBox(height: 10),
                _buildActionTile(
                  title: 'Change PIN',
                  icon: CupertinoIcons.lock_fill,
                  onTap: () => _changePin(context, wallet),
                ),
                const SizedBox(height: 10),
                _buildActionTile(
                  title: 'Lock Now',
                  icon: CupertinoIcons.lock_rotation,
                  onTap: () => _lockNow(wallet),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              icon: Icons.language,
              title: 'Network',
              subtitle: 'Switch between mainnet and devnet, then refresh balances and history.',
              children: [
                CupertinoSlidingSegmentedControl<String>(
                  groupValue: _selectedProfile,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  thumbColor: CupertinoColors.systemBlue,
                  children: const {
                    'mainnet': Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text(
                        'Mainnet',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    'devnet': Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text(
                        'Devnet',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  },
                  onValueChanged: (value) {
                    if (value == null) return;
                    _onProfileChanged(value);
                  },
                ),
                const SizedBox(height: 14),
                _buildField(
                  label: 'RPC URL',
                  placeholder: _selectedProfile == 'devnet'
                      ? 'https://devnet.octra.com'
                      : 'https://octra.network',
                  controller: _rpcController,
                  helper:
                      'Transactions, balances, history, and contract calls use this endpoint.',
                ),
                const SizedBox(height: 14),
                _buildField(
                  label: 'Explorer URL',
                  placeholder: _selectedProfile == 'devnet'
                      ? 'https://devnet.octrascan.io'
                      : 'https://octrascan.io',
                  controller: _explorerController,
                  helper:
                      'History links and transaction receipts open here from the app.',
                ),
                if (_networkMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: CupertinoColors.systemBlue.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      _networkMessage!,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _savingNetwork ? null : () => _applyNetwork(wallet),
                    child: _savingNetwork
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Text('Apply Network'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildMenuTile({
  required String title,
  required String subtitle,
  required Widget trailing,
}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    ),
  );
}

Widget _buildActionTile({
  required String title,
  required IconData icon,
  required VoidCallback onTap,
}) {
  return CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: CupertinoColors.systemBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: CupertinoColors.systemBlue, size: 18),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const Icon(CupertinoIcons.chevron_right,
              color: Colors.white38, size: 18),
        ],
      ),
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
          label,
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
