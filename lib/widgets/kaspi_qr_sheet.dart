import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/primary_button.dart';

class KaspiQrSheet extends StatefulWidget {
  const KaspiQrSheet({
    super.key,
    required this.payment,
    required this.onPaymentSuccess,
  });

  final PaymentResponseData payment;
  final VoidCallback onPaymentSuccess;

  static Future<void> show({
    required BuildContext context,
    required PaymentResponseData payment,
    required VoidCallback onPaymentSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => KaspiQrSheet(
        payment: payment,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  State<KaspiQrSheet> createState() => _KaspiQrSheetState();
}

class _KaspiQrSheetState extends State<KaspiQrSheet> {
  bool _isConfirming = false;

  String _fmt(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return '${b.toString()} ₸';
  }

  Future<void> _handleConfirm() async {
    setState(() => _isConfirming = true);
    try {
      await ApiService.confirmPayment(widget.payment.paymentId);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onPaymentSuccess();
      }
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrData = widget.payment.qrCodeData ??
        'https://kaspi.kz/pay?order_id=${widget.payment.bookingId}&amount=${widget.payment.amount}';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF14635),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Kaspi Pay',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Оплата тура по QR',
                style: AppText.h3.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Отсканируйте QR-код в приложении Kaspi.kz\nдля мгновенной оплаты',
            textAlign: TextAlign.center,
            style: AppText.work(size: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF14635), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF14635).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200.0,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFFF14635),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'К оплате',
            style: AppText.work(size: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            _fmt(widget.payment.amount),
            style: AppText.sora(size: 24, weight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Заказ № ${widget.payment.bookingId}',
            style: AppText.work(size: 12, color: AppColors.mutedLight),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            title: _isConfirming ? 'Проверка оплаты...' : 'Я оплатил в Kaspi',
            isLoading: _isConfirming,
            onTap: _handleConfirm,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Отменить',
              style: AppText.work(size: 14, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
