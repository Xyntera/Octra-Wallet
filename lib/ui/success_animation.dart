import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class SuccessAnimation extends StatefulWidget {
  final Future<void> request; // 👈 REAL API FUTURE
  final VoidCallback onComplete;

  const SuccessAnimation({
    super.key,
    required this.request,
    required this.onComplete,
  });

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation> {
  bool _sent = false;

  @override
  void initState() {
    super.initState();

    widget.request.then((_) {
      if (!mounted) return;
      setState(() => _sent = true);

      Future.delayed(const Duration(milliseconds: 900), () {
        widget.onComplete();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.92),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _sent ? _successCircle() : _pendingCircle(),
            ),
            const SizedBox(height: 22),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _sent ? "Sent" : "Sending",
                key: ValueKey(_sent),
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingCircle() {
    return Container(
      key: const ValueKey("pending"),
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    ).animate().fadeIn().scale();
  }

  Widget _successCircle() {
    return Container(
      key: const ValueKey("sent"),
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.35),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.check_rounded,
        size: 56,
        color: Colors.black,
      ),
    ).animate().scale(duration: 450.ms, curve: Curves.easeOutBack).fadeIn();
  }
}
