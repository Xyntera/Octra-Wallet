import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // For Colors
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'wallet.dart';
import 'ui/wallet_setup.dart';
import 'ui/home.dart';
import 'ui/pin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final walletController = WalletController();
  await walletController.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => walletController),
      ],
      child: const OctraWalletApp(),
    ),
  );
}

class OctraWalletApp extends StatefulWidget {
  const OctraWalletApp({super.key});

  @override
  State<OctraWalletApp> createState() => _OctraWalletAppState();
}

class _OctraWalletAppState extends State<OctraWalletApp> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Implement force lock here if needed later
      // For now, simpler is better to avoid navigation key issues without global key
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Octra Wallet',
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0A84FF), // iOS Blue
        scaffoldBackgroundColor: Colors.black,
        textTheme: CupertinoTextThemeData(
          textStyle: GoogleFonts.outfit(),
        ),
      ),
      home: const StartupCheck(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class StartupCheck extends StatefulWidget {
  const StartupCheck({super.key});

  @override
  State<StartupCheck> createState() => _StartupCheckState();
}

class _StartupCheckState extends State<StartupCheck> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSecurity());
  }

  Future<void> _checkSecurity() async {
    final wallet = context.read<WalletController>();
    
    // Check PIN & Enabled
    if (await wallet.hasPin && await wallet.isSecurityEnabled) {
       final bool? success = await Navigator.of(context).push(
         CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const PinScreen(isChecking: true))
       );
       if (success != true) {
         _checkSecurity();
         return;
       }
    }

    // Check Wallet
    if (wallet.hasWallet) {
       Navigator.of(context).pushReplacement(
         CupertinoPageRoute(builder: (_) => const HomeTabScaffold())
       );
    } else {
       Navigator.of(context).pushReplacement(
         CupertinoPageRoute(builder: (_) => const WalletSetupPage())
       );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF03057C), Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter
          )
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.circle_grid_hex, size: 80, color: Color(0xFF0A84FF)),
              SizedBox(height: 32),
              CupertinoActivityIndicator(color: Colors.white, radius: 14)
            ]
          ),
        ),
      )
    );
  }
}
