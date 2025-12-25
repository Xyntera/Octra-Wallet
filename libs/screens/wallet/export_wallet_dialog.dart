import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';

class ExportWalletDialog extends StatelessWidget {
  const ExportWalletDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final w = context.read<WalletProvider>().wallet!;
    return AlertDialog(
      title: const Text('backup wallet'),
      content: SelectableText(
        '''
Mnemonic:
${w.mnemonic.join(' ')}

Private Key (Base64):
${w.privateKeyB64}

Address:
${w.address}
''',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('close'),
        )
      ],
    );
  }
}
