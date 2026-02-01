import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoLogo extends StatefulWidget {
  final double size;
  final bool isSplash; // If true, maybe larger or different behavior

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
        // Ensure the first frame is shown after the video is initialized
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          _controller.setLooping(true);
          _controller.play();
          _controller.setVolume(0); // Mute just in case
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
      // Show a placeholder or nothing while loading
      return SizedBox(width: widget.size, height: widget.size);
    }
    
    // Video aspect ratio
    // If video has white background, we might want to scale it to fit/cover
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipOval(
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
