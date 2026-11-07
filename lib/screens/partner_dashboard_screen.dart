import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/referral.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class PartnerDashboardScreen extends StatefulWidget {
  const PartnerDashboardScreen({super.key});

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  ReferralStats? _stats;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final stats = await ApiService.getReferralStats();
    if (!mounted) return;

    if (stats != null) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = 'Не удалось загрузить данные партнёрского кабинета';
        _isLoading = false;
      });
    }
  }

  String _fmtMoney(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return '${buffer.toString()} ₸';
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.teal,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showCreateCampaignDialog() {
    final nameCtrl = TextEditingController(text: 'Instagram Stories');
    final codeCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_link_rounded, color: AppColors.teal),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Новая реферальная ссылка', style: AppText.h3.copyWith(fontSize: 18)),
                            Text('Создайте персональный промокод для соцсетей', style: AppText.work(size: 13, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Название кампании / источника', style: AppText.work(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Например: TikTok, YouTube обзор, Telegram',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Желаемый промокод (необязательно)', style: AppText.work(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Оставьте пустым для автогенерации (напр. SAPAR_...)',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);
                              final res = await ApiService.createReferralCampaign(
                                campaignName: nameCtrl.text.trim(),
                                code: codeCtrl.text.trim().isNotEmpty ? codeCtrl.text.trim() : null,
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                if (res != null) {
                                  _loadStats();
                                  _copyToClipboard(res.referralUrl, 'Ссылка создана и скопирована: ${res.referralUrl}');
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Не удалось создать ссылку. Возможно, промокод уже занят.')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Сгенерировать ссылку', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

  void _showPayoutDialog() {
    final balance = _stats?.balance ?? 0;
    if (balance < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Минимальная сумма для вывода — 1 000 ₸. Продолжайте привлекать туристов!'),
          backgroundColor: AppColors.coral,
        ),
      );
      return;
    }

    final amountCtrl = TextEditingController(text: balance.toString());
    final detailsCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF2E7D32)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Запрос выплаты вознаграждения', style: AppText.h3.copyWith(fontSize: 18)),
                            Text('Доступно: ${_fmtMoney(balance)}', style: AppText.work(size: 13, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Сумма к выводу (₸)', style: AppText.work(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Реквизиты (Kaspi Gold или номер карты)', style: AppText.work(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: detailsCtrl,
                    decoration: InputDecoration(
                      hintText: '+7 777 123 4567 или 4400 4301 ...',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final amount = int.tryParse(amountCtrl.text.replaceAll(' ', '')) ?? 0;
                              if (amount < 1000 || amount > balance) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Укажите корректную сумму вывода (от 1 000 ₸)')),
                                );
                                return;
                              }
                              if (detailsCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Пожалуйста, укажите реквизиты Kaspi или карты')),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              final res = await ApiService.requestReferralPayout(
                                amount: amount,
                                paymentDetails: detailsCtrl.text.trim(),
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                                if (res['success'] == true) {
                                  _loadStats();
                                  showDialog(
                                    context: context,
                                    builder: (dCtx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: const Row(
                                        children: [
                                          Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32)),
                                          SizedBox(width: 8),
                                          Text('Заявка принята'),
                                        ],
                                      ),
                                      content: Text(
                                        res['message'] as String? ?? 'Средства поступят на указанные реквизиты в течение 24 часов.',
                                        style: AppText.work(size: 14),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dCtx),
                                          child: const Text('Понятно', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res['message']?.toString() ?? 'Ошибка запроса вывода')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Подтвердить вывод', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

  void _showQrDialog(ReferralCampaign campaign) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(campaign.campaignName, style: AppText.h3.copyWith(fontSize: 17), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Промокод: ${campaign.code}',
                style: AppText.work(size: 13, weight: FontWeight.bold, color: AppColors.teal),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: QrImageView(
                data: campaign.referralUrl,
                version: QrVersions.auto,
                size: 190.0,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Покажите этот QR-код на экране или распечатайте для подписчиков',
              textAlign: TextAlign.center,
              style: AppText.work(size: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _copyToClipboard(campaign.referralUrl, 'Ссылка скопирована!');
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Скопировать'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.teal,
                      side: const BorderSide(color: AppColors.teal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Кабинет блогера и партнёра', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Обновить',
            onPressed: _loadStats,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.teal,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.teal,
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Обзор и ссылки'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Продажи по ссылке'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.coral),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: AppText.work(size: 14, color: AppColors.muted)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStats,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildSalesHistoryTab(),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab() {
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();

    final primaryCampaign = stats.campaigns.isNotEmpty ? stats.campaigns.first : null;

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: AppColors.teal,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // 1. Градиентная карточка дохода и баланса
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 16),
                          SizedBox(width: 4),
                          Text('Sapar Partner • 3% комиссия', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Icon(Icons.volunteer_activism_rounded, color: Colors.white70, size: 24),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Доступный баланс', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  _fmtMoney(stats.balance),
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showPayoutDialog,
                        icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                        label: const Text('Вывести средства', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F766E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add_link_rounded, color: Colors.white),
                        tooltip: 'Создать новую ссылку',
                        onPressed: _showCreateCampaignDialog,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Сетка ключевых метрик
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Переходы',
                  value: '${stats.totalClicks}',
                  icon: Icons.touch_app_rounded,
                  iconColor: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  title: 'Бронирования',
                  value: '${stats.totalBookings}',
                  icon: Icons.confirmation_number_rounded,
                  iconColor: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Конверсия (CR)',
                  value: '${stats.conversionRate}%',
                  icon: Icons.trending_up_rounded,
                  iconColor: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  title: 'Всего заработано',
                  value: _fmtMoney(stats.totalEarned),
                  icon: Icons.savings_rounded,
                  iconColor: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3. Главная реферальная ссылка (Быстрый доступ)
          if (primaryCampaign != null) ...[
            Text('Ваша основная ссылка для соцсетей', style: AppText.h3.copyWith(fontSize: 16)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Промокод: ${primaryCampaign.code}',
                          style: AppText.work(size: 13, weight: FontWeight.bold, color: AppColors.teal),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.ink),
                        tooltip: 'QR-код для сторис',
                        onPressed: () => _showQrDialog(primaryCampaign),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      primaryCampaign.referralUrl,
                      style: AppText.work(size: 13, weight: FontWeight.w500, color: AppColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _copyToClipboard(primaryCampaign.referralUrl, 'Реферальная ссылка скопирована!'),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Скопировать ссылку'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _copyToClipboard(primaryCampaign.code, 'Промокод скопирован: ${primaryCampaign.code}'),
                        icon: const Icon(Icons.discount_outlined, size: 16),
                        label: const Text('Код'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 4. Список всех кампаний
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Все реферальные каналы (${stats.campaigns.length})', style: AppText.h3.copyWith(fontSize: 16)),
              TextButton.icon(
                onPressed: _showCreateCampaignDialog,
                icon: const Icon(Icons.add, size: 16, color: AppColors.teal),
                label: const Text('Создать', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...stats.campaigns.map((camp) => _buildCampaignItem(camp)),
          const SizedBox(height: 20),

          // 5. Советы для блогера
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF16A34A), size: 20),
                    SizedBox(width: 8),
                    Text('Как зарабатывать больше с Sapar?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF15803D))),
                  ],
                ),
                const SizedBox(height: 10),
                Text('• Закрепите реферальную ссылку в Bio Instagram или описании TikTok/YouTube.', style: AppText.work(size: 12.5, color: const Color(0xFF166534))),
                const SizedBox(height: 4),
                Text('• Рассказывайте о горящих турах в ОАЭ, Турцию и Египет — подписчики получают скидку 3% по промокоду.', style: AppText.work(size: 12.5, color: const Color(0xFF166534))),
                const SizedBox(height: 4),
                Text('• Вознаграждение начисляется автоматически сразу после оплаты тура.', style: AppText.work(size: 12.5, color: const Color(0xFF166534))),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: AppText.h3.copyWith(fontSize: 19)),
          const SizedBox(height: 2),
          Text(title, style: AppText.work(size: 12, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _buildCampaignItem(ReferralCampaign camp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.link_rounded, color: AppColors.teal, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(camp.campaignName, style: AppText.sora(size: 14, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(camp.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.teal)),
                    ),
                    const SizedBox(width: 8),
                    Text('•  ${camp.clicksCount} переходов  •  ${camp.bookingsCount} броней', style: AppText.work(size: 11, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.muted),
            tooltip: 'Скопировать',
            onPressed: () => _copyToClipboard(camp.referralUrl, 'Ссылка скопирована: ${camp.referralUrl}'),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, size: 20, color: AppColors.ink),
            tooltip: 'QR-код',
            onPressed: () => _showQrDialog(camp),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesHistoryTab() {
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();

    final bookings = stats.recentBookings;

    if (bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.teal, size: 40),
              ),
              const SizedBox(height: 20),
              Text('Пока нет покупок по вашей ссылке', style: AppText.h3.copyWith(fontSize: 17), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Разместите промокод в своём блоге или сторис. Как только подписчик оформит тур — здесь появится запись и начислится вознаграждение.',
                style: AppText.work(size: 13.5, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final item = bookings[index];
        final dateStr = '${item.createdAt.day.toString().padLeft(2, '0')}.${item.createdAt.month.toString().padLeft(2, '0')}.${item.createdAt.year}';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flight_takeoff_rounded, color: Color(0xFF2E7D32), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.tourTitle, style: AppText.sora(size: 14, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('Турист: ${item.customerName} • $dateStr', style: AppText.work(size: 12, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text('Стоимость тура: ${_fmtMoney(item.tourPrice)}', style: AppText.work(size: 12, color: AppColors.ink)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${_fmtMoney(item.reward)}',
                      style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Начислено', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 11)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
