import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import 'export_wallet_dialog.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = context.read<WalletProvider>();

    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.lock),
          title: const Text('backup wallet'),
          onTap: () => showDialog(
            context: context,
            builder: (_) => const ExportWalletDialog(),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('logout'),
          onTap: () async => await wp.logout(),
        ),
      ],
    );
  }
}
