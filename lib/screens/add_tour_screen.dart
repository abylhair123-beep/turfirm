import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/primary_button.dart';

class AddTourScreen extends StatefulWidget {
  const AddTourScreen({super.key});

  @override
  State<AddTourScreen> createState() => _AddTourScreenState();
}

class _AddTourScreenState extends State<AddTourScreen> {
  final _titleController = TextEditingController();
  final _destinationController = TextEditingController();
  final _nightsController = TextEditingController(text: '7 ночей');
  final _datesController = TextEditingController(text: '15–22 ноя');
  final _priceController = TextEditingController(text: '280000');
  final _photoUrlController = TextEditingController();
  final _descController = TextEditingController();

  String _category = 'Пляжный отдых';
  String _departureCity = 'Алматы';
  String _meal = 'Всё вкл.';
  bool _isLoading = false;

  static const _categories = ['Пляжный отдых', 'Горы', 'Визовые туры', 'Санатории', 'Круизы'];
  static const _cities = ['Алматы', 'Астана', 'Шымкент'];
  static const _meals = ['Всё вкл.', 'Завтраки', 'Ультра всё вкл.', 'Без питания'];

  @override
  void dispose() {
    _titleController.dispose();
    _destinationController.dispose();
    _nightsController.dispose();
    _datesController.dispose();
    _priceController.dispose();
    _photoUrlController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitTour() async {
    if (_titleController.text.trim().isEmpty || _destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните название тура и направление')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final price = int.tryParse(_priceController.text.replaceAll(' ', '')) ?? 250000;
    final success = await ApiService.createTour({
      'title': _titleController.text.trim(),
      'destination': _destinationController.text.trim(),
      'category': _category,
      'nights': _nightsController.text.trim(),
      'dates': _datesController.text.trim(),
      'meal': _meal,
      'departureCity': _departureCity,
      'meta': '${_nightsController.text.trim()} · вылет ${_datesController.text.trim()}',
      'priceFrom': price,
      'photoColor': '0xFF0E7C77',
      'photoUrl': _photoUrlController.text.trim().isNotEmpty ? _photoUrlController.text.trim() : null,
      'description': _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : 'Отличный тур от проверенного турагентства на платформе Sapar.',
      'included': [
        'Авиаперелет туда–обратно',
        'Проживание в отеле',
        'Питание $_meal',
        'Медицинская страховка',
      ],
    });

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Тур успешно опубликован в каталоге Sapar!')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Добавить новый тур', style: AppText.h3.copyWith(fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            _field('Название тура', _titleController, 'Тур в Анталию 5*'),
            const SizedBox(height: 12),
            _field('Направление (курорт / страна)', _destinationController, 'Анталия, Турция'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _dropdown('Категория', _category, _categories, (val) => setState(() => _category = val!)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dropdown('Вылет из', _departureCity, _cities, (val) => setState(() => _departureCity = val!)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field('Длительность', _nightsController, '7 ночей'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field('Даты', _datesController, '15–22 ноя'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _dropdown('Питание', _meal, _meals, (val) => setState(() => _meal = val!)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field('Цена от (₸)', _priceController, '280000', keyboardType: TextInputType.number),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field('Ссылка на фото (URL)', _photoUrlController, 'https://images.unsplash.com/...'),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Описание тура', style: AppText.work(size: 13, weight: FontWeight.w500)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _descController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Опишите отель, пляж, программу тура и преимущества...',
                      hintStyle: AppText.work(size: 13.5, color: AppColors.mutedLight),
                      border: InputBorder.none,
                    ),
                    style: AppText.work(size: 14, color: AppColors.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              title: 'Опубликовать тур',
              isLoading: _isLoading,
              onTap: _submitTour,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint, {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.work(size: 13, weight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppText.work(size: 13.5, color: AppColors.mutedLight),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            style: AppText.work(size: 14, color: AppColors.ink),
          ),
        ),
      ],
    );
  }

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.work(size: 13, weight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: AppText.work(size: 13.5)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
