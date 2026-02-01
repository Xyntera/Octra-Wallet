import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class OwlLogo extends StatefulWidget {
  final Color color;
  final double size;

  const OwlLogo({
    super.key,
    this.color = Colors.black,
    this.size = 32,
  });

  @override
  State<OwlLogo> createState() => _OwlLogoState();
}

class _OwlLogoState extends State<OwlLogo> with TickerProviderStateMixin {
  // Pupil movement
  Offset _pupilOffset = Offset.zero;
  Timer? _lookTimer;
  
  // Blinking
  late AnimationController _blinkController;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    
    // Blink Animation
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _startLooking();
    _startBlinking();
  }

  @override
  void dispose() {
    _lookTimer?.cancel();
    _blinkTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  void _startBlinking() {
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 4000), (timer) {
      if (Random().nextBool()) {
        _blink();
      }
    });
  }

  Future<void> _blink() async {
    if (!mounted) return;
    try {
      await _blinkController.forward();
      // Short pause closed
      await Future.delayed(const Duration(milliseconds: 50));
      await _blinkController.reverse();
    } catch (_) {}
  }

  void _startLooking() {
    _lookTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          // Constrain pupils to circle
          final r = Random();
          final angle = r.nextDouble() * 2 * pi;
          // Random distance from center, favoring center slightly
          final dist = r.nextDouble() * 0.5; 
          
          final dx = cos(angle) * dist;
          final dy = sin(angle) * dist;
          _pupilOffset = Offset(dx, dy);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.2, // Visual aspect ratio
      height: widget.size,
      child: AnimatedBuilder(
        animation: _blinkController,
        builder: (context, child) {
          return CustomPaint(
            painter: _OwlPainter(
              color: widget.color,
              pupilOffset: _pupilOffset,
              blinkValue: _blinkController.value,
            ),
          );
        },
      ),
    );
  }
}

class _OwlPainter extends CustomPainter {
  final Color color;
  final Offset pupilOffset;
  final double blinkValue;

