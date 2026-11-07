import 'package:flutter/material.dart';
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
  bool _showAllAmenities = false;

  static const int _amenitiesPreview = 6;

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

  // Удобства: показываем первые N, остальные — под кнопкой «Ещё M удобств».
  Widget _buildAmenities(Tour tour) {
    final items = tour.included;
    final showAll = _showAllAmenities || items.length <= _amenitiesPreview;
    final visible = showAll ? items : items.take(_amenitiesPreview).toList();
    final hidden = items.length - _amenitiesPreview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppIcon(AppIcons.checkCircle, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Expanded(child: Text(item, style: AppText.work(size: 14))),
              ],
            ),
          ),
        if (items.length > _amenitiesPreview) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _showAllAmenities = !_showAllAmenities),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(showAll ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 18, color: AppColors.teal),
                  const SizedBox(width: 6),
                  Text(
                    showAll ? 'Скрыть' : 'Ещё $hidden ${_amenityWord(hidden)}',
                    style: AppText.work(size: 13, weight: FontWeight.w700, color: AppColors.teal),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _amenityWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'удобство';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'удобства';
    return 'удобств';
  }

  // Блок «Об отеле»: название + звёзды, описание, фото и удобства по категориям.
  Widget _buildHotelBlock(Tour tour) {
    if (!tour.hasHotelInfo) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Об отеле', style: AppText.h4),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tour.hotelName != null && tour.hotelName!.isNotEmpty)
                Row(
                  children: [
                    Expanded(child: Text(tour.hotelName!, style: AppText.h4)),
                    if (tour.hotelStars != null && tour.hotelStars! > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          tour.hotelStars!,
                          (_) => const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF39C12)),
                        ),
                      ),
                  ],
                ),
              if (tour.hotelDescription != null && tour.hotelDescription!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  tour.hotelDescription!,
                  style: AppText.work(size: 13.5, color: AppColors.inkSoft).copyWith(height: 1.5),
                ),
              ],
              if (tour.hotelPhotos.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: tour.hotelPhotos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 132,
                        height: 92,
                        child: TourPhoto(photoUrl: tour.hotelPhotos[i], fallbackColor: tour.photoColor),
                      ),
                    ),
                  ),
                ),
              ],
              if (tour.hotelAmenities.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final entry in tour.hotelAmenities.entries) ...[
                  Text(entry.key, style: AppText.work(size: 13, weight: FontWeight.w700, color: AppColors.teal)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final a in entry.value) _amenityPill(a)],
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _amenityPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 13, color: AppColors.teal),
          const SizedBox(width: 5),
          Text(text, style: AppText.work(size: 12, color: AppColors.ink)),
        ],
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
                      Text('Удобства и что включено', style: AppText.h4),
                      const SizedBox(height: 8),
                      _buildAmenities(tour),
                      const SizedBox(height: 24),

                      // Блок отеля (заполняет турагентство)
                      _buildHotelBlock(tour),

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
                if (tour.hasDiscount)
                  Text(
                    tour.oldPriceFormatted!,
                    style: AppText.work(size: 12, color: AppColors.mutedLight)
                        .copyWith(decoration: TextDecoration.lineThrough),
                  )
                else
                  Text('за человека', style: AppText.work(size: 11.5, color: AppColors.muted)),
                Text('от ${tour.priceFormatted}', style: AppText.sora(size: 20, weight: FontWeight.w800, color: AppColors.teal)),
                if (tour.installmentMonths > 0 && tour.monthlyFormatted != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${tour.monthlyFormatted} × ${tour.installmentMonths} мес',
                      style: AppText.work(size: 11, weight: FontWeight.w700, color: const Color(0xFF5A4300)),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(
              width: 170,
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
