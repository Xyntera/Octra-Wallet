import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Video Logo widget for splash screen - loops a 1-second video
class VideoLogo extends StatefulWidget {
  final double size;

  const VideoLogo({
    super.key,
    this.size = 150,
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
    _controller = VideoPlayerController.asset('assets/splash_video.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          _controller.setLooping(true);
          _controller.play();
          _controller.setVolume(0);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // Show placeholder while loading
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Image.asset('assets/owl_logo.png', fit: BoxFit.contain),
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
