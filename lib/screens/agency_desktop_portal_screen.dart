import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/booking.dart';
import '../models/tour.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AgencyDesktopPortalScreen extends StatefulWidget {
  const AgencyDesktopPortalScreen({super.key});

  @override
  State<AgencyDesktopPortalScreen> createState() => _AgencyDesktopPortalScreenState();
}

class _AgencyDesktopPortalScreenState extends State<AgencyDesktopPortalScreen> {
  int _activeTab = 0; // 0: Dashboard, 1: Tours, 2: Bookings, 3: Finances, 4: Company Profile
  bool _isLoading = true;

  // Data states
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _analytics;
  Map<String, dynamic>? _finances;
  List<Tour> _tours = [];
  List<Booking> _bookings = [];
  String _searchQuery = '';
  String _tourCategoryFilter = 'all';
  String _bookingStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getAgencyProfile(),
        ApiService.getAgencyAnalytics(period: 'month'),
        ApiService.getAgencyFinances(),
        ApiService.getAgencyTours(),
        ApiService.getAgencyBookings(),
      ]);

      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>?;
          _analytics = results[1] as Map<String, dynamic>?;
          _finances = results[2] as Map<String, dynamic>?;
          _tours = results[3] as List<Tour>;
          _bookings = results[4] as List<Booking>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AgencyDesktopPortal] Load data error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // 1. Left Desktop Navigation Sidebar
          _buildSidebar(),

          // 2. Main Desktop Content Canvas
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
                      : _buildActiveTabContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 1. SIDEBAR ====================

  Widget _buildSidebar() {
    final agencyName = _profile?['name'] ?? 'Турагентство';
    final verified = _profile?['verified'] == true;
    final rating = (_profile?['rating'] ?? 5.0).toDouble();

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Slate 900
        border: Border(right: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SAPAR', style: AppText.sora(size: 16, weight: FontWeight.w800, color: Colors.white)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('B2B PORTAL', style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Agency Info Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.teal,
                  child: Text(
                    agencyName.isNotEmpty ? agencyName[0].toUpperCase() : 'A',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              agencyName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, color: AppColors.teal, size: 14),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                          const SizedBox(width: 3),
                          Text('$rating', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '· ${_tours.length} туров',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 4),
            child: Text('МЕНЮ УПРАВЛЕНИЯ', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          ),

          // Nav Items
          _navItem(icon: Icons.dashboard_outlined, label: 'Обзор и Аналитика', index: 0),
          _navItem(icon: Icons.travel_explore_rounded, label: 'Реестр туров', index: 1, count: _tours.length),
          _navItem(icon: Icons.assignment_outlined, label: 'Заявки и Туристы', index: 2, count: _bookings.length),
          _navItem(icon: Icons.account_balance_wallet_outlined, label: 'Финансы и Выплаты', index: 3),
          _navItem(icon: Icons.business_outlined, label: 'Реквизиты компании', index: 4),

          const Spacer(),

          // Bottom Controls
          const Divider(color: Color(0xFF1E293B), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back_rounded, color: Color(0xFF94A3B8), size: 18),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Вернуться на витрину', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    ApiService.logout();
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Выйти из кабинета', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12.5), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem({required IconData icon, required String label, required int index, int? count}) {
    final isSelected = _activeTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? AppColors.teal : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => setState(() => _activeTab = index),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? Colors.white : const Color(0xFF94A3B8), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (count != null && count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 2. TOP HEADER ====================

  Widget _buildTopHeader() {
    final titles = [
      'Обзор и Аналитика агентства',
      'Каталог туров и управление квотами',
      'Заявки клиентов и реестр туристов',
      'Финансовый баланс и заявки на выплату',
      'Реквизиты компании и банковские данные',
    ];

    final availableBalance = _finances?['availableBalanceKzt'] ?? 0;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titles[_activeTab],
              style: AppText.sora(size: 16, weight: FontWeight.w700, color: const Color(0xFF0F172A)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 14),

          // Баланс агентства
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, color: AppColors.teal, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Доступно к выводу: ${_formatPrice(availableBalance)} ₸',
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),
          // Быстрая кнопка действия
          if (_activeTab == 1)
            ElevatedButton.icon(
              onPressed: _openCreateTourDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Создать тур'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )
          else if (_activeTab == 2)
            OutlinedButton.icon(
              onPressed: _exportBookingsToExcel,
              icon: const Icon(Icons.download_rounded, size: 18, color: AppColors.teal),
              label: const Text('Экспорт в Excel (XLSX)', style: TextStyle(color: AppColors.teal)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                side: const BorderSide(color: AppColors.teal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )
          else if (_activeTab == 3)
            ElevatedButton.icon(
              onPressed: _openPayoutDialog,
              icon: const Icon(Icons.payments_rounded, size: 18),
              label: const Text('Запросить выплату'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

          const SizedBox(width: 12),
          IconButton(
            onPressed: _loadAllData,
            tooltip: 'Обновить данные',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  // ==================== 3. CONTENT ROUTER ====================

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildToursCatalogTab();
      case 2:
        return _buildBookingsTab();
      case 3:
        return _buildFinancesTab();
      case 4:
        return _buildCompanyProfileTab();
      default:
        return const SizedBox();
    }
  }

  // ==================== TAB 0: DASHBOARD ====================

  Widget _buildDashboardTab() {
    final totalRevenue = _analytics?['totalRevenueKzt'] ?? 0;
    final commission = _analytics?['commissionKzt'] ?? 0;
    final totalBookings = _analytics?['totalBookings'] ?? _bookings.length;
    final statusCounts = _analytics?['statusCounts'] as Map<String, dynamic>? ?? {};

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 4 KPI Cards
        Row(
          children: [
            Expanded(child: _kpiCard(title: 'Общая выручка', value: '${_formatPrice(totalRevenue)} ₸', icon: Icons.trending_up_rounded, color: const Color(0xFF10B981))),
            const SizedBox(width: 16),
            Expanded(child: _kpiCard(title: 'Комиссия агентства (10%)', value: '${_formatPrice(commission)} ₸', icon: Icons.monetization_on_rounded, color: AppColors.teal)),
            const SizedBox(width: 16),
            Expanded(child: _kpiCard(title: 'Туров в продаже', value: '${_tours.length}', icon: Icons.beach_access_rounded, color: const Color(0xFF3B82F6))),
            const SizedBox(width: 16),
            Expanded(child: _kpiCard(title: 'Всего бронирований', value: '$totalBookings', icon: Icons.people_alt_rounded, color: const Color(0xFF8B5CF6))),
          ],
        ),

        const SizedBox(height: 24),

        // Воронка статусов заявок
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Воронка бронирований клиентов', style: AppText.sora(size: 15, weight: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _statusFunnelTile(label: 'Новые заявки', count: statusCounts['new'] ?? 0, color: Colors.blue)),
                  const SizedBox(width: 12),
                  Expanded(child: _statusFunnelTile(label: 'Подтверждены', count: statusCounts['confirmed'] ?? 0, color: Colors.amber)),
                  const SizedBox(width: 12),
                  Expanded(child: _statusFunnelTile(label: 'Ваучер выдан', count: statusCounts['voucher_issued'] ?? 0, color: AppColors.teal)),
                  const SizedBox(width: 12),
                  Expanded(child: _statusFunnelTile(label: 'Завершены', count: statusCounts['completed'] ?? 0, color: Colors.green)),
                  const SizedBox(width: 12),
                  Expanded(child: _statusFunnelTile(label: 'Отменены', count: statusCounts['cancelled'] ?? 0, color: Colors.red)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Последние заявки
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Последние бронирования', style: AppText.sora(size: 15, weight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _activeTab = 2),
                    child: const Text('Смотреть все заявки →'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_bookings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Пока нет заявок туристов', style: TextStyle(color: Color(0xFF94A3B8)))),
                )
              else
                for (final b in _bookings.take(5))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Row(
                      children: [
                        Text(b.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.teal)),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Text(b.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        Expanded(
                          child: Text(b.customerPhone, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ),
                        Text('${_formatPrice(b.totalPrice)} ₸', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 16),
                        _buildStatusBadge(b.status),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kpiCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: AppText.sora(size: 20, weight: FontWeight.w800, color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _statusFunnelTile({required String label, required int count, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$count', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ==================== TAB 1: TOURS CATALOG ====================

  Widget _buildToursCatalogTab() {
    final filteredTours = _tours.where((t) {
      if (_tourCategoryFilter != 'all' && t.category != _tourCategoryFilter) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return t.title.toLowerCase().contains(q) || t.destination.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                      hintText: 'Поиск туров по названию, направлению...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _tourCategoryFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Все категории')),
                    DropdownMenuItem(value: 'beach', child: Text('🏖️ Пляжный отдых')),
                    DropdownMenuItem(value: 'excursion', child: Text('🏛️ Экскурсии')),
                    DropdownMenuItem(value: 'mountain', child: Text('🏔️ Горы / Природа')),
                    DropdownMenuItem(value: 'hot', child: Text('🔥 Горящие')),
                  ],
                  onChanged: (val) => setState(() => _tourCategoryFilter = val ?? 'all'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: filteredTours.isEmpty
                  ? const Center(child: Text('Туры не найдены', style: TextStyle(color: Color(0xFF94A3B8))))
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('ТУР', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('НАПРАВЛЕНИЕ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('НОЧЕЙ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('ОТЕЛЬ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('ЦЕНА ОТ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('МЕСТ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('СТАТУС', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('ДЕЙСТВИЯ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                        rows: [
                          for (final t in filteredTours)
                            DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          t.primaryPhotoUrl ?? 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800',
                                          width: 36,
                                          height: 36,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(width: 36, height: 36, color: AppColors.teal),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(t.destination, style: const TextStyle(fontSize: 12.5))),
                                DataCell(Text(t.nights, style: const TextStyle(fontSize: 12.5))),
                                DataCell(Text('${t.hotelStars}★', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
                                DataCell(Text('${_formatPrice(t.priceFrom)} ₸', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataCell(Text('${t.seatsLeft ?? 20}', style: const TextStyle(fontSize: 12.5))),
                                DataCell(
                                  Switch.adaptive(
                                    value: t.isActive,
                                    activeTrackColor: AppColors.teal,
                                    onChanged: (val) async {
                                      final updated = await ApiService.toggleTourActive(t.id);
                                      if (updated != null) _loadAllData();
                                    },
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.teal),
                                        tooltip: 'Редактировать цену/квоту',
                                        onPressed: () => _openEditTourDialog(t),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                        tooltip: 'Удалить тур',
                                        onPressed: () => _confirmDeleteTour(t),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TAB 2: BOOKINGS CRM ====================

  Widget _buildBookingsTab() {
    final filteredBookings = _bookings.where((b) {
      if (_bookingStatusFilter != 'all' && b.status != _bookingStatusFilter) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return b.customerName.toLowerCase().contains(q) ||
            b.customerPhone.toLowerCase().contains(q) ||
            b.id.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Search & Status filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                      hintText: 'Поиск по ФИО туриста, телефону или номеру брони...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _bookingStatusFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Все статусы')),
                    DropdownMenuItem(value: 'new', child: Text('Новые заявки')),
                    DropdownMenuItem(value: 'confirmed', child: Text('Подтвержденные')),
                    DropdownMenuItem(value: 'voucher_issued', child: Text('Ваучер выдан')),
                    DropdownMenuItem(value: 'completed', child: Text('Завершенные')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Отмененные')),
                  ],
                  onChanged: (val) => setState(() => _bookingStatusFilter = val ?? 'all'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bookings Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: filteredBookings.isEmpty
                  ? const Center(child: Text('Заявки не найдены', style: TextStyle(color: Color(0xFF94A3B8))))
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('НОМЕР', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('ТУРИСТ / КЛИЕНТ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('КОНТАКТЫ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('ГОСТЕЙ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('СУММА', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('СТАТУС', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('УПРАВЛЕНИЕ СТАТУСОМ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                        rows: [
                          for (final b in filteredBookings)
                            DataRow(
                              cells: [
                                DataCell(Text(b.id, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.teal, fontSize: 12.5))),
                                DataCell(Text(b.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(b.customerPhone, style: const TextStyle(fontSize: 12)),
                                      Text(b.customerEmail, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                DataCell(Text('${b.guestsCount} чел.', style: const TextStyle(fontSize: 12.5))),
                                DataCell(Text('${_formatPrice(b.totalPrice)} ₸', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataCell(_buildStatusBadge(b.status)),
                                DataCell(
                                  PopupMenuButton<String>(
                                    tooltip: 'Сменить статус',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Действие', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                          SizedBox(width: 4),
                                          Icon(Icons.arrow_drop_down_rounded, size: 16),
                                        ],
                                      ),
                                    ),
                                    onSelected: (newStatus) async {
                                      final res = await ApiService.updateBookingStatus(b.id, newStatus);
                                      if (res != null) _loadAllData();
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: 'confirmed', child: Text('✅ Подтвердить бронь')),
                                      PopupMenuItem(value: 'voucher_issued', child: Text('🎟️ Выдать ваучер')),
                                      PopupMenuItem(value: 'completed', child: Text('🏁 Завершить тур')),
                                      PopupMenuItem(value: 'cancelled', child: Text('❌ Отменить бронь')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TAB 3: FINANCES ====================

  Widget _buildFinancesTab() {
    final totalSales = _finances?['totalSalesKzt'] ?? 0;
    final totalCommission = _finances?['totalCommissionEarned'] ?? 0;
    final paidOut = _finances?['paidOutKzt'] ?? 0;
    final available = _finances?['availableBalanceKzt'] ?? 0;
    final bankIban = _finances?['bankIban'] ?? 'Не указан';
    final payoutHistory = _finances?['payoutHistory'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Finance Cards
        Row(
          children: [
            Expanded(child: _kpiCard(title: 'Всего продаж туров', value: '${_formatPrice(totalSales)} ₸', icon: Icons.storefront_rounded, color: const Color(0xFF3B82F6))),
            const SizedBox(width: 16),
            Expanded(child: _kpiCard(title: 'Комиссия 10% заработано', value: '${_formatPrice(totalCommission)} ₸', icon: Icons.insights_rounded, color: const Color(0xFF10B981))),
            const SizedBox(width: 16),
            Expanded(child: _kpiCard(title: 'Выплачено агентству', value: '${_formatPrice(paidOut)} ₸', icon: Icons.check_circle_rounded, color: const Color(0xFF64748B))),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: AppColors.teal.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Доступно к выплате', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    Text('${_formatPrice(available)} ₸', style: AppText.sora(size: 20, weight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: available > 0 ? _openPayoutDialog : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.teal,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Запросить вывод на IBAN', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Payout Requisites Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF475569), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Выплаты производятся на расчетный счет: $bankIban. Изменить счет можно во вкладке «Реквизиты компании».',
                  style: const TextStyle(color: Color(0xFF334155), fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Payout history table
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('История заявок на выплату', style: AppText.sora(size: 15, weight: FontWeight.w700)),
              const SizedBox(height: 16),
              if (payoutHistory.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('История выплат пока пуста', style: TextStyle(color: Color(0xFF94A3B8)))),
                )
              else
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.2),
                    1: FlexColumnWidth(1.5),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(1.5),
                    4: FlexColumnWidth(1),
                  },
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                      children: [
                        Padding(padding: EdgeInsets.only(bottom: 8), child: Text('СУММА', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.only(bottom: 8), child: Text('ДАТА', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.only(bottom: 8), child: Text('IBAN СЧЕТ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.only(bottom: 8), child: Text('БАНК', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.only(bottom: 8), child: Text('СТАТУС', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                    for (final p in payoutHistory)
                      TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('${_formatPrice(p['amount'] ?? 0)} ₸', style: const TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('${p['createdAt'] ?? '—'}'.split('T').first)),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('${p['iban'] ?? '—'}')),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('${p['bankName'] ?? 'Kaspi Bank'}')),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (p['status'] == 'processed' ? Colors.green : Colors.amber).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p['status'] == 'processed' ? 'Выплачено' : 'В обработке',
                                style: TextStyle(color: p['status'] == 'processed' ? Colors.green : Colors.amber.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TAB 4: COMPANY PROFILE ====================

  Widget _buildCompanyProfileTab() {
    final nameCtrl = TextEditingController(text: _profile?['name'] ?? '');
    final binCtrl = TextEditingController(text: _profile?['binIin'] ?? '');
    final addressCtrl = TextEditingController(text: _profile?['legalAddress'] ?? _profile?['address'] ?? '');
    final bankCtrl = TextEditingController(text: _profile?['bankName'] ?? '');
    final ibanCtrl = TextEditingController(text: _profile?['bankIban'] ?? '');
    final bicCtrl = TextEditingController(text: _profile?['bankBic'] ?? '');
    final contactCtrl = TextEditingController(text: _profile?['contactPerson'] ?? '');
    final phoneCtrl = TextEditingController(text: _profile?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: _profile?['email'] ?? '');
    final tgCtrl = TextEditingController(text: _profile?['telegramChatId'] ?? '');

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Юридические и банковские реквизиты компании', style: AppText.sora(size: 16, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Эти данные используются при формировании договоров с туристами и перечислении комиссионного вознаграждения.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(child: _fieldInput('Название турагентства (ТОО/ИП)', nameCtrl)),
                  const SizedBox(width: 16),
                  Expanded(child: _fieldInput('БИН / ИИН компании', binCtrl, hint: '12 цифр')),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: _fieldInput('Юридический адрес', addressCtrl, hint: 'г. Алматы, пр. Достык, 180')),
                  const SizedBox(width: 16),
                  Expanded(child: _fieldInput('ФИО директора / контактного лица', contactCtrl)),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: _fieldInput('Банк обслуживания', bankCtrl, hint: 'Kaspi Bank / Halyk / Forte')),
                  const SizedBox(width: 16),
                  Expanded(child: _fieldInput('Расчетный счет IBAN', ibanCtrl, hint: 'KZ... (20 знаков)')),
                  const SizedBox(width: 16),
                  Expanded(child: _fieldInput('БИК банка', bicCtrl, hint: 'CASPKZKA')),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: _fieldInput('Контактный телефон менеджера', phoneCtrl)),
                  const SizedBox(width: 16),
                  Expanded(child: _fieldInput('Email для уведомлений о бронях', emailCtrl)),
                  const SizedBox(width: 16),
                  Expanded(child: _fieldInput('Telegram Chat ID (для бот-оповещений)', tgCtrl, hint: '@channel или chat_id')),
                ],
              ),

              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () async {
                  final updateData = {
                    'name': nameCtrl.text.trim(),
                    'binIin': binCtrl.text.trim(),
                    'legalAddress': addressCtrl.text.trim(),
                    'bankName': bankCtrl.text.trim(),
                    'bankIban': ibanCtrl.text.trim(),
                    'bankBic': bicCtrl.text.trim(),
                    'contactPerson': contactCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'telegramChatId': tgCtrl.text.trim(),
                  };
                  final res = await ApiService.updateAgencyProfile(updateData);
                  if (res != null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Реквизиты агентства успешно сохранены!'), backgroundColor: AppColors.teal),
                    );
                    _loadAllData();
                  }
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Сохранить реквизиты'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fieldInput(String label, TextEditingController controller, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF334155), fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
      ],
    );
  }

  // ==================== DIALOGS & ACTIONS ====================

  void _openCreateTourDialog() {
    final titleCtrl = TextEditingController();
    final destCtrl = TextEditingController(text: 'Анталия, Турция');
    final nightsCtrl = TextEditingController(text: '7 ночей');
    final datesCtrl = TextEditingController(text: '01.08 - 08.08');
    final priceCtrl = TextEditingController(text: '350000');
    final seatsCtrl = TextEditingController(text: '20');
    final hotelCtrl = TextEditingController(text: 'Rixos Premium 5★');
    String meal = 'Все включено (AI)';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('Создать новый тур (B2B)', style: AppText.sora(size: 16, weight: FontWeight.w700)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _fieldInput('Название тура', titleCtrl, hint: 'Летний отдых в Анталье 5★'),
                  const SizedBox(height: 12),
                  _fieldInput('Направление / Город', destCtrl),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _fieldInput('Ночей', nightsCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _fieldInput('Даты', datesCtrl)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _fieldInput('Цена от (₸)', priceCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _fieldInput('Мест в квоте', seatsCtrl)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _fieldInput('Отель', hotelCtrl),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                final newTour = {
                  'title': titleCtrl.text.trim(),
                  'destination': destCtrl.text.trim(),
                  'nights': nightsCtrl.text.trim(),
                  'durationNights': int.tryParse(nightsCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 7,
                  'dates': datesCtrl.text.trim(),
                  'meal': meal,
                  'priceFrom': int.tryParse(priceCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 300000,
                  'seatsLeft': int.tryParse(seatsCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 20,
                  'hotelStars': 5,
                  'hotelName': hotelCtrl.text.trim(),
                  'photoUrl': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800',
                  'category': 'beach',
                };
                final res = await ApiService.createTour(data: newTour);
                if (res != null) {
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  if (!mounted) return;
                  _loadAllData();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white),
              child: const Text('Опубликовать тур'),
            ),
          ],
        );
      },
    );
  }

  void _openEditTourDialog(Tour tour) {
    final priceCtrl = TextEditingController(text: '${tour.priceFrom}');
    final seatsCtrl = TextEditingController(text: '${tour.seatsLeft ?? 20}');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('Редактировать тур: ${tour.title}', style: AppText.sora(size: 15, weight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _fieldInput('Цена от (₸)', priceCtrl),
              const SizedBox(height: 12),
              _fieldInput('Остаток мест', seatsCtrl),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                final updatedPrice = int.tryParse(priceCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? tour.priceFrom;
                final updatedSeats = int.tryParse(seatsCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 20;

                final res = await ApiService.updateTour(tour.id, {
                  'priceFrom': updatedPrice,
                  'seatsLeft': updatedSeats,
                });
                if (res != null) {
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  if (!mounted) return;
                  _loadAllData();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white),
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteTour(Tour tour) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Удаление тура'),
        content: Text('Вы действительно хотите удалить тур «${tour.title}» из каталога?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final ok = await ApiService.deleteAgencyTour(tour.id);
              if (ok) _loadAllData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _openPayoutDialog() {
    final available = _finances?['availableBalanceKzt'] ?? 0;
    final defaultIban = _profile?['bankIban'] ?? '';
    final amountCtrl = TextEditingController(text: '$available');
    final ibanCtrl = TextEditingController(text: defaultIban);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Запрос на вывод комиссии', style: AppText.sora(size: 16, weight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Доступно: ${_formatPrice(available)} ₸', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.teal)),
            const SizedBox(height: 14),
            _fieldInput('Сумма к выводу (₸)', amountCtrl),
            const SizedBox(height: 12),
            _fieldInput('Номер счета IBAN', ibanCtrl, hint: 'KZ...'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              final amt = int.tryParse(amountCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
              if (amt <= 0 || amt > available) return;

              final res = await ApiService.createAgencyPayoutRequest(amount: amt, iban: ibanCtrl.text.trim());
              if (res != null) {
                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Заявка на выплату успешно отправлена!'), backgroundColor: AppColors.teal),
                );
                _loadAllData();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white),
            child: const Text('Отправить заявку'),
          ),
        ],
      ),
    );
  }

  void _exportBookingsToExcel() async {
    final url = ApiService.getAgencyBookingsExportUrl();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'new':
      case 'paid':
        bg = Colors.blue.withValues(alpha: 0.12);
        fg = Colors.blue.shade700;
        label = 'Новая';
        break;
      case 'confirmed':
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amber.shade900;
        label = 'Подтвержден';
        break;
      case 'voucher_issued':
        bg = AppColors.teal.withValues(alpha: 0.15);
        fg = AppColors.teal;
        label = 'Ваучер выдан';
        break;
      case 'completed':
        bg = Colors.green.withValues(alpha: 0.12);
        fg = Colors.green.shade700;
        label = 'Завершен';
        break;
      case 'cancelled':
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.red.shade700;
        label = 'Отменен';
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.12);
        fg = Colors.grey.shade700;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _formatPrice(num val) {
    return val.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }
}
