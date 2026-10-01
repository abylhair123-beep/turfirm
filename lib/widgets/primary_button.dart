import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum ButtonVariant { coral, teal, white }

/// Основная кнопка действия. Тот же стиль на всех экранах:
/// скруглённый прямоугольник, Sora Bold, без тени.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.coral,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final Widget? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (variant) {
      case ButtonVariant.coral:
        bg = AppColors.coral;
        fg = Colors.white;
        break;
      case ButtonVariant.teal:
        bg = AppColors.teal;
        fg = Colors.white;
        break;
      case ButtonVariant.white:
        bg = Colors.white;
        fg = AppColors.tealDark;
        break;
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: AppText.sora(size: 16, color: fg)),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                trailingIcon!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
