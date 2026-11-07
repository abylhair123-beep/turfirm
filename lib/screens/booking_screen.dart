import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../models/tour.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/icon_circle_button.dart';
import '../widgets/kaspi_qr_sheet.dart';
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
  final TextEditingController _promoController = TextEditingController();
  PromoResult? _promo;
  bool _promoChecking = false;

  late final TextEditingController _referralController;
  String? _appliedReferralCode;
  String? _referralBloggerName;
  double _referralDiscountPercent = 0.0;
  bool _isCheckingReferral = false;

  static const _paymentMethods = ['Kaspi Pay', 'Карта', 'Halyk Bank'];
  static const _serviceFee = 9800;

  int get _tourTotal => widget.tour.priceFrom * _guests;
  int get _total => _tourTotal + _serviceFee; // полная сумма без скидок (для отображения)
  // Скидки считаем по проценту от стоимости тура (без сервисного сбора)
  int get _referralDiscount =>
      _referralDiscountPercent > 0 ? (_tourTotal * (_referralDiscountPercent / 100.0)).round() : 0;
  int get _promoDiscount =>
      (_promo?.valid == true) ? (_tourTotal * _promo!.discountPercent / 100).round() : 0;
  int get _discount => _referralDiscount + _promoDiscount;
  int get _payable => _total - _discount;

  @override
  void initState() {
    super.initState();
    final u = ApiService.currentUser;
    _nameController = TextEditingController(text: u?.fullName.isNotEmpty == true ? u!.fullName : 'Айгерим Сериковна');
    _phoneController = TextEditingController(text: u?.phone?.isNotEmpty == true ? u!.phone! : '+7 701 234 56 78');
    _emailController = TextEditingController(text: u?.email.isNotEmpty == true ? u!.email : 'aigerim@mail.kz');
    _referralController = TextEditingController(text: ApiService.activeReferralCode ?? '');

    // Если был активный код из сессии, автоматически проверим его
    if (ApiService.activeReferralCode != null) {
      _applyReferral(ApiService.activeReferralCode!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _promoController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _applyPromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _promoChecking = true);
    final res = await ApiService.validatePromo(code, _total);
    if (mounted) {
      setState(() {
        _promo = res;
        _promoChecking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message)),
      );
    }
  }

  void _removePromo() {
    setState(() {
      _promo = null;
      _promoController.clear();
    });
  }

  Future<void> _applyReferral(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return;

    setState(() => _isCheckingReferral = true);
    final res = await ApiService.checkReferralCode(clean);
    if (!mounted) return;

    setState(() {
      _isCheckingReferral = false;
      if (res.valid) {
        _appliedReferralCode = res.code;
        _referralBloggerName = res.bloggerName;
        _referralDiscountPercent = res.discountPercent;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ ${res.message}'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      } else {
        _appliedReferralCode = null;
        _referralBloggerName = null;
        _referralDiscountPercent = 0.0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppColors.coral,
          ),
        );
      }
    });
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
      final method = _paymentMethods[_paymentIndex];
      final req = BookingRequest(
        tourId: widget.tour.id,
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        customerEmail: _emailController.text.trim(),
        guestsCount: _guests,
        paymentMethod: method,
        referralCode: _appliedReferralCode,
      );

      final result = await ApiService.createBooking(req);

      // Если выбран Kaspi Pay — показываем интерактивный QR код
      if (method == 'Kaspi Pay' && mounted) {
        final paymentData = await ApiService.initiatePayment(
          bookingId: result.id,
          paymentMethod: method,
          customerPhone: req.customerPhone,
          customerEmail: req.customerEmail,
          customerName: req.customerName,
        );

        if (paymentData != null && mounted) {
          setState(() => _isSubmitting = false);
          await KaspiQrSheet.show(
            context: context,
            payment: paymentData,
            onPaymentSuccess: () {
              NotificationService.simulateBookingConfirmed(destination: widget.tour.destination);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => SuccessScreen(
                    bookingId: result.id,
                    email: result.customerEmail.isNotEmpty ? result.customerEmail : 'aigerim@mail.kz',
                  ),
                ),
              );
            },
          );
          return;
        }
      }

      if (mounted) {
        NotificationService.simulateBookingConfirmed(destination: widget.tour.destination);
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
                          clipBehavior: Clip.antiAlias,
                          child: tour.photoUrl != null && tour.photoUrl!.isNotEmpty
                              ? Image.network(
                                  tour.photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tour.title, style: AppText.h4),
                              const SizedBox(height: 3),
                              Text('${tour.dates} · ${tour.nights}', style: AppText.caption),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Количество туристов', style: AppText.h4),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Взрослые', style: AppText.work(size: 14, weight: FontWeight.w600)),
                            Text('от 12 лет и старше', style: AppText.caption),
                          ],
                        ),
                        Row(
                          children: [
                            _counterBtn(Icons.remove, () {
                              if (_guests > 1) setState(() => _guests--);
                            }),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text('$_guests', style: AppText.h4),
                            ),
                            _counterBtn(Icons.add, () => setState(() => _guests++)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Контактные данные', style: AppText.h4),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _textField('Имя и фамилия', _nameController, Icons.person_outline),
                        const Divider(height: 20, color: AppColors.border),
                        _textField('Телефон для связи', _phoneController, Icons.phone_outlined),
                        const Divider(height: 20, color: AppColors.border),
                        _textField('Электронная почта', _emailController, Icons.email_outlined),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Способ оплаты', style: AppText.h4),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < _paymentMethods.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i < _paymentMethods.length - 1 ? 8 : 0),
                            child: GestureDetector(
                              onTap: () => setState(() => _paymentIndex = i),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _paymentIndex == i ? AppColors.teal.withValues(alpha: 0.08) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _paymentIndex == i ? AppColors.teal : AppColors.border,
                                    width: _paymentIndex == i ? 1.8 : 1,
                                  ),
                                ),
                                child: Text(
                                  _paymentMethods[i],
                                  textAlign: TextAlign.center,
                                  style: AppText.work(
                                    size: 13,
                                    weight: _paymentIndex == i ? FontWeight.w600 : FontWeight.w500,
                                    color: _paymentIndex == i ? AppColors.teal : AppColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('Промокод', style: AppText.h4),
                  const SizedBox(height: 8),
                  _buildPromoField(),
                  const SizedBox(height: 18),
                  Text('Код или ссылка блогера', style: AppText.h4),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _appliedReferralCode != null ? const Color(0xFF2E7D32) : AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _referralController,
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  hintText: 'Промокод блогера (напр. TRAVEL_KZ)',
                                  prefixIcon: const Icon(Icons.discount_outlined, color: AppColors.teal, size: 20),
                                  isDense: true,
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isCheckingReferral
                                  ? null
                                  : () => _applyReferral(_referralController.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.teal,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              child: _isCheckingReferral
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Применить', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                        if (_appliedReferralCode != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Промокод $_appliedReferralCode активен (${_referralBloggerName ?? "Блогер"}) • Скидка ${_referralDiscountPercent.toInt()}%',
                                    style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Детализация стоимости', style: AppText.h4),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _priceRow('Тур (${_fmt(tour.priceFrom)} × $_guests)', _fmt(_tourTotal)),
                        if (_referralDiscount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Скидка от блогера (${_referralDiscountPercent.toInt()}%)', style: AppText.work(size: 13, color: const Color(0xFF2E7D32), weight: FontWeight.w600)),
                              Text('- ${_fmt(_referralDiscount)}', style: AppText.work(size: 13, color: const Color(0xFF2E7D32), weight: FontWeight.w700)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        _priceRow('Сервисный сбор платформы', _fmt(_serviceFee)),
                        if (_promo?.valid == true && _promoDiscount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Промокод ${_promo!.code} (−${_promo!.discountPercent}%)',
                                  style: AppText.work(size: 13, color: const Color(0xFF2E7D32))),
                              Text('−${_fmt(_promoDiscount)}',
                                  style: AppText.work(size: 13.5, weight: FontWeight.w600, color: const Color(0xFF2E7D32))),
                            ],
                          ),
                        ],
                        const Divider(height: 20, color: AppColors.border),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Итого к оплате', style: AppText.h4),
                            Text(
                              _fmt(_payable),
                              style: AppText.sora(size: 18, weight: FontWeight.w700, color: AppColors.teal),
                            ),
                          ],
                        ),
                        if (tour.installmentMonths > 0 && tour.monthlyFormatted != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC107),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF5A4300)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Рассрочка 0-0-${tour.installmentMonths}: ${tour.monthlyFormatted} × ${tour.installmentMonths} мес',
                                    style: AppText.work(size: 12.5, weight: FontWeight.w700, color: const Color(0xFF5A4300)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: PrimaryButton(
                title: _isSubmitting
                    ? 'Оформление...'
                    : _paymentMethods[_paymentIndex] == 'Kaspi Pay'
                        ? 'Оплатить через Kaspi Pay (${_fmt(_payable)})'
                        : 'Оплатить ${_fmt(_payable)}',
                isLoading: _isSubmitting,
                onTap: _handlePayment,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoField() {
    final applied = _promo?.valid == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: applied ? const Color(0xFF2E7D32) : AppColors.border,
          width: applied ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            applied ? Icons.check_circle_rounded : Icons.local_offer_outlined,
            size: 18,
            color: applied ? const Color(0xFF2E7D32) : AppColors.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _promoController,
              enabled: !applied,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _applyPromo(),
              decoration: InputDecoration(
                hintText: 'Введите промокод (напр. SAPAR10)',
                hintStyle: AppText.work(size: 13.5, color: AppColors.mutedLight),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: AppText.work(size: 14, color: AppColors.ink),
            ),
          ),
          if (applied)
            GestureDetector(
              onTap: _removePromo,
              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
            )
          else
            GestureDetector(
              onTap: _promoChecking ? null : _applyPromo,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: _promoChecking
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal),
                      )
                    : Text('Применить',
                        style: AppText.work(size: 13.5, weight: FontWeight.w700, color: AppColors.teal)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppColors.ink),
      ),
    );
  }

  Widget _textField(String hint, TextEditingController ctrl, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppText.work(size: 13.5, color: AppColors.mutedLight),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: AppText.work(size: 14, color: AppColors.ink),
          ),
        ),
      ],
    );
  }

  Widget _priceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.work(size: 13, color: AppColors.muted)),
        Text(value, style: AppText.work(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
      ],
    );
  }
}
