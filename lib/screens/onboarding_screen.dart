import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/primary_button.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tealDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SAPAR',
                    style: AppText.sora(
                      size: 15,
                      weight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _goHome(context),
                    child: Text(
                      'Пропустить',
                      style: AppText.work(
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const _OnboardingIllustration(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Все туры Казахстана —\nв одном приложении',
                      style: AppText.h1.copyWith(color: Colors.white, height: 1.28),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Сравнивайте предложения турагентств, следите за ценами '
                      'и бронируйте туры за пару минут — без звонков и очередей.',
                      style: AppText.work(
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dot(active: true),
                  const SizedBox(width: 6),
                  _dot(active: false),
                  const SizedBox(width: 6),
                  _dot(active: false),
                ],
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Продолжить',
                variant: ButtonVariant.white,
                onPressed: () => _goHome(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Widget _dot({required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: active ? 20 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: active ? AppColors.coral : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// Простая декоративная иллюстрация: солнце + силуэты гор, тем же
/// духом, что и в макете, но нарисована виджетами Flutter вместо SVG.
class _OnboardingIllustration extends StatelessWidget {
  const _OnboardingIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 8,
            right: 30,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.coral,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 120),
              painter: _MountainsPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MountainsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final back = Paint()..color = Colors.white.withValues(alpha: 0.16);
    final front = Paint()..color = Colors.white.withValues(alpha: 0.30);

    final backPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.18, size.height * 0.28)
      ..lineTo(size.width * 0.32, size.height * 0.62)
      ..lineTo(size.width * 0.48, size.height * 0.12)
      ..lineTo(size.width * 0.66, size.height * 0.62)
      ..lineTo(size.width, size.height * 0.05)
      ..lineTo(size.width, size.height)
      ..close();

    final frontPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.22, size.height * 0.42)
      ..lineTo(size.width * 0.4, size.height * 0.72)
      ..lineTo(size.width * 0.56, size.height * 0.30)
      ..lineTo(size.width * 0.78, size.height * 0.72)
      ..lineTo(size.width, size.height * 0.44)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(backPath, back);
    canvas.drawPath(frontPath, front);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