  _OwlPainter({
    required this.color,
    required this.pupilOffset,
    required this.blinkValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
      
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round;

    // --- 1. HEAD SHAPE (Outline/Ears) ---
    // Drawing a stylized owl head shape
    final headPath = Path();
    
    // Start from bottom center
    headPath.moveTo(w * 0.5, h * 0.95);
    
    // Curve up to left cheek
    headPath.quadraticBezierTo(w * 0.1, h * 0.85, w * 0.1, h * 0.5);
    
    // Left Ear tip
    headPath.quadraticBezierTo(w * 0.05, h * 0.2, w * 0.25, h * 0.1);
    
    // Top of head (brow dip)
    headPath.quadraticBezierTo(w * 0.5, h * 0.35, w * 0.75, h * 0.1);
    
    // Right Ear tip
    headPath.quadraticBezierTo(w * 0.95, h * 0.2, w * 0.9, h * 0.5);
    
    // Curve down to right cheek and back to bottom
    headPath.quadraticBezierTo(w * 0.9, h * 0.85, w * 0.5, h * 0.95);
    headPath.close();

    // Draw Head Outline (or Fill if desired, using stroke here for 'logo' look)
    // Adjusting to Fill for solid look, or stroke for outlined look.
    // Based on user "dark mode", a filled shape might be heavy. Let's do heavy stroke.
    // Actually, user wants "Exactly" the image. Usually logos are filled shapes.
    // Let's try to mimic the image structure: Big eyes, brow, beak.
    
    // Let's Draw the FEATURES primarily, as that's the "Icon" usually.
    
    // --- BROWS / EARS ---
    // The "Horns"
    final browPath = Path();
    browPath.moveTo(w * 0.2, h * 0.35); // Left inner brow
    browPath.quadraticBezierTo(w * 0.1, h * 0.15, w * 0.05, h * 0.2); // Left tip
    browPath.quadraticBezierTo(w * 0.3, h * 0.45, w * 0.5, h * 0.55); // Center dip
    browPath.quadraticBezierTo(w * 0.7, h * 0.45, w * 0.95, h * 0.2); // Right tip
    browPath.quadraticBezierTo(w * 0.9, h * 0.15, w * 0.8, h * 0.35); // Right inner brow
    
    // Connect brows to center beak area
    browPath.quadraticBezierTo(w * 0.5, h * 0.65, w * 0.2, h * 0.35);
    // This is hard to get "Exact" without seeing. 
    // Let's use a simpler, cleaner geometric construction typical of vector owls.

    // 1. Two large circles for eye sockets
    final leftEyeCenter = Offset(w * 0.32, h * 0.55);
    final rightEyeCenter = Offset(w * 0.68, h * 0.55);
    final eyeOuterRadius = w * 0.26;
    
    // Draw outer eye rings (Thick stroke)
    strokePaint.strokeWidth = w * 0.08;
    canvas.drawCircle(leftEyeCenter, eyeOuterRadius, strokePaint);
    canvas.drawCircle(rightEyeCenter, eyeOuterRadius, strokePaint);

    // 2. Eyebrows / Tufts (Filled, sitting on top)
    final tuftPath = Path();
    tuftPath.moveTo(w * 0.5, h * 0.55); // Center point between eyes
    // Left Tuft
    tuftPath.quadraticBezierTo(w * 0.35, h * 0.45, w * 0.1, h * 0.2); // Curve out to left tip
    tuftPath.quadraticBezierTo(w * 0.25, h * 0.3, w * 0.35, h * 0.35); // Underlying curve?
    // Let's simplify: A dominant "V" or "M" shape
    
    // Start Center
    tuftPath.reset();
    tuftPath.moveTo(w * 0.5, h * 0.55); 
    // Curve UP and LEFT to ear tip
    tuftPath.cubicTo(w * 0.4, h * 0.4, w * 0.2, h * 0.25, w * 0.02, h * 0.15);
    // Curve DOWN and RIGHT to top of eye
    tuftPath.quadraticBezierTo(w * 0.2, h * 0.32, w * 0.32, h * 0.4);
    tuftPath.close(); // Close left tuft
    
    canvas.drawPath(tuftPath, paint); // Fill left tuft
    
    // Mirror for Right Tuft
    final rightTuftPath = Path();
    rightTuftPath.moveTo(w * 0.5, h * 0.55);
    rightTuftPath.cubicTo(w * 0.6, h * 0.4, w * 0.8, h * 0.25, w * 0.98, h * 0.15);
    rightTuftPath.quadraticBezierTo(w * 0.8, h * 0.32, w * 0.68, h * 0.4);
    rightTuftPath.close();
    
    canvas.drawPath(rightTuftPath, paint);

    // 3. Beak (Diamond/Triangle shape in center)
    final beakPath = Path();
    beakPath.moveTo(w * 0.5, h * 0.55);
    beakPath.lineTo(w * 0.56, h * 0.65);
    beakPath.lineTo(w * 0.5, h * 0.75);
    beakPath.lineTo(w * 0.44, h * 0.65);
    beakPath.close();
    canvas.drawPath(beakPath, paint);

    // 4. Pupils (Animated)
    final pupilRadius = w * 0.1;
    final maxPupilMove = w * 0.08;
    
    final currentPupilOffset = Offset(
      pupilOffset.dx * maxPupilMove, 
      pupilOffset.dy * maxPupilMove
    );
    
    canvas.drawCircle(leftEyeCenter + currentPupilOffset, pupilRadius, paint);
    canvas.drawCircle(rightEyeCenter + currentPupilOffset, pupilRadius, paint);
    
    // 5. Blinking (Eyelids)
    if (blinkValue > 0) {
      final lidHeight = eyeOuterRadius * 2.2 * blinkValue;
      final lidPaint = Paint()..color = color;
      
      // We clip the eyelids to the eye circles so they look natural
      // Left
      canvas.save();
      final lRect = Rect.fromCircle(center: leftEyeCenter, radius: eyeOuterRadius * 0.9); // Highlight area
      canvas.clipRect(lRect); // Only draw inside eye
      canvas.drawRect(Rect.fromLTWH(lRect.left, lRect.top, lRect.width, lidHeight), lidPaint);
      canvas.restore();
      
      // Right
      canvas.save();
      final rRect = Rect.fromCircle(center: rightEyeCenter, radius: eyeOuterRadius * 0.9);
      canvas.clipRect(rRect);
      canvas.drawRect(Rect.fromLTWH(rRect.left, rRect.top, rRect.width, lidHeight), lidPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _OwlPainter old) {
    return old.color != color || old.pupilOffset != pupilOffset || old.blinkValue != blinkValue;
  }
}
