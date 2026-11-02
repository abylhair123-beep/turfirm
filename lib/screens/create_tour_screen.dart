import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/primary_button.dart';

/// Экран создания тура для турагентства.
///
/// Полный путь: вход агентства → выбор фото → загрузка файла на бэкенд →
/// создание тура с полученным photoUrl. После успеха возвращает true, чтобы
/// каталог обновился и показал новый тур с фото.
class CreateTourScreen extends StatefulWidget {
  const CreateTourScreen({super.key});

  @override
  State<CreateTourScreen> createState() => _CreateTourScreenState();
}

class _CreateTourScreenState extends State<CreateTourScreen> {
  final _formKey = GlobalKey<FormState>();

  // Данные агентства (предзаполнены демо-агентством из сидов)
  final _emailCtrl = TextEditingController(text: 'turan@sapar.kz');
  final _passwordCtrl = TextEditingController(text: 'Agency123!');

  // Поля тура
  final _titleCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _nightsCtrl = TextEditingController(text: '7 ночей');
  final _datesCtrl = TextEditingController(text: 'вылет 15 нояб');
  final _mealCtrl = TextEditingController(text: 'завтраки');
  final _priceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String _category = 'Пляжный отдых';
  static const _categories = [
    'Пляжный отдых',
    'Горы',
    'Визовые туры',
    'Санатории',
    'Круизы',
  ];

  Uint8List? _photoBytes;
  String? _photoName;
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in [
      _emailCtrl,
      _passwordCtrl,
      _titleCtrl,
      _destinationCtrl,
      _nightsCtrl,
      _datesCtrl,
      _mealCtrl,
      _priceCtrl,
      _descriptionCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _photoBytes = bytes;
        _photoName = picked.name;
      });
    } catch (e) {
      _showSnack('Не удалось выбрать фото: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photoBytes == null) {
      _showSnack('Добавьте фото тура');
      return;
    }

    setState(() => _submitting = true);
    try {
      // 1. Вход агентства -> токен
      final user = await ApiService.login(_emailCtrl.text.trim(), _passwordCtrl.text);
      final token = ApiService.token;
      if (user == null || token == null) {
        _showSnack('Не удалось войти. Проверьте email и пароль агентства.');
        return;
      }

      // 2. Загрузка фото -> URL
      final photoUrl = await ApiService.uploadImage(
        bytes: _photoBytes!,
        filename: _photoName ?? 'photo.jpg',
        token: token,
        folder: 'tours',
      );
      if (photoUrl == null) {
        _showSnack('Не удалось загрузить фото.');
        return;
      }

      // 3. Создание тура
      final tour = await ApiService.createTour(
        token: token,
        data: {
          'title': _titleCtrl.text.trim(),
          'destination': _destinationCtrl.text.trim(),
          'category': _category,
          'nights': _nightsCtrl.text.trim(),
          'dates': _datesCtrl.text.trim(),
          'meal': _mealCtrl.text.trim(),
          'departureCity': 'Алматы',
          'priceFrom': int.tryParse(_priceCtrl.text.trim()) ?? 0,
          'photoUrl': photoUrl,
          'description': _descriptionCtrl.text.trim(),
          'included': <String>[],
        },
      );

      if (tour == null) {
        _showSnack('Не удалось создать тур.');
        return;
      }

      if (mounted) {
        _showSnack('Тур «${tour.title}» создан!');
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Создать тур', style: AppText.h4),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Фото
              _photoPicker(),
              const SizedBox(height: 20),

              _label('Название тура'),
              _field(_titleCtrl, hint: 'Турция, Анталия 5*'),
              _label('Направление'),
              _field(_destinationCtrl, hint: 'Анталия, Турция'),
              _label('Категория'),
              _categoryDropdown(),
              _label('Ночей'),
              _field(_nightsCtrl, hint: '7 ночей'),
              _label('Даты'),
              _field(_datesCtrl, hint: 'вылет 15 нояб'),
              _label('Питание'),
              _field(_mealCtrl, hint: 'всё включено'),
              _label('Цена от, ₸'),
              _field(_priceCtrl, hint: '350000', keyboard: TextInputType.number),
              _label('Описание'),
              _field(_descriptionCtrl, hint: 'Коротко о туре…', maxLines: 3),

              const SizedBox(height: 20),
              _agencySection(),
              const SizedBox(height: 24),

              _submitting
                  ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
                  : PrimaryButton(
                      label: 'Опубликовать тур',
                      variant: ButtonVariant.teal,
                      onPressed: _submit,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPicker() {
    return GestureDetector(
      onTap: _submitting ? null : _pickPhoto,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.4),
        ),
        clipBehavior: Clip.antiAlias,
        child: _photoBytes != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_photoBytes!, fit: BoxFit.cover),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Изменить фото',
                        style: AppText.work(size: 12, weight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.teal),
                  const SizedBox(height: 8),
                  Text('Добавить фото тура', style: AppText.work(size: 14, color: AppColors.muted)),
                ],
              ),
      ),
    );
  }

  Widget _agencySection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Данные агентства', style: AppText.work(size: 13, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Для публикации нужен вход агентства (демо уже заполнено).',
            style: AppText.caption,
          ),
          const SizedBox(height: 10),
          _field(_emailCtrl, hint: 'email агентства', keyboard: TextInputType.emailAddress),
          const SizedBox(height: 8),
          _field(_passwordCtrl, hint: 'пароль', obscure: true),
        ],
      ),
    );
  }

  Widget _categoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _category,
          isExpanded: true,
          items: _categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c, style: AppText.work(size: 14.5))))
              .toList(),
          onChanged: _submitting ? null : (v) => setState(() => _category = v ?? _category),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 0, 6),
        child: Text(text, style: AppText.work(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
      );

  Widget _field(
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboard,
    bool obscure = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      maxLines: maxLines,
      style: AppText.work(size: 14.5, color: AppColors.ink),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Заполните поле' : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.work(size: 14, color: AppColors.mutedLight),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.coral, width: 1.4),
        ),
      ),
    );
  }
}
