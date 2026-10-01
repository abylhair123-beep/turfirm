import 'package:flutter/material.dart';
import 'app_icon.dart';

/// Круглая кнопка-иконка (назад, избранное, колокольчик и т.д.) —
/// повторяющийся элемент почти на каждом экране макета.
class IconCircleButton extends StatelessWidget {
  const IconCircleButton({
    super.key,
    required this.svg,
    required this.onTap,
    this.size = 34,
    this.background = Colors.white,
    this.iconColor = Colors.black,
    this.border,
  });

  final String svg;
  final VoidCallback? onTap;
  final double size;
  final Color background;
  final Color iconColor;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: CircleBorder(
        side: border != null ? BorderSide(color: border!) : BorderSide.none,
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: AppIcon(svg, size: size * 0.46, color: iconColor),
          ),
        ),
      ),
    );
  }
}
