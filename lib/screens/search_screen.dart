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
  String _selectedCity = 'Любой';
  int? _maxPrice;
  List<Tour> _tours = [];
  bool _isLoading = false;

  static const _cities = ['Любой', 'Алматы', 'Астана', 'Шымкент'];
  static const _priceFilters = [
    (null, 'Любая цена'),
    (250000, 'до 250 тыс ₸'),
    (400000, 'до 400 тыс ₸'),
    (600000, 'до 600 тыс ₸'),
  ];

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
                  // Поисковая строка
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
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
                              _search();
                            },
                            child: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Выбор города вылета
                  Text('Город вылета:', style: AppText.work(size: 12, weight: FontWeight.w600, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _cities.map((city) {
                        final isSelected = _selectedCity == city;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(city),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) {
                                setState(() => _selectedCity = city);
                                _search();
                              }
                            },
                            selectedColor: AppColors.teal,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.ink,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Бюджет
                  Text('Бюджет:', style: AppText.work(size: 12, weight: FontWeight.w600, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _priceFilters.map((item) {
                        final isSelected = _maxPrice == item.$1;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(item.$2),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() => _maxPrice = item.$1);
                              _search();
                            },
                            selectedColor: AppColors.teal,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.ink,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
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
        ),
      ),
    );
  }
}
