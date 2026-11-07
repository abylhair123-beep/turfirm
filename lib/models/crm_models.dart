class CallQueueItem {
  final String id;
  final String targetType; // 'customer' or 'agency'
  final String targetName;
  final String targetPhone;
  final String? tourTitle;
  final String? bookingId;
  final String? bookingStatus;
  final int? totalPrice;
  final String priority; // 'callback', 'high', 'normal'
  final DateTime? lastCallAt;
  final String? lastCallStatus;
  final String? lastCallNotes;
  final DateTime? scheduledCallbackAt;
  final String reason;

  const CallQueueItem({
    required this.id,
    required this.targetType,
    required this.targetName,
    required this.targetPhone,
    this.tourTitle,
    this.bookingId,
    this.bookingStatus,
    this.totalPrice,
    required this.priority,
    this.lastCallAt,
    this.lastCallStatus,
    this.lastCallNotes,
    this.scheduledCallbackAt,
    required this.reason,
  });

  factory CallQueueItem.fromJson(Map<String, dynamic> json) {
    return CallQueueItem(
      id: json['id'] as String? ?? '',
      targetType: json['target_type'] as String? ?? 'customer',
      targetName: json['target_name'] as String? ?? 'Клиент',
      targetPhone: json['target_phone'] as String? ?? '',
      tourTitle: json['tour_title'] as String?,
      bookingId: json['booking_id'] as String?,
      bookingStatus: json['booking_status'] as String?,
      totalPrice: json['total_price'] as int?,
      priority: json['priority'] as String? ?? 'normal',
      lastCallAt: json['last_call_at'] != null ? DateTime.tryParse(json['last_call_at'] as String) : null,
      lastCallStatus: json['last_call_status'] as String?,
      lastCallNotes: json['last_call_notes'] as String?,
      scheduledCallbackAt: json['scheduled_callback_at'] != null
          ? DateTime.tryParse(json['scheduled_callback_at'] as String)
          : null,
      reason: json['reason'] as String? ?? 'Обзвон',
    );
  }
}

class CallLogItem {
  final String id;
  final String direction; // 'outbound', 'inbound'
  final String targetType;
  final String targetName;
  final String targetPhone;
  final String? bookingId;
  final String? managerName;
  final String? tourTitle;
  final String status; // 'successful', 'callback_needed', 'no_answer', 'busy', 'wrong_number', 'declined'
  final int durationSeconds;
  final String? notes;
  final DateTime? scheduledCallbackAt;
  final String telephonyProvider;
  final String? recordingUrl;
  final DateTime createdAt;

  const CallLogItem({
    required this.id,
    required this.direction,
    required this.targetType,
    required this.targetName,
    required this.targetPhone,
    this.bookingId,
    this.managerName,
    this.tourTitle,
    required this.status,
    required this.durationSeconds,
    this.notes,
    this.scheduledCallbackAt,
    required this.telephonyProvider,
    this.recordingUrl,
    required this.createdAt,
  });

  factory CallLogItem.fromJson(Map<String, dynamic> json) {
    return CallLogItem(
      id: json['id'] as String? ?? '',
      direction: json['direction'] as String? ?? 'outbound',
      targetType: json['target_type'] as String? ?? 'customer',
      targetName: json['target_name'] as String? ?? 'Абонент',
      targetPhone: json['target_phone'] as String? ?? '',
      bookingId: json['booking_id'] as String?,
      managerName: json['manager_name'] as String?,
      tourTitle: json['tour_title'] as String?,
      status: json['status'] as String? ?? 'successful',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String?,
      scheduledCallbackAt: json['scheduled_callback_at'] != null
          ? DateTime.tryParse(json['scheduled_callback_at'] as String)
          : null,
      telephonyProvider: json['telephony_provider'] as String? ?? 'manual',
      recordingUrl: json['recording_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get formattedDuration {
    if (durationSeconds <= 0) return '0 сек';
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    if (minutes == 0) return '$seconds сек';
    return '$minutes мин $seconds сек';
  }
}

class CallStats {
  final int totalCalls;
  final int callsToday;
  final int successfulCalls;
  final double answerRatePct;
  final int avgDurationSeconds;
  final int pendingCallbacksCount;
  final Map<String, int> statusBreakdown;

  const CallStats({
    required this.totalCalls,
    required this.callsToday,
    required this.successfulCalls,
    required this.answerRatePct,
    required this.avgDurationSeconds,
    required this.pendingCallbacksCount,
    required this.statusBreakdown,
  });

  factory CallStats.fromJson(Map<String, dynamic> json) {
    final rawBreakdown = json['status_breakdown'] as Map<String, dynamic>? ?? {};
    final statusMap = rawBreakdown.map((k, v) => MapEntry(k, (v as num).toInt()));

    return CallStats(
      totalCalls: (json['total_calls'] as num?)?.toInt() ?? 0,
      callsToday: (json['calls_today'] as num?)?.toInt() ?? 0,
      successfulCalls: (json['successful_calls'] as num?)?.toInt() ?? 0,
      answerRatePct: (json['answer_rate_pct'] as num?)?.toDouble() ?? 0.0,
      avgDurationSeconds: (json['avg_duration_seconds'] as num?)?.toInt() ?? 0,
      pendingCallbacksCount: (json['pending_callbacks_count'] as num?)?.toInt() ?? 0,
      statusBreakdown: statusMap,
    );
  }
}
