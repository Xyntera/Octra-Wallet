import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // For Colors
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'wallet.dart';
import 'ui/wallet_setup.dart';
import 'ui/home.dart';
import 'ui/pin_screen.dart';
import 'ui/video_logo.dart';

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
        brightness: Brightness.light,
        primaryColor: const Color(0xFF111111), // Text Primary
        scaffoldBackgroundColor: const Color(0xFFF8F6F1), // Design 4 BG
        textTheme: CupertinoTextThemeData(
          textStyle: GoogleFonts.inter(color: const Color(0xFF111111)),
          actionTextStyle: GoogleFonts.inter(color: const Color(0xFF111111), fontSize: 18),
          navTitleTextStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
          navLargeTitleTextStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 34),
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
      backgroundColor: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VideoLogo(size: 180, isSplash: true),
            const SizedBox(height: 24),
            const Text(
              'OCTRA WALLET',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 32),
            const CupertinoActivityIndicator(color: Colors.black, radius: 14),
          ],
        ),
      ),
    );
  }
}
