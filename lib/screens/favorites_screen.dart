import 'package:flutter/material.dart';
import '../models/tour.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/tour_card.dart';
import 'tour_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Tour> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final tours = await ApiService.getFavorites();
    if (mounted) {
      setState(() {
        _favorites = tours;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Избранные туры', style: AppText.h3.copyWith(fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadFavorites,
          color: AppColors.teal,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
              : _favorites.isEmpty
                  ? _emptyView()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: _favorites.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final tour = _favorites[index];
                        return TourCard(
                          tour: tour,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => TourDetailScreen(tour: tour)),
                            );
                            _loadFavorites();
                          },
                        );
                      },
                    ),
        ),
      ),
    );
  }

  Widget _emptyView() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_border_rounded, size: 40, color: Color(0xFFE53935)),
              ),
              const SizedBox(height: 16),
              Text(
                'В избранном пока пусто',
                style: AppText.h3.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                'Нажимайте на сердечко в карточке тура,\nчтобы сохранить понравившиеся варианты',
                textAlign: TextAlign.center,
                style: AppText.work(size: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
