import 'package:flutter/material.dart';

/// Static Owl Logo widget using the transparent PNG
class OwlLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const OwlLogo({
    super.key,
    this.size = 32,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/owl_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: color, // Optional tint
        colorBlendMode: color != null ? BlendMode.srcIn : null,
      ),
    );
  }
}
