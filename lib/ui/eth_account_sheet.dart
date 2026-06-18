import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Colors, Material, InkWell, Theme, ThemeData, Brightness;
import 'package:flutter/services.dart';

import '../eth/eth_account.dart';
import '../eth/eth_wallet_store.dart';

const _brand = Color(0xFF0A84FF);
const _card = Color(0xFF1C1C1E);
const _card2 = Color(0xFF2C2C2E);
const _sub = Color(0xFF8E8E93);

/// Full-screen Ethereum account manager: create / import / enter address /
/// connect. Pops when the active account changes so the caller can refresh.
class EthAccountScreen extends StatefulWidget {
  final EthWalletStore store;

  /// Invoked when the user chooses "Connect external wallet" (WalletConnect).
  final Future<void> Function()? onConnect;

  const EthAccountScreen({super.key, required this.store, this.onConnect});

  @override
  State<EthAccountScreen> createState() => _EthAccountScreenState();
}

class _EthAccountScreenState extends State<EthAccountScreen> {
  EthWalletStore get store => widget.store;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) _alert('Could not continue', _clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() => _run(() async {
        final acc = await store.createNew();
        if (!mounted) return;
        await Navigator.of(context).push(CupertinoPageRoute(
          builder: (_) => _SeedBackupScreen(
            mnemonic: store.pendingBackupMnemonic ?? '',
            address: acc.address,
          ),
        ));
        store.pendingBackupMnemonic = null;
        if (mounted) Navigator.of(context).pop();
      });

  Future<void> _import() async {
    final value = await _prompt(
      title: 'Import wallet',
      message: 'Paste a 12/24-word recovery phrase or a private key (0x…).',
      placeholder: 'recovery phrase or private key',
      multiline: true,
    );
    if (value == null || value.trim().isEmpty) return;
    await _run(() async {
      final v = value.trim();
      final looksKey = !v.contains(' ') &&
          RegExp(r'^(0x)?[0-9a-fA-F]{64}$').hasMatch(v);
      if (looksKey) {
        await store.importPrivateKey(v);
      } else {
        await store.importSeed(v);
      }
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _enterAddress() async {
    final value = await _prompt(
      title: 'Use an address',
      message: 'Watch-only / recipient. Cannot sign (claim/unwrap need a key).',
      placeholder: '0x…',
    );
    if (value == null || value.trim().isEmpty) return;
    await _run(() async {
      await store.setManualAddress(value.trim());
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _connect() async {
    if (widget.onConnect == null) {
      _alert('Connect wallet',
          'WalletConnect pairing will open your external wallet (e.g. MetaMask).');
      return;
    }
    await _run(() async {
      await widget.onConnect!.call();
      if (mounted && store.hasAccount) Navigator.of(context).pop();
    });
  }

  Future<void> _backupExisting() async {
    final phrase = await store.revealSeedPhrase();
    if (!mounted) return;
    if (phrase == null) {
      _alert('No phrase', 'This account has no recovery phrase to reveal.');
      return;
    }
    await Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => _SeedBackupScreen(
          mnemonic: phrase, address: store.account?.address ?? ''),
    ));
  }

  Future<void> _remove() => _run(() async {
        await store.clearAccount();
        if (mounted) setState(() {});
      });

  @override
  Widget build(BuildContext context) {
    final acc = store.account;
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Ethereum Account'),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (acc != null) _currentAccountCard(acc),
                if (acc != null)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 22, 4, 10),
                    child: Text('Switch account',
                        style: TextStyle(
                            color: _sub,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                _optionCard(
                  icon: CupertinoIcons.sparkles,
                  color: const Color(0xFF30D158),
                  title: 'Create new Ethereum wallet',
                  subtitle: 'Generate a fresh seed phrase on this device',
                  onTap: _create,
                ),
                _optionCard(
                  icon: CupertinoIcons.square_arrow_down,
                  color: _brand,
                  title: 'Import wallet',
                  subtitle: 'Recovery phrase or private key',
                  onTap: _import,
                ),
                _optionCard(
                  icon: CupertinoIcons.pencil_ellipsis_rectangle,
                  color: const Color(0xFFFF9F0A),
                  title: 'Use an address',
                  subtitle: 'Watch-only / wrap recipient (no signing)',
                  onTap: _enterAddress,
                ),
                _optionCard(
                  icon: CupertinoIcons.link,
                  color: const Color(0xFFBF5AF2),
                  title: 'Connect external wallet',
                  subtitle: 'WalletConnect · MetaMask & others',
                  onTap: _connect,
                ),
              ],
            ),
            if (_busy)
              const ColoredBox(
                color: Color(0x99000000),
                child: Center(child: CupertinoActivityIndicator(radius: 16)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _currentAccountCard(EthAccount acc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2A4A), _card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _modeBadge(acc.mode),
              const Spacer(),
              if (acc.canSign)
                const Icon(CupertinoIcons.checkmark_seal_fill,
                    color: Color(0xFF30D158), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: acc.address));
              HapticFeedback.selectionClick();
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(acc.address,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'monospace')),
                ),
                const Icon(CupertinoIcons.doc_on_doc, size: 16, color: _sub),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (acc.mode == EthAccountMode.derived)
                Expanded(
                  child: _smallButton('Back up phrase',
                      CupertinoIcons.lock_shield, _backupExisting),
                ),
              if (acc.mode == EthAccountMode.derived)
                const SizedBox(width: 10),
              Expanded(
                child: _smallButton(
                    'Remove', CupertinoIcons.trash, _remove,
                    danger: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeBadge(EthAccountMode mode) {
    final label = switch (mode) {
      EthAccountMode.derived => 'Seed wallet',
      EthAccountMode.imported => 'Imported key',
      EthAccountMode.walletConnect => 'WalletConnect',
      EthAccountMode.manual => 'Watch address',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              color: _brand, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _smallButton(String label, IconData icon, VoidCallback onTap,
      {bool danger = false}) {
    final c = danger ? const Color(0xFFFF453A) : Colors.white;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: _card2,
      borderRadius: BorderRadius.circular(10),
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: c, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _optionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(color: _sub, fontSize: 12.5)),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.chevron_right,
                    size: 16, color: _sub),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- helpers -------------------------------------------------------------

  Future<String?> _prompt({
    required String title,
    required String message,
    required String placeholder,
    bool multiline = false,
  }) async {
    final ctrl = TextEditingController();
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Column(
          children: [
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: ctrl,
              placeholder: placeholder,
              autofocus: true,
              maxLines: multiline ? 3 : 1,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: const Text('Continue')),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  void _alert(String title, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK')),
        ],
      ),
    );
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ArgumentError: ', '')
      .replaceFirst('StateError: ', '')
      .replaceFirst('Invalid argument(s): ', '');
}

/// Shows a freshly generated seed phrase for the user to back up.
class _SeedBackupScreen extends StatelessWidget {
  final String mnemonic;
  final String address;
  const _SeedBackupScreen({required this.mnemonic, required this.address});

  @override
  Widget build(BuildContext context) {
    final words = mnemonic.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      navigationBar: const CupertinoNavigationBar(middle: Text('Back up')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(CupertinoIcons.lock_shield_fill,
                color: Color(0xFF30D158), size: 44),
            const SizedBox(height: 14),
            const Text('Your recovery phrase',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
                'Write these 12 words down in order and keep them offline. '
                'Anyone with this phrase controls the funds.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _sub, fontSize: 13)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < words.length; i++)
                  Container(
                    width: (MediaQuery.of(context).size.width - 60) / 2,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text('${i + 1}',
                            style: const TextStyle(color: _sub, fontSize: 12)),
                        const SizedBox(width: 8),
                        Text(words[i],
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            CupertinoButton(
              color: _card2,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: mnemonic));
                HapticFeedback.selectionClick();
              },
              child: const Text('Copy phrase'),
            ),
            const SizedBox(height: 8),
            CupertinoButton.filled(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("I've saved it"),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps the screen with a dark Material ancestor (for InkWell ripples) so it
/// can be pushed from the Cupertino app without theme gaps.
Widget buildEthAccountScreen(EthWalletStore store,
    {Future<void> Function()? onConnect}) {
  return Theme(
    data: ThemeData(brightness: Brightness.dark),
    child: Material(
      color: Colors.black,
      child: EthAccountScreen(store: store, onConnect: onConnect),
    ),
  );
}
