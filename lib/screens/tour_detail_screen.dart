import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/review.dart';
import '../models/tour.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/icon_circle_button.dart';
import '../widgets/photo_gallery_viewer.dart';
import '../widgets/primary_button.dart';
import '../widgets/tour_photo.dart';
import 'booking_screen.dart';

class TourDetailScreen extends StatefulWidget {
  const TourDetailScreen({super.key, required this.tour});

  final Tour tour;

  @override
  State<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends State<TourDetailScreen> {
  List<TourReview> _reviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final list = await ApiService.getReviews(widget.tour.id);
    if (mounted) {
      setState(() {
        _reviews = list;
        _isLoadingReviews = false;
      });
    }
  }

  void _showAddReviewDialog() {
    double selectedRating = 5.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Оставить отзыв о туре', style: AppText.h3.copyWith(fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final star = index + 1;
                    return IconButton(
                      icon: Icon(
                        star <= selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: const Color(0xFFF39C12),
                        size: 32,
                      ),
                      onPressed: () {
                        setDialogState(() => selectedRating = star.toDouble());
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Расскажите о впечатлениях, сервисе турагентства...',
                    hintStyle: AppText.work(size: 13, color: AppColors.mutedLight),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Отмена', style: AppText.work(color: AppColors.muted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  if (commentController.text.trim().isNotEmpty) {
                    await ApiService.addReview(
                      tourId: widget.tour.id,
                      rating: selectedRating,
                      comment: commentController.text,
                    );
                    _loadReviews();
                  }
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Отзыв успешно добавлен!')),
                    );
                  }
                },
                child: const Text('Отправить', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tour = widget.tour;
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
                            ' · ${_reviews.length} отзывов',
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
                                Text(
                                  tour.agency,
                                  style: AppText.work(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                                ),
                                if (tour.agencyVerified) ...[
                                  const SizedBox(width: 6),
                                  const AppIcon(AppIcons.shieldCheck, size: 15, color: AppColors.teal),
                                ],
                              ],
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
                      Text(
                        tour.description,
                        style: AppText.work(size: 13.5, color: AppColors.inkSoft, weight: FontWeight.w400)
                            .copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 18),
                      Text('Что включено', style: AppText.h4),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 24),

                      // Блок отзывов
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Отзывы путешественников', style: AppText.h4),
                          TextButton.icon(
                            onPressed: _showAddReviewDialog,
                            icon: const Icon(Icons.rate_review_outlined, size: 16, color: AppColors.teal),
                            label: const Text('Написать', style: TextStyle(color: AppColors.teal, fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingReviews)
                        const Center(child: CircularProgressIndicator(color: AppColors.teal))
                      else if (_reviews.isEmpty)
                        Text('Пока нет отзывов. Будьте первыми!', style: AppText.work(size: 13, color: AppColors.muted))
                      else
                        for (final r in _reviews)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      r.authorName,
                                      style: AppText.work(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF39C12)),
                                        const SizedBox(width: 3),
                                        Text(r.rating.toStringAsFixed(1), style: AppText.work(size: 13, weight: FontWeight.w600)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  r.comment,
                                  style: AppText.work(size: 13, color: AppColors.inkSoft),
                                ),
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

class _Hero extends StatefulWidget {
  const _Hero({required this.tour});

  final Tour tour;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tour = widget.tour;
    final photos = tour.photoUrls;

    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          // Слайдер фотографий
          Positioned.fill(
            child: photos.isNotEmpty
                ? PageView.builder(
                    controller: _pageController,
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    itemBuilder: (context, i) {
                      return GestureDetector(
                        onTap: () {
                          PhotoGalleryViewer.show(
                            context,
                            photoUrls: photos,
                            initialIndex: _currentIndex,
                            title: tour.title,
                            fallbackColor: tour.photoColor,
                          );
                        },
                        child: TourPhoto(
                          photoUrl: photos[i],
                          fallbackColor: tour.photoColor,
                        ),
                      );
                    },
                  )
                : TourPhoto(
                    photoUrl: tour.photoUrl,
                    fallbackColor: tour.photoColor,
                  ),
          ),

          // Затемнение сверху для читаемости кнопок
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 70,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Кнопка назад
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

          // Кнопка «Поделиться туром / Реферальная ссылка»
          Positioned(
            top: 18,
            right: 62,
            child: GestureDetector(
              onTap: () {
                final refCode = ApiService.activeReferralCode ?? 'SAPAR';
                final shareUrl = 'https://sapar.kz/tours/${tour.id}?ref=$refCode';
                Clipboard.setData(ClipboardData(text: shareUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Ссылка на тур скопирована: $shareUrl')),
                      ],
                    ),
                    backgroundColor: AppColors.teal,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.share_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Кнопка избранного
          Positioned(
            top: 18,
            right: 18,
            child: ValueListenableBuilder<Set<String>>(
              valueListenable: ApiService.favoritesNotifier,
              builder: (context, favs, _) {
                final isFav = favs.contains(tour.id);
                return GestureDetector(
                  onTap: () {
                    ApiService.toggleFavorite(tour.id);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isFav ? Colors.white : AppColors.ink.withValues(alpha: 0.42),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 20,
                        color: isFav ? const Color(0xFFE53935) : Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Локация тура (снизу слева)
          Positioned(
            left: 20,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(AppIcons.pin, size: 13, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    tour.destination,
                    style: AppText.work(size: 12.5, weight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // Счетчик фото и кнопка полноэкранного зума (снизу справа)
          if (photos.isNotEmpty)
            Positioned(
              right: 20,
              bottom: 16,
              child: GestureDetector(
                onTap: () {
                  PhotoGalleryViewer.show(
                    context,
                    photoUrls: photos,
                    initialIndex: _currentIndex,
                    title: tour.title,
                    fallbackColor: tour.photoColor,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_currentIndex + 1}/${photos.length}',
                        style: AppText.work(size: 12, weight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
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
                title: 'Забронировать',
                onTap: onBook,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
