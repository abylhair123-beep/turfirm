import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/primary_button.dart';
import 'home_screen.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({
    super.key,
    this.bookingId = 'SP-48213',
    this.email = 'aigerim@mail.kz',
  });

  final String bookingId;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: AppColors.successBg,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: AppIcon(AppIcons.check, size: 34, color: AppColors.success),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Бронь подтверждена!',
                style: AppText.h2.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Мы отправили билет и ваучер на $email. '
                'Номер брони — $bookingId.',
                style: AppText.work(size: 14, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'На главную',
                  variant: ButtonVariant.teal,
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
