import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Animated Video Splash Screen
/// Plays a 1-second video then navigates to main app
class VideoSplashScreen extends StatefulWidget {
  final Widget child;
  
  const VideoSplashScreen({super.key, required this.child});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  late VideoPlayerController _controller;
  bool _showSplash = true;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.asset('assets/splash_video.mp4');
    
    try {
      await _controller.initialize();
      setState(() => _videoInitialized = true);
      
      // Play video
      _controller.play();
      
      // Listen for video end
      _controller.addListener(() {
        if (_controller.value.position >= _controller.value.duration) {
          _hideSplash();
        }
      });
      
      // Fallback timeout (2 seconds max)
      Future.delayed(const Duration(seconds: 2), () {
        if (_showSplash) _hideSplash();
      });
    } catch (e) {
      print('Video splash error: $e');
      // If video fails, just show splash briefly then continue
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_showSplash) _hideSplash();
      });
    }
  }

  void _hideSplash() {
    if (mounted && _showSplash) {
      setState(() => _showSplash = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSplash) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _videoInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Fallback static logo while video loads
                  Image(
                    image: AssetImage('assets/icon.png'),
                    width: 120,
                    height: 120,
                  ),
                  SizedBox(height: 24),
                  CupertinoActivityIndicator(),
                ],
              ),
      ),
    );
  }
}
