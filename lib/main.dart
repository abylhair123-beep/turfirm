import 'package:flutter/material.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SaparApp());
}

class SaparApp extends StatelessWidget {
  const SaparApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sapar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const OnboardingScreen(),
    );
  }
}
