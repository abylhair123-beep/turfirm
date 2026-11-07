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

  // Состояния фильтрации
  String _selectedCity = 'Любой';
  int? _selectedStars;
  String? _selectedMeal;
  int? _selectedBeach;
  int? _minDuration;
  int? _maxDuration;
  int? _maxPrice;
  double? _minRating;
  int _adultsCount = 2;
  String _selectedDates = 'Любые';

  List<Tour> _tours = [];
  bool _isLoading = false;

  static const _cities = ['Любой', 'Алматы', 'Астана', 'Шымкент', 'Актау'];

  static const _starsOptions = [
    (null, 'Любые'),
    (3, '3★+'),
    (4, '4★+'),
    (5, '5★ Deluxe'),
  ];

  static const _mealOptions = [
    (null, 'Любое'),
    ('AI', 'Всё включено (AI)'),
    ('UAI', 'Ультра всё (UAI)'),
    ('BB', 'Завтраки (BB)'),
    ('HB', 'Завтрак + ужин (HB)'),
    ('RO', 'Без питания (RO)'),
  ];

  static const _beachOptions = [
    (null, 'Любая'),
    (1, '🏖️ 1-я линия (у моря)'),
    (2, '2-я линия'),
    (3, '3-я линия'),
  ];

  static const _durationOptions = [
    (null, null, 'Любая'),
    (3, 5, '3–5 ночей'),
    (7, 7, '7 ночей'),
    (8, 10, '8–10 ночей'),
    (11, 14, '11–14 ночей'),
  ];

  static const _priceFilters = [
    (null, 'Любой бюджет'),
    (250000, 'до 250 тыс ₸'),
    (400000, 'до 400 тыс ₸'),
    (600000, 'до 600 тыс ₸'),
    (1000000, 'до 1 млн ₸'),
  ];

  static const _ratingOptions = [
    (null, 'Любой'),
    (4.0, '4.0+ ★'),
    (4.5, '4.5+ ★'),
    (4.8, '4.8+ ★ Топ'),
  ];

  int get _activeFiltersCount {
    var count = 0;
    if (_selectedCity != 'Любой') count++;
    if (_selectedStars != null) count++;
    if (_selectedMeal != null) count++;
    if (_selectedBeach != null) count++;
    if (_minDuration != null || _maxDuration != null) count++;
    if (_maxPrice != null) count++;
    if (_minRating != null) count++;
    if (_adultsCount != 2) count++;
    if (_selectedDates != 'Любые') count++;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _selectedCity = 'Любой';
      _selectedStars = null;
      _selectedMeal = null;
      _selectedBeach = null;
      _minDuration = null;
      _maxDuration = null;
      _maxPrice = null;
      _minRating = null;
      _adultsCount = 2;
      _selectedDates = 'Любые';
    });
    _search();
  }

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _isLoading = true);
    final results = await ApiService.getTours(
      search: _searchController.text,
      departureCity: _selectedCity != 'Любой' ? _selectedCity : null,
      maxPrice: _maxPrice,
      hotelStars: _selectedStars,
      mealType: _selectedMeal,
      beachLine: _selectedBeach,
      minDuration: _minDuration,
      maxDuration: _maxDuration,
      minRating: _minRating,
    );
    if (mounted) {
      setState(() {
        _tours = results;
        _isLoading = false;
      });
    }
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Шапка модалки
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune_rounded, color: AppColors.teal, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Фильтры туров',
                              style: AppText.sora(size: 18, weight: FontWeight.w700),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (_activeFiltersCount > 0)
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    _resetFilters();
                                  });
                                },
                                child: const Text(
                                  'Сбросить все',
                                  style: TextStyle(color: Color(0xFFE53935), fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),

                  // Список секций фильтрации
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      children: [
                        // ⭐ Звёзды отеля
                        _sectionTitle('⭐ Звёзды отеля'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _starsOptions.map((opt) {
                            final isSel = _selectedStars == opt.$1;
                            return ChoiceChip(
                              label: Text(opt.$2),
                              selected: isSel,
                              selectedColor: AppColors.teal,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppColors.ink,
                                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                              ),
                              onSelected: (val) {
                                setModalState(() => _selectedStars = val ? opt.$1 : null);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 🍽️ Питание
                        _sectionTitle('🍽️ Тип питания'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _mealOptions.map((opt) {
                            final isSel = _selectedMeal == opt.$1;
                            return ChoiceChip(
                              label: Text(opt.$2),
                              selected: isSel,
                              selectedColor: AppColors.teal,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppColors.ink,
                                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                              ),
                              onSelected: (val) {
                                setModalState(() => _selectedMeal = val ? opt.$1 : null);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 🏖️ Линия пляжа
                        _sectionTitle('🏖️ Линия пляжа'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _beachOptions.map((opt) {
                            final isSel = _selectedBeach == opt.$1;
                            return ChoiceChip(
                              label: Text(opt.$2),
                              selected: isSel,
                              selectedColor: AppColors.teal,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppColors.ink,
                                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                              ),
                              onSelected: (val) {
                                setModalState(() => _selectedBeach = val ? opt.$1 : null);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 🌙 Длительность поездки
                        _sectionTitle('🌙 Длительность (ночи)'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _durationOptions.map((opt) {
                            final isSel = _minDuration == opt.$1 && _maxDuration == opt.$2;
                            return ChoiceChip(
                              label: Text(opt.$3),
                              selected: isSel,
                              selectedColor: AppColors.teal,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppColors.ink,
                                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                              ),
                              onSelected: (val) {
                                setModalState(() {
                                  if (val) {
                                    _minDuration = opt.$1;
                                    _maxDuration = opt.$2;
                                  } else {
                                    _minDuration = null;
                                    _maxDuration = null;
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 💰 Бюджет
                        _sectionTitle('💰 Максимальный бюджет (на человека)'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _priceFilters.map((opt) {
                            final isSel = _maxPrice == opt.$1;
                            return ChoiceChip(
                              label: Text(opt.$2),
                              selected: isSel,
                              selectedColor: AppColors.teal,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppColors.ink,
                                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                              ),
                              onSelected: (val) {
                                setModalState(() => _maxPrice = val ? opt.$1 : null);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // ⭐ Рейтинг
                        _sectionTitle('⭐ Рейтинг тура / отеля'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _ratingOptions.map((opt) {
                            final isSel = _minRating == opt.$1;
                            return ChoiceChip(
                              label: Text(opt.$2),
                              selected: isSel,
                              selectedColor: AppColors.teal,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppColors.ink,
                                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                              ),
                              onSelected: (val) {
                                setModalState(() => _minRating = val ? opt.$1 : null);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 👥 Количество туристов
                        _sectionTitle('👥 Количество туристов'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Взрослые (12+ лет):',
                                style: AppText.work(size: 14, weight: FontWeight.w600),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: _adultsCount > 1
                                        ? () => setModalState(() => _adultsCount--)
                                        : null,
                                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.teal),
                                  ),
                                  Text(
                                    '$_adultsCount чел.',
                                    style: AppText.sora(size: 15, weight: FontWeight.w700),
                                  ),
                                  IconButton(
                                    onPressed: _adultsCount < 8
                                        ? () => setModalState(() => _adultsCount++)
                                        : null,
                                    icon: const Icon(Icons.add_circle_outline, color: AppColors.teal),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ✈️ Город вылета
                        _sectionTitle('✈️ Город вылета'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _cities.map((city) {
                            final isSel = _selectedCity == city;
                            return ChoiceChip(
                              label: Text(city),
                              selected: isSel,
                              selectedColor: AppColors.teal,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppColors.ink,
                                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                              ),
                              onSelected: (val) {
                                if (val) setModalState(() => _selectedCity = city);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),

                  // Кнопка применения
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          offset: const Offset(0, -4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.coral,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _search();
                        },
                        child: Text(
                          _activeFiltersCount > 0
                              ? 'Применить фильтры ($_activeFiltersCount)'
                              : 'Показать все туры',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: AppText.sora(size: 14, weight: FontWeight.w700, color: AppColors.ink),
      ),
    );
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
        actions: [
          if (_activeFiltersCount > 0)
            TextButton(
              onPressed: _resetFilters,
              child: const Text('Сброс', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Поисковая строка и кнопка модалки фильтров
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (_) => _search(),
                                  decoration: InputDecoration(
                                    hintText: 'Страна, курорт, отель или турагентство...',
                                    hintStyle: AppText.work(size: 13.5, color: AppColors.mutedLight),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                                  ),
                                  style: AppText.work(size: 14, color: AppColors.ink),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    _search();
                                  },
                                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Кнопка вызова расширенных фильтров
                      GestureDetector(
                        onTap: _openFilterBottomSheet,
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: _activeFiltersCount > 0 ? AppColors.teal : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _activeFiltersCount > 0 ? AppColors.teal : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 20,
                                color: _activeFiltersCount > 0 ? Colors.white : AppColors.ink,
                              ),
                              if (_activeFiltersCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.coral,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$_activeFiltersCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Быстрая горизонтальная панель фильтров
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Кнопка "Все фильтры"
                        GestureDetector(
                          onTap: _openFilterBottomSheet,
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: _activeFiltersCount > 0 ? AppColors.teal.withValues(alpha: 0.12) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _activeFiltersCount > 0 ? AppColors.teal : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.filter_list_rounded,
                                  size: 16,
                                  color: _activeFiltersCount > 0 ? AppColors.teal : AppColors.ink,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _activeFiltersCount > 0 ? 'Фильтры ($_activeFiltersCount)' : 'Все фильтры',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _activeFiltersCount > 0 ? AppColors.teal : AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Быстрый фильтр: ⭐ 4★ и 5★
                        _quickFilterChip(
                          label: '⭐ 4★+',
                          isActive: _selectedStars != null,
                          onTap: () {
                            setState(() {
                              _selectedStars = _selectedStars == 4 ? null : 4;
                            });
                            _search();
                          },
                        ),

                        // Быстрый фильтр: 🍽️ Всё включено
                        _quickFilterChip(
                          label: '🍽️ Всё включено (AI)',
                          isActive: _selectedMeal == 'AI',
                          onTap: () {
                            setState(() {
                              _selectedMeal = _selectedMeal == 'AI' ? null : 'AI';
                            });
                            _search();
                          },
                        ),

                        // Быстрый фильтр: 🏖️ 1-я линия
                        _quickFilterChip(
                          label: '🏖️ 1-я линия',
                          isActive: _selectedBeach == 1,
                          onTap: () {
                            setState(() {
                              _selectedBeach = _selectedBeach == 1 ? null : 1;
                            });
                            _search();
                          },
                        ),

                        // Быстрый фильтр: 🌙 7 ночей
                        _quickFilterChip(
                          label: '🌙 7 ночей',
                          isActive: _minDuration == 7 && _maxDuration == 7,
                          onTap: () {
                            setState(() {
                              if (_minDuration == 7 && _maxDuration == 7) {
                                _minDuration = null;
                                _maxDuration = null;
                              } else {
                                _minDuration = 7;
                                _maxDuration = 7;
                              }
                            });
                            _search();
                          },
                        ),

                        // Быстрый фильтр: 💰 до 400 тыс ₸
                        _quickFilterChip(
                          label: '💰 до 400 тыс ₸',
                          isActive: _maxPrice == 400000,
                          onTap: () {
                            setState(() {
                              _maxPrice = _maxPrice == 400000 ? null : 400000;
                            });
                            _search();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Счетчик найденных результатов
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Найдено: ${_tours.length} ${_pluralTours(_tours.length)}',
                    style: AppText.work(size: 13, weight: FontWeight.w600, color: AppColors.muted),
                  ),
                  if (_activeFiltersCount > 0)
                    GestureDetector(
                      onTap: _resetFilters,
                      child: Text(
                        'Сбросить фильтры',
                        style: AppText.work(size: 12, weight: FontWeight.w600, color: const Color(0xFFE53935)),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),

            // Список карточек
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
                  : _tours.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: AppColors.teal.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.travel_explore_rounded, size: 36, color: AppColors.teal),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'По заданным фильтрам туров не найдено',
                                style: AppText.sora(size: 15, weight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Попробуйте смягчить параметры поиска или сбросить фильтры',
                                style: AppText.work(size: 13, color: AppColors.muted),
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton(
                                onPressed: _resetFilters,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.teal),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Сбросить фильтры', style: TextStyle(color: AppColors.teal)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
        ),
      ),
    );
  }

  Widget _quickFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.teal : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.teal : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }

  String _pluralTours(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'туров';
    if (mod10 == 1) return 'тур';
    if (mod10 >= 2 && mod10 <= 4) return 'тура';
    return 'туров';
  }
}
