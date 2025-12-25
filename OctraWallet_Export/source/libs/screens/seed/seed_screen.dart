import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../wallet/wallet_screen.dart';

class SeedScreen extends StatelessWidget {
  const SeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.read<WalletProvider>().wallet!;

    return Scaffold(
      appBar: AppBar(title: const Text('backup recovery phrase')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'write down these 12 words in order',
              style: TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: wallet.mnemonic.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 3,
                ),
                itemBuilder: (_, i) => Card(
                  color: Colors.black,
                  child: Center(
                    child: Text(
                      '${i + 1}. ${wallet.mnemonic[i]}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WalletScreen(),
                  ),
                );
              },
              child: const Text('i saved it'),
            )
          ],
        ),
      ),
    );
  }
}
