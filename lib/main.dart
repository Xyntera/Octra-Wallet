import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'wallet.dart';
import 'ui/wallet_setup.dart';
import 'ui/home.dart';
import 'ui/pin_screen.dart';
import 'ui/owl_logo.dart';

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
  bool _wasInBackground = false;
  bool _isLocked = true;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      // Lock the app when coming back from background
      _isLocked = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      navigatorKey: _navigatorKey,
      title: 'Octra Wallet',
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF111111),
        scaffoldBackgroundColor: const Color(0xFFF8F6F1),
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
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSecurity());
  }

  Future<void> _checkSecurity() async {
    final wallet = context.read<WalletController>();
    
    // Always check security if PIN exists and is enabled
    if (await wallet.hasPin && await wallet.isSecurityEnabled) {
       final bool? success = await Navigator.of(context).push(
         CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const PinScreen(isChecking: true))
       );
       if (success != true) {
         // User failed or cancelled - retry
         _checkSecurity();
         return;
       }
    }

    setState(() => _checking = false);

    // Navigate to appropriate screen
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
            // Owl Logo (transparent PNG)
            const OwlLogo(size: 150),
            const SizedBox(height: 32),
            const Text(
              'OCTRA WALLET',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'SECURE • PRIVATE • FAST',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 48),
            if (_checking)
              const CupertinoActivityIndicator(color: Colors.black, radius: 12),
          ],
        ),
      ),
    );
  }
}
