import 'dart:async';

import 'package:flutter/material.dart';
import '../models/tour.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';
import 'tour_photo.dart';

/// Карточка тура в каталоге — фото, бейдж агентства, рейтинг, цена,
/// а также маркетинговые бейджи: скидка, «горящий» таймер, остаток мест, рассрочка.
class TourCard extends StatelessWidget {
  const TourCard({super.key, required this.tour, required this.onTap});

  static const Color _discountRed = Color(0xFFE53935);
  static const Color _seatsOrange = Color(0xFFEF6C00);
  static const Color _installmentAmber = Color(0xFFFFC107); // Жёлтая плашка рассрочки
  static const Color _installmentInk = Color(0xFF5A4300);

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
                    // Горящий таймер под бейджем агентства
                    if (tour.isHot && tour.hotUntil != null)
                      Positioned(
                        top: 44,
                        left: 12,
                        child: _HotCountdown(until: tour.hotUntil!),
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
                    // Бейдж скидки в правом нижнем углу фото
                    if (tour.discountPercent > 0)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: _discountRed,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '−${tour.discountPercent}%',
                            style: AppText.work(size: 12.5, weight: FontWeight.w700, color: Colors.white),
                          ),
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
                        Expanded(child: Text(tour.title, style: AppText.h4)),
                        const SizedBox(width: 8),
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
                        if (tour.hasDiscount) ...[
                          const SizedBox(width: 8),
                          Text(
                            tour.oldPriceFormatted!,
                            style: AppText.work(size: 12.5, color: AppColors.mutedLight).copyWith(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Рассрочка (как у Kaspi): платёж в месяц — яркая жёлтая плашка
                    if (tour.installmentMonths > 0 && tour.monthlyFormatted != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _installmentAmber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 15, color: _installmentInk),
                            const SizedBox(width: 6),
                            Text(
                              '${tour.monthlyFormatted} × ${tour.installmentMonths} мес',
                              style: AppText.work(size: 12.5, weight: FontWeight.w700, color: _installmentInk),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'в рассрочку',
                              style: AppText.work(size: 11, weight: FontWeight.w600, color: _installmentInk.withValues(alpha: 0.75)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Осталось мест
                    if (tour.seatsLeft != null && tour.seatsLeft! > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, size: 14, color: _seatsOrange),
                          const SizedBox(width: 4),
                          Text(
                            'Осталось ${tour.seatsLeft} ${_seatsWord(tour.seatsLeft!)}',
                            style: AppText.work(size: 11.5, weight: FontWeight.w600, color: _seatsOrange),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _seatsWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'место';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'места';
    return 'мест';
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: AppText.work(size: 11.5, weight: FontWeight.w600, color: fg)),
    );
  }
}

/// Тикающий таймер обратного отсчёта для «горящих туров».
class _HotCountdown extends StatefulWidget {
  const _HotCountdown({required this.until});

  final DateTime until;

  @override
  State<_HotCountdown> createState() => _HotCountdownState();
}

class _HotCountdownState extends State<_HotCountdown> {
  Timer? _timer;
  late Duration _left;

  @override
  void initState() {
    super.initState();
    _left = _remaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _left = _remaining());
    });
  }

  Duration _remaining() {
    final d = widget.until.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    if (_left == Duration.zero) return const SizedBox.shrink();

    final days = _left.inDays;
    final hours = _left.inHours % 24;
    final minutes = _left.inMinutes % 60;
    final seconds = _left.inSeconds % 60;
    final label = days > 0
        ? '$daysд ${_two(hours)}:${_two(minutes)}'
        : '${_two(_left.inHours)}:${_two(minutes)}:${_two(seconds)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5722),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppText.work(size: 11.5, weight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
