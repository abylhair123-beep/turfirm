import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_service.dart';
import 'services/locale_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  await LocaleService.init();
  runApp(const SaparApp());
}

class SaparApp extends StatelessWidget {
  const SaparApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleService.localeNotifier,
      builder: (context, locale, _) {
        return MaterialApp(
          title: 'Sapar',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          navigatorKey: NotificationService.navigatorKey,
          locale: locale,
          supportedLocales: const [
            Locale('ru'),
            Locale('kk'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ApiService.hasSeenOnboarding ? const HomeScreen() : const OnboardingScreen(),
        );
      },
    );
  }
}
