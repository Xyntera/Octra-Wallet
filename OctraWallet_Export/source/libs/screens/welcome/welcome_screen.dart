import 'package:flutter/material.dart';
import '../loading/loading_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoadingScreen()),
            );
          },
          child: const Text('create wallet'),
        ),
      ),
    );
  }
}
