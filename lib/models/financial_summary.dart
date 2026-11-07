class CategoryBreakdown {
  const CategoryBreakdown({
    required this.category,
    required this.label,
    required this.amount,
    required this.percentage,
  });

  final String category;
  final String label;
  final int amount;
  final double percentage;

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      category: json['category'] as String? ?? '',
      label: json['label'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FinancialChartPoint {
  const FinancialChartPoint({
    required this.date,
    required this.income,
    required this.expense,
    required this.net,
  });

  final String date;
  final int income;
  final int expense;
  final int net;

  factory FinancialChartPoint.fromJson(Map<String, dynamic> json) {
    return FinancialChartPoint(
      date: json['date'] as String? ?? '',
      income: (json['income'] as num?)?.toInt() ?? 0,
      expense: (json['expense'] as num?)?.toInt() ?? 0,
      net: (json['net'] as num?)?.toInt() ?? 0,
    );
  }
}

class FinancialRecordItem {
  const FinancialRecordItem({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.title,
    this.description,
    this.referenceId,
    required this.createdAt,
  });

  final String id;
  final String type; // "income" или "expense"
  final String category;
  final int amount;
  final String title;
  final String? description;
  final String? referenceId;
  final DateTime createdAt;

  bool get isIncome => type == 'income';

  factory FinancialRecordItem.fromJson(Map<String, dynamic> json) {
    return FinancialRecordItem(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'income',
      category: json['category'] as String? ?? 'other',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      referenceId: json['referenceId'] as String? ?? json['reference_id'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class FinancialSummary {
  const FinancialSummary({
    required this.period,
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfit,
    required this.marginPercentage,
    required this.incomeBreakdown,
    required this.expenseBreakdown,
    required this.chartPoints,
    required this.recentTransactions,
  });

  final String period;
  final int totalIncome;
  final int totalExpense;
  final int netProfit;
  final double marginPercentage;
  final List<CategoryBreakdown> incomeBreakdown;
  final List<CategoryBreakdown> expenseBreakdown;
  final List<FinancialChartPoint> chartPoints;
  final List<FinancialRecordItem> recentTransactions;

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    final listInc = json['incomeBreakdown'] as List<dynamic>? ?? json['income_breakdown'] as List<dynamic>? ?? [];
    final listExp = json['expenseBreakdown'] as List<dynamic>? ?? json['expense_breakdown'] as List<dynamic>? ?? [];
    final listPts = json['chartPoints'] as List<dynamic>? ?? json['chart_points'] as List<dynamic>? ?? [];
    final listTx = json['recentTransactions'] as List<dynamic>? ?? json['recent_transactions'] as List<dynamic>? ?? [];

    return FinancialSummary(
      period: json['period'] as String? ?? 'all',
      totalIncome: (json['totalIncome'] as num? ?? json['total_income'] as num?)?.toInt() ?? 0,
      totalExpense: (json['totalExpense'] as num? ?? json['total_expense'] as num?)?.toInt() ?? 0,
      netProfit: (json['netProfit'] as num? ?? json['net_profit'] as num?)?.toInt() ?? 0,
      marginPercentage: (json['marginPercentage'] as num? ?? json['margin_percentage'] as num?)?.toDouble() ?? 0.0,
      incomeBreakdown: listInc.map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>)).toList(),
      expenseBreakdown: listExp.map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>)).toList(),
      chartPoints: listPts.map((e) => FinancialChartPoint.fromJson(e as Map<String, dynamic>)).toList(),
      recentTransactions: listTx.map((e) => FinancialRecordItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
