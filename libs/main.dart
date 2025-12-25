import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/wallet_provider.dart';
import 'app_bootstrap.dart';

void main() {
  runApp(const OuqroApp());
}

class OuqroApp extends StatelessWidget {
  const OuqroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WalletProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const AppBootstrap(),
      ),
    );
  }
}
