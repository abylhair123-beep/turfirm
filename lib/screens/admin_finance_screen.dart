import 'package:flutter/material.dart';
import '../models/financial_summary.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  String _selectedPeriod = 'all'; // 'today', 'week', 'month', 'all'
  bool _isLoading = true;
  FinancialSummary? _summary;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await ApiService.getAdminFinancialSummary(period: _selectedPeriod);
    if (!mounted) return;

    if (res != null) {
      setState(() {
        _summary = res;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = 'Не удалось загрузить финансовые данные платформы';
        _isLoading = false;
      });
    }
  }

  String _fmtMoney(int amount) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final s = absAmount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return '${isNegative ? "-" : ""}${buffer.toString()} ₸';
  }

  void _showAddRecordDialog() {
    String type = 'income'; // 'income' или 'expense'
    String category = 'advertising';
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isIncome = type == 'income';
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isIncome ? const Color(0xFF2E7D32) : AppColors.coral).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isIncome ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                            color: isIncome ? const Color(0xFF2E7D32) : AppColors.coral,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Внести финансовую проводку', style: AppText.h3.copyWith(fontSize: 18)),
                              Text('Реклама, маркетинг, сервисы или прочие статьи', style: AppText.work(size: 13, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Переключатель типа (Приход / Расход)
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() {
                                type = 'income';
                                category = 'advertising';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isIncome ? const Color(0xFFE8F5E9) : AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isIncome ? const Color(0xFF2E7D32) : AppColors.border,
                                  width: isIncome ? 1.8 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_downward_rounded, size: 16, color: isIncome ? const Color(0xFF2E7D32) : AppColors.muted),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Приход (+)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isIncome ? const Color(0xFF2E7D32) : AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() {
                                type = 'expense';
                                category = 'marketing';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isIncome ? const Color(0xFFFFEBEE) : AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !isIncome ? AppColors.coral : AppColors.border,
                                  width: !isIncome ? 1.8 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_upward_rounded, size: 16, color: !isIncome ? AppColors.coral : AppColors.muted),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Расход (-)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: !isIncome ? AppColors.coral : AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Категория
                    Text('Категория статьи', style: AppText.work(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: category,
                          isExpanded: true,
                          items: isIncome
                              ? const [
                                  DropdownMenuItem(value: 'advertising', child: Text('Реклама и промо-баннеры')),
                                  DropdownMenuItem(value: 'featured_tour', child: Text('Топ-размещение тура агентством')),
                                  DropdownMenuItem(value: 'other_income', child: Text('Прочие сервисные доходы')),
                                ]
                              : const [
                                  DropdownMenuItem(value: 'marketing', child: Text('Маркетинг и таргет реклама')),
                                  DropdownMenuItem(value: 'operational', child: Text('Серверы, SMS и IT-инфраструктура')),
                                  DropdownMenuItem(value: 'agency_payout', child: Text('Выплата турагентству')),
                                  DropdownMenuItem(value: 'other_expense', child: Text('Прочие расходы платформы')),
                                ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => category = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Название
                    Text('Название проводки', style: AppText.work(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        hintText: isIncome ? 'Например: Рекламный контракт с Отелем' : 'Например: Таргетированная реклама в Meta',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Сумма
                    Text('Сумма (₸)', style: AppText.work(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '50 000',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Описание
                    Text('Примечание / договор (необязательно)', style: AppText.work(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        hintText: 'Номер счёта или договора...',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Кнопка сохранения
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final amount = int.tryParse(amountCtrl.text.replaceAll(' ', '')) ?? 0;
                                if (titleCtrl.text.trim().isEmpty || amount <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Укажите корректное название и сумму проводки')),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);
                                final res = await ApiService.createAdminFinancialRecord(
                                  type: type,
                                  category: category,
                                  amount: amount,
                                  title: titleCtrl.text.trim(),
                                  description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  if (res != null) {
                                    _loadData();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('✓ Проводка "${res.title}" успешно сохранена!'),
                                        backgroundColor: const Color(0xFF2E7D32),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Ошибка сохранения проводки')),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isIncome ? const Color(0xFF2E7D32) : AppColors.coral,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('Внести ${isIncome ? "приход" : "расход"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
        title: const Text('Финансовый баланс платформы', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Обновить баланс',
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRecordDialog,
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Проводка', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.teal,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    children: [
                      // 1. Фильтр по периодам
                      _buildPeriodSelector(),
                      const SizedBox(height: 16),

                      // 2. Три ключевые финансовые карточки: Приход, Расход, Итог
                      _buildMainBalanceCards(),
                      const SizedBox(height: 20),

                      // 3. Динамика за 7 дней (График)
                      _buildChartSection(),
                      const SizedBox(height: 24),

                      // 4. Структура приходов
                      _buildBreakdownSection(
                        title: 'Структура приходов',
                        icon: Icons.trending_up_rounded,
                        color: const Color(0xFF2E7D32),
                        items: _summary?.incomeBreakdown ?? [],
                        total: _summary?.totalIncome ?? 0,
                      ),
                      const SizedBox(height: 20),

                      // 5. Структура расходов
                      _buildBreakdownSection(
                        title: 'Структура расходов',
                        icon: Icons.trending_down_rounded,
                        color: AppColors.coral,
                        items: _summary?.expenseBreakdown ?? [],
                        total: _summary?.totalExpense ?? 0,
                      ),
                      const SizedBox(height: 24),

                      // 6. Журнал последних операций
                      _buildTransactionsLog(),
                      const SizedBox(height: 70),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = [
      {'key': 'all', 'label': 'За всё время'},
      {'key': 'month', 'label': 'Месяц'},
      {'key': 'week', 'label': 'Неделя'},
      {'key': 'today', 'label': 'Сегодня'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((p) {
          final isSelected = _selectedPeriod == p['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(p['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedPeriod = p['key']!);
                  _loadData();
                }
              },
              selectedColor: AppColors.teal,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.ink,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isSelected ? AppColors.teal : AppColors.border),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainBalanceCards() {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Главная карточка: Чистая прибыль (Итог)
        Container(
          width: double.infinity,
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
                color: const Color(0xFF0F766E).withValues(alpha: 0.28),
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
                  const Text('ИТОГ (ЧИСТАЯ ПРИБЫЛЬ)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${s.marginPercentage}% маржинальность',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _fmtMoney(s.netProfit),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'Свободный остаток средств на счетах маркетплейса',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Две карточки: Приход и Расход
        Row(
          children: [
            // Приход
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF2E7D32), size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text('ПРИХОД', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _fmtMoney(s.totalIncome),
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                    const SizedBox(height: 4),
                    const Text('Оплаты туров + реклама', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Расход
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEBEE),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_upward_rounded, color: AppColors.coral, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text('РАСХОД', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.coral)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _fmtMoney(s.totalExpense),
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.coral),
                    ),
                    const SizedBox(height: 4),
                    const Text('Выплаты агентствам + блогеры', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartSection() {
    final points = _summary?.chartPoints ?? [];
    if (points.isEmpty) return const SizedBox.shrink();

    final maxVal = points.fold<int>(1, (max, p) => p.income > max ? p.income : max);

    return Container(
      padding: const EdgeInsets.all(18),
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
              Text('Динамика баланса (7 дней)', style: AppText.h3.copyWith(fontSize: 16)),
              Row(
                children: [
                  _legendDot(const Color(0xFF2E7D32), 'Приход'),
                  const SizedBox(width: 10),
                  _legendDot(AppColors.coral, 'Расход'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points.map((p) {
              final incRatio = (p.income / maxVal).clamp(0.08, 1.0);
              final expRatio = (p.expense / maxVal).clamp(0.08, 1.0);

              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Столбик дохода
                      Container(
                        width: 14,
                        height: 90 * incRatio,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 3),
                      // Столбик расхода
                      Container(
                        width: 14,
                        height: 90 * expRatio,
                        decoration: BoxDecoration(
                          color: AppColors.coral,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(p.date, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ],
    );
  }

  Widget _buildBreakdownSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<CategoryBreakdown> items,
    required int total,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: AppText.h3.copyWith(fontSize: 16)),
              const Spacer(),
              Text(_fmtMoney(total), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text('Нет данных за выбранный период', style: TextStyle(color: AppColors.muted, fontSize: 13))
          else
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.label, style: AppText.work(size: 13, weight: FontWeight.w600)),
                        Text('${_fmtMoney(item.amount)}  (${item.percentage}%)', style: AppText.work(size: 12, color: AppColors.ink, weight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (item.percentage / 100.0).clamp(0.02, 1.0),
                        backgroundColor: AppColors.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTransactionsLog() {
    final list = _summary?.recentTransactions ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
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
              Text('Журнал финансовых проводок', style: AppText.h3.copyWith(fontSize: 16)),
              Text('Всего: ${list.length}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 14),
          if (list.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Операции не найдены', style: TextStyle(color: AppColors.muted)),
              ),
            )
          else
            ...list.map((tx) {
              final isInc = tx.isIncome;
              final dateStr = '${tx.createdAt.day.toString().padLeft(2, '0')}.${tx.createdAt.month.toString().padLeft(2, '0')} ${tx.createdAt.hour.toString().padLeft(2, '0')}:${tx.createdAt.minute.toString().padLeft(2, '0')}';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isInc ? const Color(0xFF2E7D32) : AppColors.coral).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isInc ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: isInc ? const Color(0xFF2E7D32) : AppColors.coral,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx.title, style: AppText.sora(size: 13, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('${tx.description ?? "Транзакция"} • $dateStr', style: AppText.work(size: 11, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Text(
                      '${isInc ? "+" : "-"}${_fmtMoney(tx.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isInc ? const Color(0xFF2E7D32) : AppColors.coral,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
