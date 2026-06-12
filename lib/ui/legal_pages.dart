import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;

class LegalPage extends StatelessWidget {
  final String title;
  final String content;

  const LegalPage({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.white,
      navigationBar: CupertinoNavigationBar(
        middle: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black,
              fontFamily: 'Helvetica Neue',
            ),
          ),
        ),
      ),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalPage(
      title: 'PRIVACY POLICY',
      content: '''
Effective Date: February 1, 2026

1. DATA COLLECTION
Octra Wallet is a non-custodial wallet. We do not collect, store, or transmit your personal data, private keys, or seed phrases. 
All keys are generated and stored locally on your device using secure storage.

2. LOCAL STORAGE
Your private keys and transaction history are stored securely on your device. You are responsible for backing up your seed phrase. If you lose your device or delete the app without a backup, your funds cannot be recovered.

3. NETWORK INTERACTION
The app connects to the Octra Network RPC nodes to broadcast transactions and fetch balances. Your IP address may be visible to these nodes, but no personal identity is attached to your wallet address.

4. THIRD-PARTY SERVICES
We heavily respect user privacy. No analytics or tracking SDKs are included in this build.

5. CHANGES
We may update this policy. Continued use implies acceptance.
''',
    );
  }
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalPage(
      title: 'TERMS & CONDITIONS',
      content: '''
Last Updated: February 1, 2026

1. ACCEPTANCE
By using Octra Wallet, you agree to these terms.

2. NO WARRANTY
The software is provided "AS IS", without warranty of any kind. The developers are not liable for any damages, including loss of funds, arising from the use of this software.

3. YOUR RESPONSIBILITY
You are solely responsible for securing your private keys and PIN. We cannot access or recover your funds if you lose your credentials.

4. COMPLIANCE
You agree to use this wallet in compliance with all applicable laws in your jurisdiction.

5. OPEN SOURCE
Parts of this software may be open source. Stick to the licenses provided in the repository.
''',
    );
  }
}
