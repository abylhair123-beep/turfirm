import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.init();
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
      home: ApiService.hasSeenOnboarding ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
