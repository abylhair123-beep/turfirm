import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/crm_models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/primary_button.dart';

class CrmCallsScreen extends StatefulWidget {
  const CrmCallsScreen({super.key});

  @override
  State<CrmCallsScreen> createState() => _CrmCallsScreenState();
}

class _CrmCallsScreenState extends State<CrmCallsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<CallQueueItem> _queue = [];
  List<CallLogItem> _logs = [];
  CallStats? _stats;

  String _queueFilter = 'all'; // 'all', 'customer', 'agency'
  String _logsStatusFilter = 'all';
  String _searchQuery = '';

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final queueFuture = ApiService.getCallQueue(
        targetType: _queueFilter,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      final logsFuture = ApiService.getCallLogs(
        status: _logsStatusFilter != 'all' ? _logsStatusFilter : null,
      );
      final statsFuture = ApiService.getCallStats();

      final results = await Future.wait([queueFuture, logsFuture, statsFuture]);

      if (!mounted) return;
      setState(() {
        _queue = results[0] as List<CallQueueItem>;
        _logs = results[1] as List<CallLogItem>;
        _stats = results[2] as CallStats?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Ошибка загрузки данных CRM: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _launchPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: cleanPhone));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Номер скопирован в буфер: $cleanPhone'),
            backgroundColor: AppColors.teal,
          ),
        );
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: cleanPhone));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Номер скопирован в буфер: $cleanPhone'),
          backgroundColor: AppColors.teal,
        ),
      );
    }
  }

  Future<void> _launchWhatsApp(String phone, String name) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final message = Uri.encodeComponent('Здравствуйте, $name! Вас беспокоит служба заботы маркетплейса Sapar по вашему бронированию.');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$message');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: phone));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Контакт скопирован: $phone'), backgroundColor: AppColors.teal),
        );
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: phone));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Контакт скопирован: $phone'), backgroundColor: AppColors.teal),
      );
    }
  }

  void _openCallLogDialog({
    required String targetName,
    required String targetPhone,
    String targetType = 'customer',
    String? bookingId,
    String? agencyId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LogCallBottomSheet(
        targetName: targetName,
        targetPhone: targetPhone,
        targetType: targetType,
        bookingId: bookingId,
        agencyId: agencyId,
        onSaved: () {
          _loadAllData();
        },
      ),
    );
  }

  Future<void> _triggerVoipSimulation(CallQueueItem item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.teal),
                SizedBox(height: 16),
                Text('Набор номера через IP-АТС...', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('SIP протокол • Запись разговора включена', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        ),
      ),
    );

    final res = await ApiService.simulateVoipCall(
      targetPhone: item.targetPhone,
      targetName: item.targetName,
      targetType: item.targetType,
      bookingId: item.bookingId,
      agencyId: item.targetType == 'agency' ? item.id : null,
      simulatedOutcome: 'successful',
      notes: 'Автоматический вызов через IP-АТС. Разговор с абонентом успешно завершен.',
    );

    if (mounted) {
      Navigator.of(context).pop(); // close loading dialog
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Звонок совершен! Запись сохранена (${res.formattedDuration})')),
              ],
            ),
            backgroundColor: AppColors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAllData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Мини-CRM & Обзвон', style: AppText.sora(size: 17, weight: FontWeight.w700)),
            const SizedBox(height: 1),
            Text('Клиенты, бронирования и турфирмы', style: AppText.work(size: 11.5, color: AppColors.muted)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_call, color: AppColors.teal),
            tooltip: 'Зафиксировать звонок',
            onPressed: () {
              _openCallLogDialog(
                targetName: '',
                targetPhone: '',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.ink),
            tooltip: 'Обновить',
            onPressed: _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.teal,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.teal,
          indicatorWeight: 3,
          labelStyle: AppText.sora(size: 13, weight: FontWeight.w700),
          unselectedLabelStyle: AppText.work(size: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Очередь'),
                  if (_queue.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.coral,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_queue.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'История звонков'),
            const Tab(text: 'Аналитика и VoIP'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _errorMessage != null
              ? _buildErrorView()
              : Column(
                  children: [
                    _buildKpiBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildQueueTab(),
                          _buildLogsTab(),
                          _buildAnalyticsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_errorMessage!, textAlign: TextAlign.center, style: AppText.work(size: 14, color: AppColors.muted)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAllData,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
              child: const Text('Повторить', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiBar() {
    final s = _stats;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _kpiItem(
              title: 'Звонков сегодня',
              value: '${s?.callsToday ?? 0}',
              icon: Icons.phone_forwarded_rounded,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _kpiItem(
              title: 'Дозвон',
              value: '${s?.answerRatePct ?? 0}%',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _kpiItem(
              title: 'Ср. разговор',
              value: '${(s?.avgDurationSeconds ?? 0) ~/ 60}м ${(s?.avgDurationSeconds ?? 0) % 60}с',
              icon: Icons.timer_outlined,
              color: const Color(0xFF1E88E5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _kpiItem(
              title: 'Ждут перезвона',
              value: '${s?.pendingCallbacksCount ?? 0}',
              icon: Icons.schedule_rounded,
              color: const Color(0xFFE65100),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppText.sora(size: 15, weight: FontWeight.w700, color: AppColors.ink),
          ),
        ],
      ),
    );
  }

  // ==================== Вкладка: Очередь обзвона ====================

  Widget _buildQueueTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: AppColors.teal,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Поиск и фильтры
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Поиск по клиенту или телефону...',
                    hintStyle: AppText.work(size: 13, color: AppColors.muted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.muted),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _searchQuery = '';
                              _loadAllData();
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                  onSubmitted: (val) {
                    _searchQuery = val.trim();
                    _loadAllData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Быстрые фильтры
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(label: 'Все контакты', value: 'all'),
                const SizedBox(width: 8),
                _filterChip(label: 'Клиенты (брони)', value: 'customer'),
                const SizedBox(width: 8),
                _filterChip(label: 'Турфирмы (B2B)', value: 'agency'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_queue.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: AppColors.teal, size: 48),
                  const SizedBox(height: 12),
                  Text('Очередь обзвона пуста', style: AppText.sora(size: 16, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Все актуальные брони и агентства обработаны.', style: AppText.work(size: 13, color: AppColors.muted)),
                ],
              ),
            )
          else
            for (final item in _queue) ...[
              _buildQueueCard(item),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _filterChip({required String label, required String value}) {
    final selected = _queueFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) {
          setState(() => _queueFilter = value);
          _loadAllData();
        }
      },
      selectedColor: AppColors.teal,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.ink,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12.5,
      ),
      side: BorderSide(color: selected ? AppColors.teal : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildQueueCard(CallQueueItem item) {
    Color priorityColor;
    String priorityText;
    if (item.priority == 'callback') {
      priorityColor = const Color(0xFFE65100);
      priorityText = 'ПЕРЕЗВОНИТЬ';
    } else if (item.priority == 'high') {
      priorityColor = AppColors.coral;
      priorityText = 'ГОРЯЧАЯ БРОНЬ';
    } else {
      priorityColor = AppColors.teal;
      priorityText = 'ОБЫЧНЫЙ';
    }

    final isAgency = item.targetType == 'agency';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.priority == 'callback' ? const Color(0xFFFFB74D) : AppColors.border,
          width: item.priority == 'callback' ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка карточки
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isAgency ? const Color(0xFF7B1FA2).withValues(alpha: 0.12) : AppColors.teal.withValues(alpha: 0.12),
                child: Icon(
                  isAgency ? Icons.business_rounded : Icons.person_rounded,
                  color: isAgency ? const Color(0xFF7B1FA2) : AppColors.teal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.targetName,
                            style: AppText.sora(size: 14.5, weight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            priorityText,
                            style: TextStyle(color: priorityColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.targetPhone,
                      style: AppText.work(size: 13, weight: FontWeight.w600, color: AppColors.teal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Информация о бронировании / туре
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.sand,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.flight_takeoff_rounded, size: 16, color: AppColors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.tourTitle ?? 'Тур в Sapar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.work(size: 12, weight: FontWeight.w600),
                  ),
                ),
                if (item.totalPrice != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${item.totalPrice} ₸',
                    style: AppText.sora(size: 12.5, weight: FontWeight.w700, color: AppColors.coral),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Причина звонка и предыдущий контакт
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.reason,
                  style: AppText.work(size: 11.5, color: AppColors.muted),
                ),
              ),
            ],
          ),

          if (item.lastCallNotes != null && item.lastCallNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFFE65100)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Заметка: ${item.lastCallNotes}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFFE65100)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Кнопки действий: Вызов, WhatsApp, VoIP, Зафиксировать
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _launchPhone(item.targetPhone),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 16, color: AppColors.teal),
                  label: const Text('Позвонить', style: TextStyle(color: AppColors.teal, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: AppColors.teal),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366)),
                tooltip: 'Написать в WhatsApp',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _launchWhatsApp(item.targetPhone, item.targetName),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.headset_mic_rounded, color: Color(0xFF1E88E5)),
                tooltip: 'Автообзвон VoIP (SIP)',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _triggerVoipSimulation(item),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openCallLogDialog(
                    targetName: item.targetName,
                    targetPhone: item.targetPhone,
                    targetType: item.targetType,
                    bookingId: item.bookingId,
                    agencyId: isAgency ? item.id : null,
                  ),
                  icon: const Icon(Icons.post_add_rounded, size: 16),
                  label: const Text('Итог', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Вкладка: История звонков ====================

  Widget _buildLogsTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: AppColors.teal,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Фильтр по статусу звонка
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _logStatusChip('Все', 'all'),
                const SizedBox(width: 6),
                _logStatusChip('Дозвонился', 'successful'),
                const SizedBox(width: 6),
                _logStatusChip('Перезвонить', 'callback_needed'),
                const SizedBox(width: 6),
                _logStatusChip('Не берет', 'no_answer'),
                const SizedBox(width: 6),
                _logStatusChip('Занято', 'busy'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_logs.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.phone_missed_rounded, color: AppColors.muted, size: 44),
                  const SizedBox(height: 12),
                  Text('Звонков с таким фильтром не найдено', style: AppText.work(size: 14, color: AppColors.muted)),
                ],
              ),
            )
          else
            for (final log in _logs) ...[
              _buildLogCard(log),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _logStatusChip(String label, String value) {
    final selected = _logsStatusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) {
          setState(() => _logsStatusFilter = value);
          _loadAllData();
        }
      },
      selectedColor: AppColors.teal,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.ink,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(color: selected ? AppColors.teal : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildLogCard(CallLogItem log) {
    Color statusColor;
    String statusTitle;
    IconData statusIcon;

    switch (log.status) {
      case 'successful':
        statusColor = const Color(0xFF2E7D32);
        statusTitle = 'Дозвонился';
        statusIcon = Icons.call_made_rounded;
        break;
      case 'callback_needed':
        statusColor = const Color(0xFFE65100);
        statusTitle = 'Перезвонить';
        statusIcon = Icons.schedule_rounded;
        break;
      case 'no_answer':
        statusColor = const Color(0xFFC62828);
        statusTitle = 'Не взял трубку';
        statusIcon = Icons.phone_missed_rounded;
        break;
      case 'busy':
        statusColor = const Color(0xFFD84315);
        statusTitle = 'Занято / Сбросил';
        statusIcon = Icons.phone_locked_rounded;
        break;
      default:
        statusColor = AppColors.muted;
        statusTitle = log.status;
        statusIcon = Icons.call_end_rounded;
    }

    final timeStr = '${log.createdAt.day.toString().padLeft(2, '0')}.${log.createdAt.month.toString().padLeft(2, '0')} ${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, color: statusColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.targetName, style: AppText.sora(size: 13.5, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${log.targetPhone} • $timeStr', style: AppText.work(size: 11.5, color: AppColors.muted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusTitle,
                  style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Длительность и провайдер телефонии
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                'Длительность: ${log.formattedDuration}',
                style: AppText.work(size: 12, weight: FontWeight.w600, color: AppColors.ink),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.telephonyProvider.toUpperCase(),
                  style: const TextStyle(fontSize: 9.5, color: AppColors.muted, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          if (log.notes != null && log.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              log.notes!,
              style: AppText.work(size: 12, color: AppColors.ink),
            ),
          ],

          if (log.recordingUrl != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.audiotrack_rounded, size: 16, color: Color(0xFF1E88E5)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Аудиозапись разговора доступна (.mp3)',
                      style: TextStyle(color: Color(0xFF1E88E5), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF1E88E5), size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Воспроизведение записи звонка...'),
                          backgroundColor: Color(0xFF1E88E5),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],

          if (log.managerName != null) ...[
            const SizedBox(height: 8),
            Text(
              'Менеджер: ${log.managerName}',
              style: AppText.work(size: 11, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== Вкладка: Аналитика и VoIP ====================

  Widget _buildAnalyticsTab() {
    final s = _stats;
    final breakdown = s?.statusBreakdown ?? {};

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Карточка интеграции с IP-телефонией
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF115E59)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.settings_phone_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IP-Телефония & VoIP Webhooks', style: AppText.sora(size: 15, weight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('Mango Office, Zadarma, Asterisk, Sipuni', style: AppText.work(size: 11.5, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.link_rounded, color: Colors.amberAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'POST /api/v1/crm/calls/webhook',
                        style: TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Входящие и исходящие звонки регистрируются автоматически с привязкой к клиенту по номеру телефона.',
                style: TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text('Воронка результатов обзвона', style: AppText.sora(size: 15, weight: FontWeight.w700)),
        const SizedBox(height: 10),

        _analyticsRow(title: 'Успешно (дозвонился)', count: breakdown['successful'] ?? 0, color: const Color(0xFF2E7D32)),
        const SizedBox(height: 8),
        _analyticsRow(title: 'Запланирован перезвон', count: breakdown['callback_needed'] ?? 0, color: const Color(0xFFE65100)),
        const SizedBox(height: 8),
        _analyticsRow(title: 'Не взял трубку', count: breakdown['no_answer'] ?? 0, color: const Color(0xFFC62828)),
        const SizedBox(height: 8),
        _analyticsRow(title: 'Занято / Сбросил', count: breakdown['busy'] ?? 0, color: const Color(0xFFD84315)),
        const SizedBox(height: 8),
        _analyticsRow(title: 'Отказ / Неактуально', count: breakdown['declined'] ?? 0, color: AppColors.muted),
      ],
    );
  }

  Widget _analyticsRow({required String title, required int count, required Color color}) {
    final total = _stats?.totalCalls ?? 1;
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AppText.work(size: 13, weight: FontWeight.w600))),
              Text('$count звонков ($pct%)', style: AppText.sora(size: 12.5, weight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? count / total : 0,
              backgroundColor: AppColors.sand,
              color: color,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogCallBottomSheet extends StatefulWidget {
  final String targetName;
  final String targetPhone;
  final String targetType;
  final String? bookingId;
  final String? agencyId;
  final VoidCallback onSaved;

  const _LogCallBottomSheet({
    required this.targetName,
    required this.targetPhone,
    required this.targetType,
    this.bookingId,
    this.agencyId,
    required this.onSaved,
  });

  @override
  State<_LogCallBottomSheet> createState() => _LogCallBottomSheetState();
}

class _LogCallBottomSheetState extends State<_LogCallBottomSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _durationCtrl = TextEditingController(text: '90');

  String _status = 'successful';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.targetName);
    _phoneCtrl = TextEditingController(text: widget.targetPhone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите имя и телефон для фиксации звонка')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 0;

    final res = await ApiService.createCallLog(
      targetType: widget.targetType,
      targetName: name,
      targetPhone: phone,
      bookingId: widget.bookingId,
      agencyId: widget.agencyId,
      status: _status,
      durationSeconds: duration,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      scheduledCallbackAt: _status == 'callback_needed' ? DateTime.now().add(const Duration(hours: 3)) : null,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res != null) {
      widget.onSaved();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Лог звонка успешно сохранен в CRM!'),
          backgroundColor: AppColors.teal,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить звонок. Проверьте права доступа.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Фиксация звонка в CRM', style: AppText.sora(size: 17, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Результат разговора, заметки и планирование перезвона', style: AppText.work(size: 12, color: AppColors.muted)),
            const SizedBox(height: 18),

            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Имя клиента / Агентство',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Номер телефона',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),

            Text('Результат звонка:', style: AppText.sora(size: 13, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _statusRadio('Дозвонился', 'successful', const Color(0xFF2E7D32)),
                _statusRadio('Перезвонить', 'callback_needed', const Color(0xFFE65100)),
                _statusRadio('Не взял трубку', 'no_answer', const Color(0xFFC62828)),
                _statusRadio('Занято / Сбросил', 'busy', const Color(0xFFD84315)),
                _statusRadio('Отказ', 'declined', AppColors.muted),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Длительность (секунды)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Заметки менеджера (пожелания, виза, отель...)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                title: _isSaving ? 'Сохранение...' : 'Зафиксировать звонок',
                onTap: _isSaving ? () {} : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRadio(String label, String value, Color color) {
    final selected = _status == value;
    return InkWell(
      onTap: () => setState(() => _status = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppColors.sand,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppColors.ink,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
