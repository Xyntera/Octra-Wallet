import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/privacy_provider.dart';
import '../../providers/wallet_provider.dart';

class PrivacyTab extends StatefulWidget {
  const PrivacyTab({super.key});

  @override
  State<PrivacyTab> createState() => _PrivacyTabState();
}

class _PrivacyTabState extends State<PrivacyTab> {
  bool encryptMode = true;
  final amountCtrl = TextEditingController();
  final addrCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final privacy = context.watch<PrivacyProvider>();
    final wallet = context.read<WalletProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() => encryptMode = true),
                child: const Text('encrypt'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() => encryptMode = false),
                child: const Text('decrypt'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                encryptMode ? 'amount to encrypt' : 'amount to decrypt',
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: privacy.loading
              ? null
              : () {
                  final amt = double.parse(amountCtrl.text);
                  encryptMode
                      ? privacy.encrypt(wallet, amt)
                      : privacy.decrypt(wallet, amt);
                },
          child: const Text('submit'),
        ),
        const Divider(height: 32),
        const Text('private send'),
        const SizedBox(height: 8),
        TextField(
          controller: addrCtrl,
          decoration:
              const InputDecoration(labelText: 'recipient address'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            privacy.privateSend(
              wallet,
              addrCtrl.text,
              double.parse(amountCtrl.text),
            );
          },
          child: const Text('send privately'),
        ),
        const Divider(height: 32),
        const Text('pending transfers'),
        const SizedBox(height: 8),
        ...privacy.pending.map(
          (p) => ListTile(
            title: Text(p.from),
            subtitle: Text(p.hash),
            trailing: Text('${p.amount} OCT'),
          ),
        )
      ],
    );
  }
}
