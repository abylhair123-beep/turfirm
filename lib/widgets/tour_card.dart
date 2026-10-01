import 'package:flutter/material.dart';
import '../models/tour.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';

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
                    Container(color: tour.photoColor),
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
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.ink.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: AppIcon(AppIcons.heart, size: 15, color: Colors.white),
                        ),
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
}
