import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoLogo extends StatefulWidget {
  final double size;
  final bool isSplash;

  const VideoLogo({
    super.key,
    this.size = 32,
    this.isSplash = false,
  });

  @override
  State<VideoLogo> createState() => _VideoLogoState();
}

class _VideoLogoState extends State<VideoLogo> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/animatelogo.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          _controller.setLooping(true);
          _controller.play();
          _controller.setVolume(0);
          
          // Listen to position and restart at 3 seconds for endless loop effect
          _controller.addListener(_loopAt3Seconds);
        }
      });
  }

  void _loopAt3Seconds() {
    if (_controller.value.isInitialized) {
      final position = _controller.value.position;
      // Loop back to start after 3 seconds
      if (position.inMilliseconds >= 3000) {
        _controller.seekTo(Duration.zero);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_loopAt3Seconds);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // Show icon placeholder while loading
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Image.asset('assets/icon.png', fit: BoxFit.contain),
      );
    }
    
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.size / 2),
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }
}
