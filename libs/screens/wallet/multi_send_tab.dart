import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../models/recipient_model.dart';

class MultiSendTab extends StatefulWidget {
  const MultiSendTab({super.key});

  @override
  State<MultiSendTab> createState() => _MultiSendTabState();
}

class _MultiSendTabState extends State<MultiSendTab> {
  final addrCtrl = TextEditingController();
  final amtCtrl = TextEditingController();
  final List<RecipientModel> recipients = [];

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WalletProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: addrCtrl,
          decoration: const InputDecoration(labelText: 'address'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: amtCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'amount'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              recipients.add(
                RecipientModel(
                  address: addrCtrl.text,
                  amount: double.parse(amtCtrl.text),
                ),
              );
              addrCtrl.clear();
              amtCtrl.clear();
            });
          },
          child: const Text('+ add recipient'),
        ),
        const SizedBox(height: 16),
        ...recipients.map(
          (r) => ListTile(
            title: Text(r.address),
            trailing: Text('${r.amount} OCT'),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: wp.sending
              ? null
              : () => wp.multiSend(recipients),
          child: wp.sending
              ? const CircularProgressIndicator()
              : const Text('send all'),
        ),
      ],
    );
  }
}
