import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../models/tour.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'agency_desktop_portal_screen.dart';
import 'create_tour_screen.dart';
import 'crm_calls_screen.dart';

class AgencyDashboardScreen extends StatefulWidget {
  const AgencyDashboardScreen({super.key});

  @override
  State<AgencyDashboardScreen> createState() => _AgencyDashboardScreenState();
}

class _AgencyDashboardScreenState extends State<AgencyDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Данные аналитики
  bool _isLoadingAnalytics = true;
  String _selectedPeriod = 'month'; // 'week', 'month', 'all'
  Map<String, dynamic>? _analyticsData;

  // Данные заявок (Канбан)
  bool _isLoadingBookings = true;
  String _selectedStatusFilter = 'all'; // 'all', 'new', 'confirmed', 'voucher_issued', 'completed'
  List<Booking> _agencyBookings = [];

  // Данные туров агентства
  bool _isLoadingTours = true;
  List<Tour> _agencyTours = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadAnalytics(),
      _loadBookings(),
      _loadTours(),
    ]);
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoadingAnalytics = true);
    final data = await ApiService.getAgencyAnalytics(period: _selectedPeriod);
    if (mounted) {
      setState(() {
        _analyticsData = data;
        _isLoadingAnalytics = false;
      });
    }
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoadingBookings = true);
    final bookings = await ApiService.getAgencyBookings(
      status: _selectedStatusFilter == 'all' ? null : _selectedStatusFilter,
    );
    if (mounted) {
      setState(() {
        _agencyBookings = bookings;
        _isLoadingBookings = false;
      });
    }
  }

  Future<void> _loadTours() async {
    setState(() => _isLoadingTours = true);
    final tours = await ApiService.getAgencyTours();
    if (mounted) {
      setState(() {
        _agencyTours = tours;
        _isLoadingTours = false;
      });
    }
  }

  Future<void> _toggleTourActive(Tour tour) async {
    final updated = await ApiService.toggleTourActive(tour.id);
    if (updated != null && mounted) {
      NotificationService.showNotification(
        title: updated.isActive ? 'Тур возвращен в продажу' : 'Тур поставлен на паузу',
        body: '${tour.title} (${tour.destination})',
      );
      _loadTours();
    }
  }

  Future<void> _changeBookingStatus(String bookingId, String nextStatus, String label) async {
    final updated = await ApiService.updateBookingStatus(bookingId, nextStatus);
    if (updated != null && mounted) {
      NotificationService.showNotification(
        title: 'Статус заявки обновлен',
        body: 'Заявка $bookingId переведена в статус "$label"',
      );
      _loadBookings();
      _loadAnalytics();
    }
  }

  void _showEditTourDialog(Tour tour) {
    final priceController = TextEditingController(text: tour.priceFrom.toString());
    final datesController = TextEditingController(text: tour.dates);
    final nightsController = TextEditingController(text: tour.nights.toString());
    final descController = TextEditingController(text: tour.description);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Редактирование тура', style: AppText.sora(size: 18, weight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tour.title, style: AppText.work(size: 14, weight: FontWeight.w600, color: AppColors.teal)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Цена от (₸)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: datesController,
                    decoration: InputDecoration(
                      labelText: 'Даты (напр. 15 июня - 22 июня)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nightsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Количество ночей',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Описание тура',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                final price = int.tryParse(priceController.text) ?? tour.priceFrom;
                final nights = int.tryParse(nightsController.text) ?? tour.nights;
                final updated = await ApiService.updateTour(tour.id, {
                  'priceFrom': price,
                  'dates': datesController.text.trim(),
                  'nights': nights,
                  'description': descController.text.trim(),
                });
                if (context.mounted) {
                  Navigator.of(context).pop();
                  if (updated != null) {
                    NotificationService.showNotification(
                      title: 'Тур успешно обновлен',
                      body: 'Новая цена: ${price.toString()} ₸',
                    );
                    _loadTours();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Сохранить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Кабинет турагентства (B2B)', style: AppText.sora(size: 18, weight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.desktop_windows_rounded, color: AppColors.teal),
            tooltip: 'Десктоп-портал для компаний',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AgencyDesktopPortalScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.headset_mic_rounded, color: AppColors.teal),
            tooltip: 'Мини-CRM & Обзвон',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CrmCallsScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.teal,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.teal,
          indicatorWeight: 3,
          labelStyle: AppText.work(size: 13, weight: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Аналитика'),
            Tab(icon: Icon(Icons.view_kanban_outlined), text: 'Заявки (CRM)'),
            Tab(icon: Icon(Icons.beach_access_rounded), text: 'Мои туры'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAnalyticsTab(),
          _buildBookingsTab(),
          _buildToursTab(),
        ],
      ),
    );
  }

  // ==================== ВКЛАДКА 1: АНАЛИТИКА ====================
  Widget _buildAnalyticsTab() {
    if (_isLoadingAnalytics) {
      return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    }

    final data = _analyticsData ?? {};
    final totalRevenue = data['totalRevenueKzt'] ?? 0;
    final commission = data['commissionKzt'] ?? 0;
    final avgCheck = data['averageCheckKzt'] ?? 0;
    final totalBookings = data['totalBookings'] ?? 0;
    final salesChart = (data['salesChart'] as List<dynamic>?) ?? [];
    final statusCounts = (data['statusCounts'] as Map<String, dynamic>?) ?? {};

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: AppColors.teal,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Переключатель периода
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Период продаж:', style: AppText.work(size: 14, weight: FontWeight.w600, color: AppColors.muted)),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'week', label: Text('Неделя')),
                  ButtonSegment(value: 'month', label: Text('Месяц')),
                  ButtonSegment(value: 'all', label: Text('Все')),
                ],
                selected: {_selectedPeriod},
                onSelectionChanged: (set) {
                  setState(() => _selectedPeriod = set.first);
                  _loadAnalytics();
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return AppColors.teal;
                    return Colors.white;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return Colors.white;
                    return AppColors.ink;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Карточки KPI
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  title: 'Выручка продаж',
                  value: '${_formatMoney(totalRevenue)} ₸',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard(
                  title: 'Комиссия (10%)',
                  value: '${_formatMoney(commission)} ₸',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  title: 'Средний чек',
                  value: '${_formatMoney(avgCheck)} ₸',
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard(
                  title: 'Всего броней',
                  value: '$totalBookings заявок',
                  icon: Icons.flight_takeoff_rounded,
                  color: const Color(0xFFEA580C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // График продаж по дням
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Динамика продаж по дням', style: AppText.sora(size: 15, weight: FontWeight.w700)),
                    const Icon(Icons.trending_up_rounded, color: AppColors.teal, size: 22),
                  ],
                ),
                const SizedBox(height: 16),
                if (salesChart.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text('Нет данных за выбранный период', style: AppText.work(color: AppColors.muted))),
                  )
                else
                  _buildBarChart(salesChart),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Воронка статусов (Конверсия)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Воронка обработки туристов', style: AppText.sora(size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 14),
                _funnelItem('Новые заявки', statusCounts['new'] ?? 0, const Color(0xFFF59E0B)),
                _funnelItem('Подтверждены', statusCounts['confirmed'] ?? 0, const Color(0xFF0284C7)),
                _funnelItem('Выдан ваучер', statusCounts['voucher_issued'] ?? 0, const Color(0xFF10B981)),
                _funnelItem('Завершены успешно', statusCounts['completed'] ?? 0, const Color(0xFF6B7280)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard({required String title, required String value, required IconData icon, required Color color}) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppText.work(size: 11.5, weight: FontWeight.w600, color: AppColors.muted)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AppText.sora(size: 16, weight: FontWeight.w700, color: AppColors.ink)),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<dynamic> points) {
    int maxRevenue = 1;
    for (final p in points) {
      final rev = (p['revenue'] as num?)?.toInt() ?? 0;
      if (rev > maxRevenue) maxRevenue = rev;
    }

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((p) {
          final rev = (p['revenue'] as num?)?.toInt() ?? 0;
          final label = p['label']?.toString() ?? '';
          final heightFactor = (rev / maxRevenue).clamp(0.08, 1.0);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (rev > 0)
                    Text(
                      '${(rev / 1000).round()}k',
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.teal),
                    ),
                  const SizedBox(height: 4),
                  Container(
                    height: 85 * heightFactor,
                    decoration: BoxDecoration(
                      color: rev > 0 ? AppColors.teal : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label.split(' ').first,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: rev > 0 ? FontWeight.bold : FontWeight.normal,
                      color: rev > 0 ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _funnelItem(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: AppText.work(size: 13, weight: FontWeight.w500))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ==================== ВКЛАДКА 2: КАНБАН ЗАЯВОК ====================
  Widget _buildBookingsTab() {
    return Column(
      children: [
        // Панель фильтров статусов + Кнопка Excel экспорта
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _statusChip('all', 'Все'),
                    _statusChip('new', 'Новые'),
                    _statusChip('confirmed', 'Подтверждены'),
                    _statusChip('voucher_issued', 'Ваучер выдан'),
                    _statusChip('completed', 'Завершены'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Заявок найдено: ${_agencyBookings.length}', style: AppText.work(size: 13, color: AppColors.muted)),
                  OutlinedButton.icon(
                    onPressed: () {
                      final exportUrl = ApiService.getAgencyBookingsExportUrl(
                        status: _selectedStatusFilter == 'all' ? null : _selectedStatusFilter,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Манифест формируется по адресу:\n$exportUrl'),
                          backgroundColor: const Color(0xFF0284C7),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    },
                    icon: const Icon(Icons.table_view_rounded, size: 16, color: Color(0xFF059669)),
                    label: const Text('Экспорт в Excel (XLSX)', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF059669)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Список бронирований
        Expanded(
          child: _isLoadingBookings
              ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
              : _agencyBookings.isEmpty
                  ? Center(child: Text('Заявок с данным статусом нет', style: AppText.work(color: AppColors.muted)))
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
                      color: AppColors.teal,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _agencyBookings.length,
                        itemBuilder: (context, index) {
                          final b = _agencyBookings[index];
                          return _buildBookingKanbanCard(b);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _statusChip(String statusKey, String label) {
    final isSelected = _selectedStatusFilter == statusKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.teal,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.ink,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12.5,
        ),
        onSelected: (val) {
          if (val) {
            setState(() => _selectedStatusFilter = statusKey);
            _loadBookings();
          }
        },
      ),
    );
  }

  Widget _buildBookingKanbanCard(Booking b) {
    Color badgeColor = Colors.orange;
    String statusTitle = 'Новая заявка';

    switch (b.status) {
      case 'confirmed':
        badgeColor = const Color(0xFF0284C7);
        statusTitle = 'Подтверждена';
        break;
      case 'voucher_issued':
        badgeColor = const Color(0xFF10B981);
        statusTitle = 'Ваучер выдан';
        break;
      case 'completed':
        badgeColor = Colors.grey;
        statusTitle = 'Завершена';
        break;
      case 'cancelled':
        badgeColor = Colors.red;
        statusTitle = 'Отменена';
        break;
      default:
        badgeColor = Colors.amber.shade800;
        statusTitle = 'Оплачена (Новая)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
              Text(b.id, style: AppText.sora(size: 14, weight: FontWeight.w700, color: AppColors.teal)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(statusTitle, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(b.customerName, style: AppText.sora(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(b.customerPhone, style: AppText.work(size: 13, color: AppColors.muted)),
              const SizedBox(width: 12),
              const Icon(Icons.people_outline_rounded, size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
              Text('${b.guestsCount} чел.', style: AppText.work(size: 13, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Сумма тура:', style: AppText.work(size: 13, color: AppColors.muted)),
              Text('${_formatMoney(b.totalPrice)} ₸', style: AppText.sora(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
          const Divider(height: 20),

          // Кнопки управления статусом Канбан
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (b.status == 'paid' || b.status == 'new' || b.status == 'pending')
                ElevatedButton.icon(
                  onPressed: () => _changeBookingStatus(b.id, 'confirmed', 'Подтверждена'),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Подтвердить тур'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                ),
              if (b.status == 'confirmed')
                ElevatedButton.icon(
                  onPressed: () => _changeBookingStatus(b.id, 'voucher_issued', 'Выдан ваучер'),
                  icon: const Icon(Icons.assignment_turned_in_outlined, size: 16),
                  label: const Text('Выдать ваучер'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                ),
              if (b.status == 'voucher_issued')
                ElevatedButton.icon(
                  onPressed: () => _changeBookingStatus(b.id, 'completed', 'Завершена'),
                  icon: const Icon(Icons.flag_circle_outlined, size: 16),
                  label: const Text('Завершить тур'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700, foregroundColor: Colors.white),
                ),
              OutlinedButton.icon(
                onPressed: () {
                  final pdfUrl = ApiService.getVoucherPdfUrl(b.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ссылка на PDF ваучера:\n$pdfUrl')),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.red),
                label: const Text('Ваучер PDF', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== ВКЛАДКА 3: МОИ ТУРЫ ====================
  Widget _buildToursTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Всего туров: ${_agencyTours.length}', style: AppText.work(size: 14, weight: FontWeight.w600)),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateTourScreen()),
                  ).then((_) => _loadTours());
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Создать тур', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingTours
              ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
              : _agencyTours.isEmpty
                  ? Center(child: Text('У агентства пока нет опубликованных туров', style: AppText.work(color: AppColors.muted)))
                  : RefreshIndicator(
                      onRefresh: _loadTours,
                      color: AppColors.teal,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _agencyTours.length,
                        itemBuilder: (context, index) {
                          final tour = _agencyTours[index];
                          return _buildTourManagementCard(tour);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildTourManagementCard(Tour tour) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  tour.primaryPhotoUrl ?? '',
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 70,
                    height: 70,
                    color: AppColors.teal.withValues(alpha: 0.1),
                    child: const Icon(Icons.image_not_supported_outlined, color: AppColors.teal),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tour.title, style: AppText.sora(size: 14, weight: FontWeight.w700), maxLines: 2),
                    const SizedBox(height: 4),
                    Text('${tour.destination} · ${tour.dates}', style: AppText.work(size: 12, color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Text('от ${_formatMoney(tour.priceFrom)} ₸', style: AppText.sora(size: 14, weight: FontWeight.w700, color: AppColors.teal)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          // Статус рекламы и кнопка продвижения
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tour.isPromoted ? const Color(0xFFFFFBEB) : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: tour.isPromoted ? const Color(0xFFFDE68A) : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: tour.isPromoted ? const Color(0xFFD97706) : AppColors.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tour.isPromoted ? 'Реклама активна (ТОП выдачи)' : 'Тур на стандартных позициях',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tour.isPromoted ? const Color(0xFFB45309) : AppColors.muted,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showPromoteTourDialog(tour),
                  icon: Icon(
                    tour.isPromoted ? Icons.update_rounded : Icons.rocket_launch_rounded,
                    size: 15,
                    color: tour.isPromoted ? const Color(0xFFB45309) : AppColors.teal,
                  ),
                  label: Text(
                    tour.isPromoted ? 'Продлить' : 'Продвинуть',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: tour.isPromoted ? const Color(0xFFB45309) : AppColors.teal,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: tour.isActive ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tour.isActive ? 'В продаже' : 'На паузе',
                    style: TextStyle(
                      color: tour.isActive ? Colors.green.shade700 : Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.teal),
                    tooltip: 'Редактировать цену/даты',
                    onPressed: () => _showEditTourDialog(tour),
                  ),
                  Switch(
                    value: tour.isActive,
                    activeThumbColor: AppColors.teal,
                    onChanged: (val) => _toggleTourActive(tour),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPromoteTourDialog(Tour tour) {
    int selectedDays = 7;
    String selectedMethod = 'Kaspi Pay';
    bool isSubmitting = false;

    final tariffs = [
      {'days': 3, 'title': 'Быстрый старт', 'price': 15000, 'badge': 'Тест'},
      {'days': 7, 'title': 'Тур недели', 'price': 29000, 'badge': 'Хит'},
      {'days': 30, 'title': 'Максимальный охват', 'price': 79000, 'badge': 'VIP'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeTariff = tariffs.firstWhere((t) => t['days'] == selectedDays);
            final price = activeTariff['price'] as int;

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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Продвижение тура в ТОП', style: AppText.h3.copyWith(fontSize: 18)),
                            Text(tour.title, style: AppText.work(size: 13, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  Text('Выберите срок размещения', style: AppText.work(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 10),

                  // Карточки тарифов
                  Row(
                    children: tariffs.map((t) {
                      final days = t['days'] as int;
                      final isSelected = selectedDays == days;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedDays = days),
                          child: Container(
                            margin: EdgeInsets.only(right: days != 30 ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFFFBEB) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFF59E0B) : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFF59E0B) : AppColors.surface,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    t['badge'] as String,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : AppColors.muted,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('$days дней', style: AppText.work(size: 13, weight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${_formatMoney(t['price'] as int)} ₸', style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Преимущества тарифа
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                            SizedBox(width: 6),
                            Text('Преимущества платного продвижения:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('• Тур поднимается на 1-е место в каталоге и результатах поиска.', style: AppText.work(size: 11.5, color: const Color(0xFF166534))),
                        Text('• Золотой бейдж «Реклама • ТОП» привлекает на 300% больше кликов.', style: AppText.work(size: 11.5, color: const Color(0xFF166534))),
                        Text('• Прямой переход к бронированию и звонкам в агентство.', style: AppText.work(size: 11.5, color: const Color(0xFF166534))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Способ оплаты
                  Text('Способ оплаты рекламы', style: AppText.work(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Kaspi Pay', 'Банковская карта'].map((m) {
                      final isSelected = selectedMethod == m;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedMethod = m),
                          child: Container(
                            margin: EdgeInsets.only(right: m == 'Kaspi Pay' ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.teal.withValues(alpha: 0.08) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? AppColors.teal : AppColors.border,
                                width: isSelected ? 1.8 : 1,
                              ),
                            ),
                            child: Text(
                              m,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? AppColors.teal : AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),

                  // Кнопка оплаты
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);
                              final res = await ApiService.promoteTour(
                                tourId: tour.id,
                                days: selectedDays,
                                tier: selectedDays == 30 ? 'vip' : 'top',
                                paymentMethod: selectedMethod,
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                                if (res != null && res['success'] == true) {
                                  _loadTours();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(res['message']?.toString() ?? 'Тур успешно поднят в ТОП!')),
                                        ],
                                      ),
                                      backgroundColor: const Color(0xFFD97706),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res?['message']?.toString() ?? 'Ошибка оформления продвижения'),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Оплатить ${_formatMoney(price)} ₸ и запустить', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

  String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }
}
