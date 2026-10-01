import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../models/tour.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/icon_circle_button.dart';
import '../widgets/primary_button.dart';
import 'success_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.tour, this.guests = 2});

  final Tour tour;
  final int guests;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late int _guests = widget.guests;
  int _paymentIndex = 0;
  bool _isSubmitting = false;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  static const _paymentMethods = ['Kaspi Pay', 'Карта', 'Halyk Bank'];
  static const _serviceFee = 9800;

  int get _tourTotal => widget.tour.priceFrom * _guests;
  int get _total => _tourTotal + _serviceFee;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Айгерим Сериковна');
    _phoneController = TextEditingController(text: '+7 701 234 56 78');
    _emailController = TextEditingController(text: 'aigerim@mail.kz');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _fmt(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return '${b.toString()} ₸';
  }

  Future<void> _handlePayment() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, укажите имя и фамилию')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final req = BookingRequest(
        tourId: widget.tour.id,
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        customerEmail: _emailController.text.trim(),
        guestsCount: _guests,
        paymentMethod: _paymentMethods[_paymentIndex],
      );

      final result = await ApiService.createBooking(req);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SuccessScreen(
              bookingId: result.id,
              email: result.customerEmail.isNotEmpty ? result.customerEmail : 'aigerim@mail.kz',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tour = widget.tour;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  IconCircleButton(
                    svg: AppIcons.back,
                    background: Colors.white,
                    border: AppColors.border,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 14),
                  Text('Оформление брони', style: AppText.h3.copyWith(fontSize: 17)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: tour.photoColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tour.destination, style: AppText.h4.copyWith(fontSize: 14.5)),
                              const SizedBox(height: 2),
                              Text(
                                '${tour.agency} · ${tour.dates}, ${tour.nights}',
                                style: AppText.work(size: 12.5, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _Label('КОЛИЧЕСТВО ГОСТЕЙ'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 1.4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Взрослые', style: AppText.work(size: 14, weight: FontWeight.w600)),
                        Row(
                          children: [
                            _StepButton(
                              icon: AppIcons.minus,
                              filled: false,
                              onTap: _guests > 1 ? () => setState(() => _guests--) : null,
                            ),
                            SizedBox(
                              width: 28,
                              child: Text('$_guests', textAlign: TextAlign.center, style: AppText.work(size: 15, weight: FontWeight.w700)),
                            ),
                            _StepButton(
                              icon: AppIcons.plus,
                              filled: true,
                              onTap: () => setState(() => _guests++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _Label('КОНТАКТНЫЕ ДАННЫЕ'),
                  const SizedBox(height: 8),
                  _EditableField(
                    controller: _nameController,
                    hint: 'ФИО туриста',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 10),
                  _EditableField(
                    controller: _phoneController,
                    hint: 'Телефон',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  _EditableField(
                    controller: _emailController,
                    hint: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  const _Label('СПОСОБ ОПЛАТЫ'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final (i, label) in _paymentMethods.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _PayChip(
                            label: label,
                            active: _paymentIndex == i,
                            onTap: () => setState(() => _paymentIndex = i),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _Label('К ОПЛАТЕ'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _priceRow('Тур ($_guests чел.)', _fmt(_tourTotal)),
                        _priceRow('Сервисный сбор', _fmt(_serviceFee)),
                        const Divider(height: 20, color: AppColors.border),
                        _priceRow('Итого', _fmt(_total), big: true),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: PrimaryButton(
                label: _isSubmitting ? 'Обработка платежа...' : 'Оплатить ${_fmt(_total)}',
                onPressed: _isSubmitting ? null : _handlePayment,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool big = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: big
                ? AppText.sora(size: 15, weight: FontWeight.w700)
                : AppText.work(size: 14, color: AppColors.muted),
          ),
          Text(
            value,
            style: big
                ? AppText.sora(size: 16, weight: FontWeight.w800, color: AppColors.teal)
                : AppText.work(size: 14),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: AppText.label);
}

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: AppText.work(size: 14, weight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppText.work(size: 14, color: AppColors.mutedLight),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.filled, required this.onTap});
  final String icon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: IconCircleButton(
        svg: icon,
        size: 30,
        background: filled ? AppColors.teal : Colors.white,
        iconColor: filled ? Colors.white : AppColors.ink,
        border: filled ? null : AppColors.border,
        onTap: onTap,
      ),
    );
  }
}

class _PayChip extends StatelessWidget {
  const _PayChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.teal : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: active ? null : Border.all(color: AppColors.border, width: 1.4),
          ),
          child: Column(
            children: [
              AppIcon(AppIcons.card, size: 18, color: active ? Colors.white : AppColors.ink),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppText.work(size: 12.5, weight: FontWeight.w600, color: active ? Colors.white : AppColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
