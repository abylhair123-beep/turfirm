import 'package:flutter/material.dart';
import '../models/tour.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';
import 'tour_photo.dart';

/// Карточка тура в каталоге — фото-плейсхолдер (сплошной брендовый цвет,
/// как в макете), бейдж агентства, рейтинг, цена.
class TourCard extends StatelessWidget {
  const TourCard({super.key, required this.tour, required this.onTap});

  final Tour tour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 150,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: TourPhoto(
                        photoUrl: tour.primaryPhotoUrl,
                        fallbackColor: tour.photoColor,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _pill(
                        tour.agency,
                        Colors.white.withValues(alpha: 0.9),
                        AppColors.ink,
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: ValueListenableBuilder<Set<String>>(
                        valueListenable: ApiService.favoritesNotifier,
                        builder: (context, favs, _) {
                          final isFav = favs.contains(tour.id);
                          return GestureDetector(
                            onTap: () {
                              ApiService.toggleFavorite(tour.id);
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isFav
                                    ? Colors.white
                                    : AppColors.ink.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  size: 17,
                                  color: isFav ? const Color(0xFFE53935) : Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 10,
                      child: _pill(
                        tour.destination,
                        AppColors.ink.withValues(alpha: 0.55),
                        Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tour.title, style: AppText.h4),
                        Row(
                          children: [
                            const AppIcon(AppIcons.star, size: 13, color: AppColors.coral),
                            const SizedBox(width: 3),
                            Text(
                              tour.rating.toStringAsFixed(1),
                              style: AppText.work(size: 13, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(tour.meta, style: AppText.caption),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _attrTag('${tour.hotelStars}★', const Color(0xFFFFF8E1), const Color(0xFFF57F17)),
                        _attrTag(tour.mealType.isNotEmpty ? tour.mealType : tour.meal, const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
                        if (tour.beachLine > 0)
                          _attrTag('${tour.beachLine}-я линия', const Color(0xFFE1F5FE), const Color(0xFF0288D1)),
                        _attrTag('${tour.durationNights} ночей', const Color(0xFFF3E5F5), const Color(0xFF7B1FA2)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('от ', style: AppText.work(size: 12, color: AppColors.mutedLight)),
                        Text(tour.priceFormatted, style: AppText.price),
                        Text(' / чел.', style: AppText.work(size: 12, color: AppColors.mutedLight)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: AppText.work(size: 11.5, weight: FontWeight.w600, color: fg)),
    );
  }

  Widget _attrTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
