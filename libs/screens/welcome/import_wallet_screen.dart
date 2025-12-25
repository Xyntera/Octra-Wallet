import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  bool mnemonic = true;
  final ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final wp = context.read<WalletProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('import wallet')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: Text(mnemonic ? 'mnemonic' : 'private key'),
              value: mnemonic,
              onChanged: (v) => setState(() => mnemonic = v),
            ),
            TextField(
              controller: ctrl,
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (mnemonic) {
                  await wp.importFromMnemonic(ctrl.text.trim());
                } else {
                  await wp.importFromPrivateKey(ctrl.text.trim());
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('import'),
            )
          ],
        ),
      ),
    );
  }
}
