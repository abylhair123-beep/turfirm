import 'dart:async';

import 'package:flutter/material.dart';
import '../models/tour.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/tour_card.dart';
import 'tour_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _selectedCity = 'Любой';
  int? _maxPrice;
  int _adults = 2;
  int _children = 0;
  final Set<String> _amenities = {};
  int _starRating = 0; // 0 = любые звёзды
  List<AmenityOption> _amenityOptionsLoaded = [];
  List<Tour> _tours = [];
  bool _isLoading = false;

  // Подсказки
  Timer? _debounce;
  List<SearchSuggestion> _suggestions = [];
  List<String> _recent = [];
  List<SearchSuggestion> _popular = [];
  bool _suggestLoading = false;

  static const _cities = ['Любой', 'Алматы', 'Астана', 'Шымкент'];
  static const _priceFilters = [
    (null, 'Любая цена'),
    (250000, 'до 250 тыс ₸'),
    (400000, 'до 400 тыс ₸'),
    (600000, 'до 600 тыс ₸'),
  ];

  // Теги удобств для фильтра: (тег на бэке, подпись)
  static const _amenityOptions = [
    ('all_inclusive', 'Всё включено'),
    ('beach_first_line', 'Первая линия'),
    ('pool', 'Бассейн'),
    ('kids_club', 'Детский клуб'),
    ('spa', 'СПА'),
    ('wifi', 'Wi-Fi'),
    ('city_center', 'Центр города'),
  ];

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
    _loadRecentAndPopular();
    _loadFilterOptions();
    _search();
  }

  Future<void> _loadFilterOptions() async {
    final opts = await ApiService.getFilterOptions();
    if (mounted && opts.amenities.isNotEmpty) {
      setState(() {
        _amenityOptionsLoaded = opts.amenities;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecentAndPopular() async {
    final recent = await ApiService.getRecentSearches();
    final popular = await ApiService.getPopularSearches();
    if (mounted) {
      setState(() {
        _recent = recent;
        _popular = popular;
      });
    }
  }

  // Показывать ли панель подсказок (строка в фокусе).
  bool get _showSuggestions => _searchFocus.hasFocus;

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      _search();
      return;
    }
    setState(() => _suggestLoading = true);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final items = await ApiService.getSuggestions(q);
      if (mounted) {
        setState(() {
          _suggestions = items;
          _suggestLoading = false;
        });
      }
    });
  }

  Future<void> _applyQuery(String query) async {
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    _searchFocus.unfocus();
    await ApiService.addRecentSearch(query);
    _recent = await ApiService.getRecentSearches();
    _search();
  }

  Future<void> _search() async {
    setState(() => _isLoading = true);
    final results = await ApiService.getTours(
      search: _searchController.text,
      departureCity: _selectedCity != 'Любой' ? _selectedCity : null,
      maxPrice: _maxPrice,
      guests: _adults + _children,
      children: _children,
      amenities: _amenities.toList(),
      stars: _starRating > 0 ? [_starRating] : null,
    );
    if (mounted) {
      setState(() {
        _tours = results;
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
        title: Text('Поиск и фильтры', style: AppText.h3.copyWith(fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Поисковая строка + кнопка фильтров
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _searchFocus.hasFocus ? AppColors.teal : AppColors.border,
                              width: _searchFocus.hasFocus ? 1.6 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocus,
                                  textInputAction: TextInputAction.search,
                                  onChanged: _onQueryChanged,
                                  onSubmitted: (val) {
                                    if (val.trim().isNotEmpty) {
                                      _applyQuery(val.trim());
                                    } else {
                                      _searchFocus.unfocus();
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Страна, город, отель или турагентство...',
                                    hintStyle: AppText.work(size: 13.5, color: AppColors.mutedLight),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  style: AppText.work(size: 14, color: AppColors.ink),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _suggestions = []);
                                    _search();
                                  },
                                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildFilterButton(),
                    ],
                  ),
                ],
              ),
            ),
            if (_showSuggestions)
              Expanded(child: _buildSuggestionsPanel())
            else ...[
              const Divider(color: AppColors.border, height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
                    : _tours.isEmpty
                        ? Center(
                            child: Text(
                              'По вашему запросу ничего не найдено',
                              style: AppText.work(size: 14, color: AppColors.muted),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: _tours.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final tour = _tours[index];
                              return TourCard(
                                tour: tour,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => TourDetailScreen(tour: tour)),
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _guestStepper(String label, int value, int min, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.work(size: 12.5, weight: FontWeight.w600, color: AppColors.ink),
            ),
          ),
          Row(
            children: [
              _stepBtn(Icons.remove, value > min, () => onChanged(value - 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('$value', style: AppText.work(size: 14, weight: FontWeight.w700)),
              ),
              _stepBtn(Icons.add, value < 10, () => onChanged(value + 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: enabled ? AppColors.teal.withValues(alpha: 0.1) : AppColors.bg,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 16, color: enabled ? AppColors.teal : AppColors.mutedLight),
      ),
    );
  }

  int get _activeFilterCount {
    var c = 0;
    if (_selectedCity != 'Любой') c++;
    if (_maxPrice != null) c++;
    if (_adults != 2 || _children != 0) c++;
    c += _amenities.length;
    if (_starRating > 0) c++;
    return c;
  }

  Widget _buildFilterButton() {
    final count = _activeFilterCount;
    return GestureDetector(
      onTap: _openFilters,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: count > 0 ? AppColors.teal : AppColors.border,
            width: count > 0 ? 1.6 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.tune_rounded, color: AppColors.teal, size: 22),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: AppColors.coral, shape: BoxShape.circle),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: AppText.work(size: 10, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openFilters() {
    // Временные копии — применяем только по кнопке «Готово»
    String city = _selectedCity;
    int? maxPrice = _maxPrice;
    int adults = _adults;
    int children = _children;
    final amenities = Set<String>.from(_amenities);
    int starRating = _starRating;

    // Список удобств берём из каталога (что задали агентства), иначе — запасной статичный
    final amenityChoices = _amenityOptionsLoaded.isNotEmpty
        ? _amenityOptionsLoaded.map((a) => (a.tag, a.label)).toList()
        : _amenityOptions.toList();

    _searchFocus.unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        Widget sectionTitle(String t) => Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(t, style: AppText.work(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
            );

        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Фильтры', style: AppText.h3.copyWith(fontSize: 18)),
                        TextButton(
                          onPressed: () => setSheet(() {
                            city = 'Любой';
                            maxPrice = null;
                            adults = 2;
                            children = 0;
                            amenities.clear();
                            starRating = 0;
                          }),
                          child: Text('Сбросить', style: AppText.work(size: 13, color: AppColors.muted)),
                        ),
                      ],
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sectionTitle('Город вылета'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final c in _cities)
                                  ChoiceChip(
                                    label: Text(c),
                                    selected: city == c,
                                    onSelected: (v) => setSheet(() => city = c),
                                    selectedColor: AppColors.teal,
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: AppColors.border),
                                    labelStyle: TextStyle(
                                      color: city == c ? Colors.white : AppColors.ink,
                                      fontWeight: city == c ? FontWeight.w600 : FontWeight.w400,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            sectionTitle('Бюджет'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final item in _priceFilters)
                                  ChoiceChip(
                                    label: Text(item.$2),
                                    selected: maxPrice == item.$1,
                                    onSelected: (v) => setSheet(() => maxPrice = item.$1),
                                    selectedColor: AppColors.teal,
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: AppColors.border),
                                    labelStyle: TextStyle(
                                      color: maxPrice == item.$1 ? Colors.white : AppColors.ink,
                                      fontWeight: maxPrice == item.$1 ? FontWeight.w600 : FontWeight.w400,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            sectionTitle('Гости'),
                            Row(
                              children: [
                                Expanded(
                                  child: _guestStepper('Взрослые', adults, 1, (v) => setSheet(() => adults = v)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _guestStepper('Дети', children, 0, (v) => setSheet(() => children = v)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            sectionTitle('Звёзды отеля'),
                            Row(
                              children: [
                                for (var i = 1; i <= 5; i++)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => setSheet(() => starRating = (starRating == i) ? 0 : i),
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Icon(
                                        Icons.star_rounded,
                                        size: 36,
                                        color: i <= starRating ? const Color(0xFFFFC107) : AppColors.border,
                                      ),
                                    ),
                                  ),
                                if (starRating > 0) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '$starRating★',
                                    style: AppText.work(size: 13, weight: FontWeight.w700, color: AppColors.ink),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 14),
                            sectionTitle('Удобства'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final (tag, label) in amenityChoices)
                                  FilterChip(
                                    label: Text(label),
                                    selected: amenities.contains(tag),
                                    onSelected: (sel) => setSheet(() {
                                      if (sel) {
                                        amenities.add(tag);
                                      } else {
                                        amenities.remove(tag);
                                      }
                                    }),
                                    backgroundColor: Colors.white,
                                    selectedColor: AppColors.teal,
                                    checkmarkColor: Colors.white,
                                    side: const BorderSide(color: AppColors.border),
                                    labelStyle: TextStyle(
                                      color: amenities.contains(tag) ? Colors.white : AppColors.ink,
                                      fontWeight: amenities.contains(tag) ? FontWeight.w600 : FontWeight.w400,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedCity = city;
                            _maxPrice = maxPrice;
                            _adults = adults;
                            _children = children;
                            _amenities
                              ..clear()
                              ..addAll(amenities);
                            _starRating = starRating;
                          });
                          Navigator.pop(ctx);
                          _search();
                        },
                        child: Text('Готово', style: AppText.work(size: 15, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSuggestionsPanel() {
    final query = _searchController.text.trim();

    // Пустая строка — показываем недавние и популярные запросы.
    if (query.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          if (_recent.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Недавние', style: AppText.work(size: 12, weight: FontWeight.w600, color: AppColors.muted)),
                GestureDetector(
                  onTap: () async {
                    await ApiService.clearRecentSearches();
                    setState(() => _recent = []);
                  },
                  child: Text('Очистить', style: AppText.work(size: 12, color: AppColors.teal)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final r in _recent)
              _SuggestionTile(
                icon: Icons.history_rounded,
                text: r,
                onTap: () => _applyQuery(r),
              ),
            const SizedBox(height: 12),
          ],
          if (_popular.isNotEmpty) ...[
            Text('Популярные направления', style: AppText.work(size: 12, weight: FontWeight.w600, color: AppColors.muted)),
            const SizedBox(height: 4),
            for (final p in _popular)
              _SuggestionTile(
                icon: Icons.trending_up_rounded,
                text: p.text,
                onTap: () => _applyQuery(p.text),
              ),
          ],
          if (_recent.isEmpty && _popular.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  'Начните вводить — покажем подсказки',
                  style: AppText.work(size: 13, color: AppColors.mutedLight),
                ),
              ),
            ),
        ],
      );
    }

    // Есть текст — живые подсказки.
    if (_suggestLoading && _suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.teal)),
      );
    }
    if (_suggestions.isEmpty) {
      return Center(
        child: Text(
          'Ничего не найдено по «$query»',
          style: AppText.work(size: 13, color: AppColors.mutedLight),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: _suggestions.length,
      itemBuilder: (context, i) {
        final s = _suggestions[i];
        return _SuggestionTile(
          icon: _iconForType(s.type),
          text: s.text,
          subtitle: s.subtitle,
          badge: _labelForType(s.type),
          onTap: () => _applyQuery(s.text),
        );
      },
    );
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'tour':
        return Icons.card_travel_rounded;
      case 'agency':
        return Icons.apartment_rounded;
      case 'category':
        return Icons.category_rounded;
      case 'destination':
      default:
        return Icons.place_outlined;
    }
  }

  static String? _labelForType(String type) {
    switch (type) {
      case 'tour':
        return 'Тур';
      case 'agency':
        return 'Агентство';
      case 'category':
        return 'Категория';
      case 'destination':
        return 'Направление';
      default:
        return null;
    }
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.text,
    this.subtitle,
    this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final String? subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.work(size: 14.5, color: AppColors.ink),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.work(size: 12, color: AppColors.mutedLight),
                    ),
                ],
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: AppText.work(size: 10.5, weight: FontWeight.w600, color: AppColors.teal),
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.north_west_rounded, size: 15, color: AppColors.mutedLight),
          ],
        ),
      ),
    );
  }
}
