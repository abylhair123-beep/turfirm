import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'legal_docs_screen.dart';

class SavedCardItem {
  SavedCardItem({
    required this.id,
    required this.brand,
    required this.cardNumber,
    required this.cardHolder,
    required this.expiryDate,
    this.isDefault = false,
  });

  final String id;
  final String brand; // 'Kaspi', 'Visa', 'Mastercard', 'Halyk'
  final String cardNumber; // '•••• 4589'
  final String cardHolder;
  final String expiryDate; // '09/27'
  bool isDefault;

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'cardNumber': cardNumber,
        'cardHolder': cardHolder,
        'expiryDate': expiryDate,
        'isDefault': isDefault,
      };

  factory SavedCardItem.fromJson(Map<String, dynamic> json) => SavedCardItem(
        id: json['id'] as String,
        brand: json['brand'] as String,
        cardNumber: json['cardNumber'] as String,
        cardHolder: json['cardHolder'] as String? ?? 'CARD HOLDER',
        expiryDate: json['expiryDate'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
      );
}

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  String _selectedMethod = 'kaspi'; // 'kaspi', 'halyk', 'cards', 'installment'
  List<SavedCardItem> _cards = [];
  Map<String, dynamic>? _gatewayStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final method = prefs.getString('sapar_default_payment_method') ?? 'kaspi';
      final cardsJson = prefs.getString('sapar_saved_cards');
      List<SavedCardItem> loadedCards = [];
      if (cardsJson != null && cardsJson.isNotEmpty) {
        final list = jsonDecode(cardsJson) as List<dynamic>;
        loadedCards = list.map((e) => SavedCardItem.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        // Дефолтные карты
        loadedCards = [
          SavedCardItem(
            id: 'card-1',
            brand: 'Kaspi',
            cardNumber: '•••• 4589',
            cardHolder: 'SAPAR TRAVELER',
            expiryDate: '09/27',
            isDefault: true,
          ),
          SavedCardItem(
            id: 'card-2',
            brand: 'Visa',
            cardNumber: '•••• 1204',
            cardHolder: 'SAPAR TRAVELER',
            expiryDate: '04/28',
            isDefault: false,
          ),
        ];
      }
      final gatewayStatus = await ApiService.getPaymentConfigStatus();
      if (!mounted) return;
      setState(() {
        _selectedMethod = method;
        _cards = loadedCards;
        _gatewayStatus = gatewayStatus;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sapar_default_payment_method', _selectedMethod);
      final jsonStr = jsonEncode(_cards.map((c) => c.toJson()).toList());
      await prefs.setString('sapar_saved_cards', jsonStr);
    } catch (_) {}
  }

  void _setDefaultCard(String id) {
    setState(() {
      for (final card in _cards) {
        card.isDefault = (card.id == id);
      }
    });
    _saveCards();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Основная карта обновлена'),
        backgroundColor: AppColors.teal,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _deleteCard(String id) {
    setState(() {
      _cards.removeWhere((c) => c.id == id);
      if (_cards.isNotEmpty && !_cards.any((c) => c.isDefault)) {
        _cards.first.isDefault = true;
      }
    });
    _saveCards();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Карта удалена'),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showAddCardModal() {
    final numCtrl = TextEditingController();
    final expCtrl = TextEditingController();
    final cvvCtrl = TextEditingController();
    final holderCtrl = TextEditingController();
    String detectedBrand = 'Visa';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Привязать банковскую карту',
                      style: AppText.sora(size: 18, weight: FontWeight.w700, color: AppColors.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Для быстрой и безопасной оплаты туров и авиабилетов',
                      style: AppText.work(size: 12.5, color: AppColors.muted),
                    ),
                    const SizedBox(height: 18),

                    // Превью карты
                    Container(
                      width: double.infinity,
                      height: 160,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: detectedBrand == 'Kaspi'
                              ? [const Color(0xFFF14635), const Color(0xFFB91C1C)]
                              : detectedBrand == 'Mastercard'
                                  ? [const Color(0xFFEA580C), const Color(0xFFC2410C)]
                                  : [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                detectedBrand.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const Icon(Icons.contactless_rounded, color: Colors.white70, size: 24),
                            ],
                          ),
                          Text(
                            numCtrl.text.isEmpty ? '•••• •••• •••• ••••' : numCtrl.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                holderCtrl.text.isEmpty ? 'ИМЯ ВЛАДЕЛЬЦА' : holderCtrl.text.toUpperCase(),
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                expCtrl.text.isEmpty ? 'ММ/ГГ' : expCtrl.text,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Поле номера карты
                    TextField(
                      controller: numCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                        _CardNumberInputFormatter(),
                      ],
                      onChanged: (val) {
                        final digits = val.replaceAll(' ', '');
                        if (digits.startsWith('4')) {
                          detectedBrand = 'Visa';
                        } else if (digits.startsWith('5')) {
                          detectedBrand = 'Mastercard';
                        } else if (digits.startsWith('4400') || digits.startsWith('5169') || digits.startsWith('4000')) {
                          detectedBrand = 'Kaspi';
                        }
                        setModalState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Номер карты',
                        hintText: '4400 0000 0000 0000',
                        prefixIcon: const Icon(Icons.credit_card_rounded, color: AppColors.teal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: expCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                              _CardExpiryInputFormatter(),
                            ],
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Срок (ММ/ГГ)',
                              hintText: '12/28',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: cvvCtrl,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration: InputDecoration(
                              labelText: 'CVV / CVC',
                              hintText: '•••',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: holderCtrl,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Имя на карте (латиницей)',
                        hintText: 'TIMUR IVANOV',
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.teal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final digits = numCtrl.text.replaceAll(' ', '');
                          if (digits.length < 16) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Введите корректный 16-значный номер карты'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          final last4 = digits.substring(digits.length - 4);
                          final newCard = SavedCardItem(
                            id: 'card-${DateTime.now().millisecondsSinceEpoch}',
                            brand: detectedBrand,
                            cardNumber: '•••• $last4',
                            cardHolder: holderCtrl.text.trim().isEmpty ? 'SAPAR CARD' : holderCtrl.text.trim().toUpperCase(),
                            expiryDate: expCtrl.text.trim().isEmpty ? '12/28' : expCtrl.text.trim(),
                            isDefault: _cards.isEmpty,
                          );

                          setState(() {
                            _cards.add(newCard);
                          });
                          _saveCards();
                          Navigator.of(ctx).pop();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Карта $detectedBrand •••• $last4 успешно сохранена!'),
                              backgroundColor: AppColors.teal,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Привязать карту', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Способы оплаты', style: AppText.sora(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                // Банковские шлюзы и комплаенс
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: AppColors.teal, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Банковские шлюзы РК подключены',
                              style: AppText.sora(size: 14, weight: FontWeight.w700, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _gatewayStatus != null
                            ? 'Прямая интеграция: Kaspi Pay (${_gatewayStatus!['kaspi']?['isTestMode'] == true ? 'Тестовый Sandbox' : 'Боевой API'}) и Halyk Bank (${_gatewayStatus!['halyk']?['isTestMode'] == true ? 'Тестовый Sandbox' : 'Боевой API'}). Документы готовы к банковскому аудиту.'
                            : 'Прямая интеграция с Kaspi Pay (QR / Red / 0-0-12) и Halyk Bank E-Pay (Visa / MasterCard / Apple Pay). Тестовый контур активен, комплаенс-документы подготовлены для аудита банков.',
                        style: AppText.work(size: 12, color: const Color(0xFF94A3B8)).copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF14635).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFF14635).withValues(alpha: 0.4)),
                            ),
                            child: const Text('Kaspi Pay Sandbox', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF007A33).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF007A33).withValues(alpha: 0.4)),
                            ),
                            child: const Text('Halyk E-Pay Sandbox', style: TextStyle(color: Color(0xFF86EFAC), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Платежные сервисы Казахстана
                Text('Быстрая оплата в Казахстане', style: AppText.sora(size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 12),

                _methodTile(
                  id: 'kaspi',
                  title: 'Kaspi Pay & QR',
                  subtitle: 'Оплата в приложении Kaspi.kz • Kaspi Gold, Red, Kredit • 0% комиссии',
                  iconText: 'K',
                  iconBg: const Color(0xFFF14635),
                  badge: 'Рекомендуем',
                  badgeColor: const Color(0xFF0F766E),
                ),
                const SizedBox(height: 10),
                _methodTile(
                  id: 'halyk',
                  title: 'Halyk Bank & QR',
                  subtitle: 'Homebank QR, списание со счета Halyk, бонусы до 5%',
                  iconText: 'H',
                  iconBg: const Color(0xFF007A33),
                  badge: 'Кешбэк 5%',
                  badgeColor: const Color(0xFF007A33),
                ),
                const SizedBox(height: 10),
                _methodTile(
                  id: 'installment',
                  title: 'Рассрочка 0-0-12',
                  subtitle: 'Kaspi Red / Halyk рассрочка без процентов и первого взноса',
                  icon: Icons.percent_rounded,
                  iconBg: const Color(0xFF7C3AED),
                  badge: '0% переплаты',
                  badgeColor: const Color(0xFF7C3AED),
                ),
                const SizedBox(height: 10),
                _methodTile(
                  id: 'cards',
                  title: 'Банковские карты онлайн',
                  subtitle: 'Visa, Mastercard, Forte, Freedom, зарубежные карты',
                  icon: Icons.credit_card_rounded,
                  iconBg: const Color(0xFF1E3A8A),
                ),

                const SizedBox(height: 28),

                // Сохраненные банковские карты
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Привязанные карты', style: AppText.sora(size: 15, weight: FontWeight.w700)),
                    TextButton.icon(
                      onPressed: _showAddCardModal,
                      icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.teal),
                      label: const Text('Добавить', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_cards.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.credit_card_off_rounded, size: 40, color: AppColors.muted),
                        const SizedBox(height: 8),
                        Text('Нет сохраненных карт', style: AppText.sora(size: 14, weight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          'Привяжите карту для быстрой оплаты в 1 клик',
                          style: AppText.work(size: 12, color: AppColors.muted),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _showAddCardModal,
                          icon: const Icon(Icons.add_card_rounded, size: 18),
                          label: const Text('Привязать карту'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final card in _cards)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: card.isDefault ? AppColors.teal : AppColors.border,
                          width: card.isDefault ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: card.brand == 'Kaspi'
                                  ? const Color(0xFFF14635)
                                  : card.brand == 'Mastercard'
                                      ? const Color(0xFFEA580C)
                                      : const Color(0xFF1E3A8A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: card.brand == 'Kaspi'
                                ? const Text('K', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20))
                                : const Icon(Icons.credit_card_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${card.brand} ${card.cardNumber}',
                                      style: AppText.sora(size: 14, weight: FontWeight.w700),
                                    ),
                                    if (card.isDefault) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.teal.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Основная', style: TextStyle(color: AppColors.teal, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Срок: ${card.expiryDate} • ${card.cardHolder}',
                                  style: AppText.work(size: 11.5, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted),
                            onSelected: (val) {
                              if (val == 'default') _setDefaultCard(card.id);
                              if (val == 'delete') _deleteCard(card.id);
                            },
                            itemBuilder: (ctx) => [
                              if (!card.isDefault)
                                const PopupMenuItem(
                                  value: 'default',
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded, color: AppColors.teal, size: 18),
                                      SizedBox(width: 8),
                                      Text('Сделать основной'),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                    SizedBox(width: 8),
                                    Text('Удалить карту', style: TextStyle(color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                const SizedBox(height: 24),

                // Безопасность
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.sand,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_rounded, color: AppColors.teal, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Безопасность платежей PCI-DSS Level 1', style: AppText.sora(size: 13, weight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(
                              'Платежи защищены по международному протоколу 3D-Secure 2.0. Данные банковских карт передаются в зашифрованном виде (TLS 1.3) и не хранятся на серверах приложения.',
                              style: AppText.work(size: 11.5, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Юридическая информация и комплаенс
                Text('Юридическая информация для банков и клиентов', style: AppText.sora(size: 14, weight: FontWeight.w700)),
                const SizedBox(height: 10),
                _legalButton(
                  title: 'Публичная оферта и договор туруслуг',
                  subtitle: 'Соответствие Закону РК № 211-II «О туристской деятельности»',
                  icon: Icons.description_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LegalDocsScreen(initialDoc: LegalDocType.offer)),
                  ),
                ),
                const SizedBox(height: 8),
                _legalButton(
                  title: 'Политика возврата и аннуляции броней',
                  subtitle: 'Регламент возврата средств на Kaspi Gold и карты Halyk Bank',
                  icon: Icons.assignment_return_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LegalDocsScreen(initialDoc: LegalDocType.refund)),
                  ),
                ),
                const SizedBox(height: 8),
                _legalButton(
                  title: 'Политика конфиденциальности и защита ПДН',
                  subtitle: 'Закон РК № 94-V «О персональных данных и их защите»',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LegalDocsScreen(initialDoc: LegalDocType.privacy)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _legalButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.teal, size: 20),
          ),
          title: Text(title, style: AppText.sora(size: 13, weight: FontWeight.w600)),
          subtitle: Text(subtitle, style: AppText.work(size: 11, color: AppColors.muted)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.muted, size: 14),
        ),
      ),
    );
  }

  Widget _methodTile({
    required String id,
    required String title,
    required String subtitle,
    String? iconText,
    IconData? icon,
    required Color iconBg,
    String? badge,
    Color? badgeColor,
  }) {
    final isSelected = _selectedMethod == id;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.teal : AppColors.border,
          width: isSelected ? 1.6 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: () {
            setState(() => _selectedMethod = id);
            _saveCards();
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: iconText != null
                ? Text(iconText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20))
                : Icon(icon, color: Colors.white, size: 20),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: AppText.sora(size: 14, weight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? AppColors.teal).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(color: badgeColor ?? AppColors.teal, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(subtitle, style: AppText.work(size: 11.5, color: AppColors.muted)),
          trailing: Icon(
            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: isSelected ? AppColors.teal : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) {
        buffer.write(' ');
      }
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && text.length > 2) {
        buffer.write('/');
      }
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
