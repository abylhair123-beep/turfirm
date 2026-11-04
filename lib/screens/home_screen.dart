import 'package:flutter/material.dart';
import '../models/tour.dart';
import '../services/api_service.dart';
import '../services/locale_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/category_chip.dart';
import '../widgets/icon_circle_button.dart';
import '../widgets/tour_card.dart';
import 'bookings_list_screen.dart';
import 'create_tour_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'tour_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _buildCurrentTab(),
      ),
      bottomNavigationBar: _BottomTabBar(
        index: _tabIndex,
        onChanged: (i) => setState(() => _tabIndex = i),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_tabIndex) {
      case 1:
        return const SearchScreen();
      case 2:
        return const BookingsListScreen();
      case 3:
        return const ProfileScreen();
      default:
        return _HomeCatalogTab(
          onOpenSearch: () => setState(() => _tabIndex = 1),
        );
    }
  }
}

class _HomeCatalogTab extends StatefulWidget {
  const _HomeCatalogTab({required this.onOpenSearch});

  final VoidCallback onOpenSearch;

  @override
  State<_HomeCatalogTab> createState() => _HomeCatalogTabState();
}

class _HomeCatalogTabState extends State<_HomeCatalogTab> {
  String _activeCategory = 'Пляжный отдых';
  List<Tour> _tours = mockTours;
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  static const _categories = [
    'Пляжный отдых',
    'Горы',
    'Визовые туры',
    'Санатории',
    'Круизы',
  ];

  @override
  void initState() {
    super.initState();
    _loadTours();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTours() async {
    setState(() => _isLoading = true);
    try {
      final tours = await ApiService.getTours(
        category: _activeCategory,
        search: _searchController.text,
      );
      if (mounted) {
        setState(() {
          _tours = tours;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onCategorySelected(String category) {
    if (_activeCategory == category) return;
    setState(() => _activeCategory = category);
    _loadTours();
  }

  Future<void> _openCreateTour() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateTourScreen()),
    );
    if (created == true && mounted) {
      // Показываем все туры, чтобы новый точно попал в список
      setState(() {
        _activeCategory = 'Все';
        _searchController.clear();
      });
      _loadTours();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateTour,
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Тур', style: AppText.sora(size: 14, color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTours,
        color: AppColors.teal,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          children: [
            _TopBar(),
            const SizedBox(height: 16),
            _SearchBar(
              controller: _searchController,
              onChanged: (val) {
                _loadTours();
              },
              onSubmitted: (_) => _loadTours(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final label = _categories[i];
                  return CategoryChip(
                    label: label,
                    active: label == _activeCategory,
                    onTap: () => _onCategorySelected(label),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const _PromoBanner(),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(LocaleService.tr('popular_tours'), style: AppText.h3),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _activeCategory = 'Все';
                      _searchController.clear();
                    });
                    _loadTours();
                  },
                  child: Text(
                    LocaleService.tr('all_tours'),
                    style: AppText.work(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: AppColors.teal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.teal)),
              )
            else if (_tours.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 48, color: AppColors.mutedLight),
                      const SizedBox(height: 10),
                      Text(
                        'Туров по этой категории не найдено',
                        style: AppText.work(size: 14, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final tour in _tours)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TourCard(
                    tour: tour,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TourDetailScreen(tour: tour),
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ApiService.userNotifier,
      builder: (context, user, _) {
        final displayName = user?.fullName.isNotEmpty == true ? user!.fullName.split(' ').first : 'Асем';
        final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'А';

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.teal,
                  child: Text(
                    initial,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${LocaleService.tr('hello')}, $displayName', style: AppText.work(size: 13, color: AppColors.muted)),
                    Text(LocaleService.tr('where_to_fly'), style: AppText.h4.copyWith(fontSize: 16)),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                IconCircleButton(
                  svg: AppIcons.heart,
                  background: Colors.white,
                  border: AppColors.border,
                  iconColor: const Color(0xFFE53935),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconCircleButton(
                  svg: AppIcons.bell,
                  background: Colors.white,
                  border: AppColors.border,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Новых уведомлений нет')),
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.4),
      ),
      child: Row(
        children: [
          const AppIcon(AppIcons.search, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: LocaleService.tr('search_hint'),
                hintStyle: AppText.work(size: 14.5, color: AppColors.mutedLight),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: AppText.work(size: 14.5, color: AppColors.ink),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: const Icon(Icons.close, size: 18, color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.teal, AppColors.tealDark],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'СКИДКА ДО 15%',
                style: AppText.work(size: 12, weight: FontWeight.w600, color: const Color(0xFFBFEAE4)),
              ),
              const SizedBox(height: 4),
              Text(
                'Турция и ОАЭ\nэтой осенью',
                style: AppText.sora(size: 17, color: Colors.white),
              ),
            ],
          ),
          const Icon(Icons.flight_takeoff_rounded, color: Color(0xFFFF9A85), size: 40),
        ],
      ),
    );
  }
}

class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  List<(String, String)> _getTabs() => [
    (AppIcons.home, LocaleService.tr('nav_home')),
    (AppIcons.searchTab, LocaleService.tr('nav_search')),
    (AppIcons.ticket, LocaleService.tr('nav_bookings')),
    (AppIcons.user, LocaleService.tr('nav_profile')),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleService.localeNotifier,
      builder: (context, _, __) {
        final tabs = _getTabs();
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < tabs.length; i++)
                GestureDetector(
                  onTap: () => onChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        tabs[i].$1,
                        size: 20,
                        color: i == index ? AppColors.teal : AppColors.mutedLight,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tabs[i].$2,
                        style: AppText.work(
                          size: 11,
                          weight: i == index ? FontWeight.w600 : FontWeight.w400,
                          color: i == index ? AppColors.teal : AppColors.mutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
