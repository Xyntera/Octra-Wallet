import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class SuccessAnimation extends StatelessWidget {
  final VoidCallback onComplete;

  const SuccessAnimation({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    // Icon: scale(400ms) → hold(800ms) → fadeOut(400ms) → callback at 1600ms
    // Text: fadeIn+moveY(50..250ms) → hold(950ms) → fadeOut(400ms) → done at 1600ms
    return Material(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
              ),
              child: const Icon(Icons.check, size: 60, color: Colors.white),
            )
                .animate()
                .scale(duration: 400.ms, curve: Curves.elasticOut)
                .then(delay: 800.ms)
                .fadeOut(duration: 400.ms)
                .callback(callback: (_) => onComplete()),
            const SizedBox(height: 24),
            Text(
              'Done!',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            )
                .animate()
                .fadeIn(delay: 50.ms, duration: 200.ms)
                .moveY(begin: 16, end: 0, duration: 250.ms)
                .then(delay: 950.ms)
                .fadeOut(duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
