import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

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
  late VideoPlayerController _splashController;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _initSplashVideo();
  }

  Future<void> _initSplashVideo() async {
    _splashController = VideoPlayerController.asset('assets/animatelogo.mp4');
    
    try {
      await _splashController.initialize();
      await _splashController.setLooping(false);
      setState(() => _videoReady = true);
      
      // Play splash video
      _splashController.play();
      
      // Wait for video to end, then check security
      _splashController.addListener(() {
        if (_splashController.value.position >= _splashController.value.duration) {
          _checkSecurity();
        }
      });
      
      // Fallback timeout (3 seconds max)
      Future.delayed(const Duration(seconds: 3), () {
        if (_checking) _checkSecurity();
      });
    } catch (e) {
      print('Splash video error: $e');
      // If video fails, proceed after short delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_checking) _checkSecurity();
      });
    }
  }

  @override
  void dispose() {
    _splashController.dispose();
    super.dispose();
  }

  Future<void> _checkSecurity() async {
    if (!_checking) return;
    
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
        child: _videoReady
          ? SizedBox(
              width: 200,
              height: 200,
              child: VideoPlayer(_splashController),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fallback static logo while video loads
                Image.asset('assets/icon.png', width: 120, height: 120),
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
                const SizedBox(height: 48),
                const CupertinoActivityIndicator(color: Colors.black, radius: 12),
              ],
            ),
      ),
    );
  }
}
