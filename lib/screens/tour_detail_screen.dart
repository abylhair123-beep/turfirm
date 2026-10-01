import 'package:flutter/material.dart';
import '../models/tour.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/icon_circle_button.dart';
import '../widgets/primary_button.dart';
import 'booking_screen.dart';

class TourDetailScreen extends StatelessWidget {
  const TourDetailScreen({super.key, required this.tour});

  final Tour tour;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _Hero(tour: tour),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tour.title}, ${tour.nights}',
                        style: AppText.h2.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const AppIcon(AppIcons.star, size: 14, color: AppColors.coral),
                          const SizedBox(width: 6),
                          Text(
                            tour.rating.toStringAsFixed(1),
                            style: AppText.work(size: 13.5, weight: FontWeight.w600),
                          ),
                          Text(
                            ' · ${tour.reviewsCount} отзывов',
                            style: AppText.work(size: 13.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.sand,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                const AppIcon(AppIcons.shieldCheck, size: 14, color: AppColors.teal),
                                const SizedBox(width: 6),
                                Text('Продаёт: ${tour.agency}', style: AppText.work(size: 13, weight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (tour.agencyVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.teal, width: 1.3),
                              ),
                              child: Text(
                                'Проверено',
                                style: AppText.work(size: 12, weight: FontWeight.w700, color: AppColors.teal),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _InfoBox(icon: AppIcons.calendar, value: tour.dates, label: 'Даты'),
                          const SizedBox(width: 8),
                          _InfoBox(icon: AppIcons.moon, value: tour.nights, label: 'Длительность'),
                          const SizedBox(width: 8),
                          _InfoBox(icon: AppIcons.food, value: tour.meal, label: 'Питание'),
                          const SizedBox(width: 8),
                          _InfoBox(icon: AppIcons.plane, value: tour.departureCity, label: 'Вылет'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('О туре', style: AppText.h4),
                      const SizedBox(height: 8),
                      Text(tour.description, style: AppText.work(size: 13.5, color: AppColors.inkSoft, weight: FontWeight.w400).copyWith(height: 1.6)),
                      const SizedBox(height: 18),
                      Text('Что включено', style: AppText.h4),
                      const SizedBox(height: 4),
                      for (final item in tour.included)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const AppIcon(AppIcons.checkCircle, size: 18, color: AppColors.teal),
                              const SizedBox(width: 10),
                              Text(item, style: AppText.work(size: 14)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _PriceBar(
            tour: tour,
            onBook: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BookingScreen(tour: tour)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.tour});

  final Tour tour;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: tour.photoColor)),
          Positioned(
            top: 18,
            left: 18,
            child: IconCircleButton(
              svg: AppIcons.back,
              size: 34,
              background: AppColors.ink.withValues(alpha: 0.42),
              iconColor: Colors.white,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: IconCircleButton(
              svg: AppIcons.heart,
              size: 34,
              background: AppColors.ink.withValues(alpha: 0.42),
              iconColor: Colors.white,
              onTap: () {},
            ),
          ),
          Positioned(
            left: 20,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(AppIcons.pin, size: 13, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(tour.destination, style: AppText.work(size: 12.5, weight: FontWeight.w600, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.value, required this.label});

  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            AppIcon(icon, size: 17, color: AppColors.teal),
            const SizedBox(height: 6),
            Text(value, style: AppText.work(size: 13, weight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(label, style: AppText.work(size: 11, color: AppColors.muted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _PriceBar extends StatelessWidget {
  const _PriceBar({required this.tour, required this.onBook});

  final Tour tour;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('за человека', style: AppText.work(size: 11.5, color: AppColors.muted)),
                Text('от ${tour.priceFormatted}', style: AppText.sora(size: 20, weight: FontWeight.w800, color: AppColors.teal)),
              ],
            ),
            SizedBox(
              width: 190,
              child: PrimaryButton(
                label: 'Забронировать',
                onPressed: onBook,
                trailingIcon: const AppIcon(AppIcons.arrowRight, size: 15, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
