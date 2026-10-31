import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class BookingsListScreen extends StatefulWidget {
  const BookingsListScreen({super.key});

  @override
  State<BookingsListScreen> createState() => _BookingsListScreenState();
}

class _BookingsListScreenState extends State<BookingsListScreen> {
  List<BookingResult> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getMyBookings();
      if (mounted) {
        setState(() {
          _bookings = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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

  void _showReviewDialog(String tourId) {
    double selectedRating = 5.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Оставить отзыв', style: AppText.h3.copyWith(fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final star = index + 1;
                    return IconButton(
                      icon: Icon(
                        star <= selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: const Color(0xFFF39C12),
                        size: 32,
                      ),
                      onPressed: () {
                        setDialogState(() => selectedRating = star.toDouble());
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Поделитесь впечатлениями об отеле, перелете и сервисе турагентства...',
                    hintStyle: AppText.work(size: 13, color: AppColors.mutedLight),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Отмена', style: AppText.work(color: AppColors.muted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  if (commentController.text.trim().isNotEmpty) {
                    await ApiService.addReview(
                      tourId: tourId,
                      rating: selectedRating,
                      comment: commentController.text,
                    );
                  }
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Спасибо за ваш отзыв!')),
                    );
                  }
                },
                child: const Text('Отправить', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
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
        title: Text('Мои бронирования', style: AppText.h3.copyWith(fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBookings,
          color: AppColors.teal,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
              : _bookings.isEmpty
                  ? _emptyView()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: _bookings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final b = _bookings[index];
                        return _bookingCard(b);
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
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flight_outlined, size: 40, color: AppColors.teal),
              ),
              const SizedBox(height: 16),
              Text(
                'У вас пока нет бронирований',
                style: AppText.h3.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                'Выберите подходящий тур в каталоге и оформите поездку',
                textAlign: TextAlign.center,
                style: AppText.work(size: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bookingCard(BookingResult b) {
    final isPaid = b.status.toLowerCase() == 'paid';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.teal),
                  const SizedBox(width: 6),
                  Text(
                    b.id,
                    style: AppText.sora(size: 14, weight: FontWeight.w700, color: AppColors.ink),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPaid ? 'Оплачено' : 'Ожидает оплаты',
                  style: AppText.work(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: isPaid ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            b.tourId.replaceAll('-', ' ').toUpperCase(),
            style: AppText.sora(size: 15, weight: FontWeight.w600, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.people_outline_rounded, size: 16, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                '${b.guestsCount} гостя',
                style: AppText.work(size: 13, color: AppColors.muted),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.payment_rounded, size: 16, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                b.paymentMethod,
                style: AppText.work(size: 13, color: AppColors.muted),
              ),
            ],
          ),
          const Divider(height: 22, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Итоговая сумма', style: AppText.work(size: 11.5, color: AppColors.mutedLight)),
                  Text(
                    _fmt(b.totalPrice),
                    style: AppText.sora(size: 16, weight: FontWeight.w700, color: AppColors.teal),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => _showReviewDialog(b.tourId),
                icon: const Icon(Icons.star_outline_rounded, size: 16, color: AppColors.teal),
                label: const Text('Оставить отзыв', style: TextStyle(color: AppColors.teal, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.teal),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
