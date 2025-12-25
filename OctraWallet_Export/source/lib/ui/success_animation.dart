import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class SuccessAnimation extends StatelessWidget {
  final VoidCallback onComplete;

  const SuccessAnimation({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.9), // Overlay
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
            .then(delay: 1000.ms)
            .fadeOut(duration: 500.ms)
            .callback(callback: (_) => onComplete()), 
            
            const SizedBox(height: 24),
            Text(
              "Sent!",
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ).animate()
             .fadeIn(delay: 200.ms).moveY(begin: 20, end: 0)
             .then(delay: 800.ms).fadeOut(duration: 500.ms)
          ],
        ),
      ),
    );
  }
}
