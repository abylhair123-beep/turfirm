import 'package:flutter/material.dart';

/// Фото тура/отеля.
///
/// Если у тура задан [photoUrl] — показывает картинку по сети.
/// Пока картинка грузится или если её нет / не удалось загрузить —
/// показывает сплошной [fallbackColor] (как было в макете).
class TourPhoto extends StatelessWidget {
  const TourPhoto({
    super.key,
    required this.photoUrl,
    required this.fallbackColor,
  });

  final String? photoUrl;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    if (url == null || url.isEmpty) {
      return Container(color: fallbackColor);
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child; // загрузка завершена
        return Container(color: fallbackColor);
      },
      errorBuilder: (context, error, stackTrace) => Container(color: fallbackColor),
    );
  }
}
