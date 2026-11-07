import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Полноэкранный просмотрщик галереи фотографий с жестами масштабирования (pinch-to-zoom)
/// и переключением свайпом.
class PhotoGalleryViewer extends StatefulWidget {
  const PhotoGalleryViewer({
    super.key,
    required this.photoUrls,
    this.initialIndex = 0,
    required this.title,
    this.fallbackColor = AppColors.teal,
  });

  final List<String> photoUrls;
  final int initialIndex;
  final String title;
  final Color fallbackColor;

  static void show(
    BuildContext context, {
    required List<String> photoUrls,
    int initialIndex = 0,
    required String title,
    Color fallbackColor = AppColors.teal,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) => PhotoGalleryViewer(
          photoUrls: photoUrls,
          initialIndex: initialIndex,
          title: title,
          fallbackColor: fallbackColor,
        ),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<PhotoGalleryViewer> createState() => _PhotoGalleryViewerState();
}

class _PhotoGalleryViewerState extends State<PhotoGalleryViewer> {
  late int _currentIndex;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.photoUrls.isEmpty ? 0 : widget.photoUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.photoUrls;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: SafeArea(
        child: Stack(
          children: [
            // Слайдер фото с возможностью зума
            urls.isEmpty
                ? Center(
                    child: Container(
                      width: 280,
                      height: 200,
                      decoration: BoxDecoration(
                        color: widget.fallbackColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(Icons.photo_library_outlined, size: 64, color: Colors.white70),
                      ),
                    ),
                  )
                : PageView.builder(
                    controller: _pageController,
                    itemCount: urls.length,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.network(
                            urls[index],
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(color: AppColors.coral),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: widget.fallbackColor,
                              child: const Center(
                                child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

            // Верхняя панель (назад, название, счетчик)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppText.sora(size: 15, weight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                  if (urls.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${urls.length}',
                        style: AppText.work(size: 13, weight: FontWeight.w600, color: Colors.white),
                      ),
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),

            // Нижние точки-индикаторы
            if (urls.length > 1)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(urls.length, (i) {
                    final active = i == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: active ? AppColors.coral : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
