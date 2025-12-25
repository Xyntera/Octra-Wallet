import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';

class SendTab extends StatelessWidget {
  const SendTab({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WalletProvider>();
    final toCtrl = TextEditingController();
    final amtCtrl = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: toCtrl, decoration: const InputDecoration(labelText: 'to address')),
          TextField(controller: amtCtrl, decoration: const InputDecoration(labelText: 'amount')),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: wp.sending
                ? null
                : () => wp.send(
                      to: toCtrl.text,
                      amount: double.tryParse(amtCtrl.text) ?? 0,
                    ),
            child: wp.sending
                ? const CircularProgressIndicator()
                : const Text('send'),
          ),
        ],
      ),
    );
  }
}
