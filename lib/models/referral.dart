class ReferralCampaign {
  const ReferralCampaign({
    required this.id,
    required this.userId,
    required this.code,
    required this.campaignName,
    required this.commissionRate,
    required this.fixedReward,
    required this.clicksCount,
    required this.bookingsCount,
    required this.totalEarned,
    required this.balance,
    required this.referralUrl,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String code;
  final String campaignName;
  final double commissionRate;
  final int fixedReward;
  final int clicksCount;
  final int bookingsCount;
  final int totalEarned;
  final int balance;
  final String referralUrl;
  final bool isActive;
  final DateTime createdAt;

  factory ReferralCampaign.fromJson(Map<String, dynamic> json) {
    return ReferralCampaign(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      campaignName: json['campaignName'] as String? ?? json['campaign_name'] as String? ?? 'Основная кампания',
      commissionRate: (json['commissionRate'] as num? ?? json['commission_rate'] as num?)?.toDouble() ?? 3.0,
      fixedReward: (json['fixedReward'] as num? ?? json['fixed_reward'] as num?)?.toInt() ?? 0,
      clicksCount: (json['clicksCount'] as num? ?? json['clicks_count'] as num?)?.toInt() ?? 0,
      bookingsCount: (json['bookingsCount'] as num? ?? json['bookings_count'] as num?)?.toInt() ?? 0,
      totalEarned: (json['totalEarned'] as num? ?? json['total_earned'] as num?)?.toInt() ?? 0,
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      referralUrl: json['referralUrl'] as String? ?? json['referral_url'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'code': code,
      'campaignName': campaignName,
      'commissionRate': commissionRate,
      'fixedReward': fixedReward,
      'clicksCount': clicksCount,
      'bookingsCount': bookingsCount,
      'totalEarned': totalEarned,
      'balance': balance,
      'referralUrl': referralUrl,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class ReferralBookingItem {
  const ReferralBookingItem({
    required this.id,
    required this.bookingId,
    required this.tourTitle,
    required this.customerName,
    required this.tourPrice,
    required this.reward,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String bookingId;
  final String tourTitle;
  final String customerName;
  final int tourPrice;
  final int reward;
  final String status;
  final DateTime createdAt;

  factory ReferralBookingItem.fromJson(Map<String, dynamic> json) {
    return ReferralBookingItem(
      id: json['id'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? json['booking_id'] as String? ?? '',
      tourTitle: json['tourTitle'] as String? ?? json['tour_title'] as String? ?? 'Тур Sapar',
      customerName: json['customerName'] as String? ?? json['customer_name'] as String? ?? 'Турист',
      tourPrice: (json['tourPrice'] as num? ?? json['tour_price'] as num?)?.toInt() ?? 0,
      reward: (json['reward'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'paid',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ReferralStats {
  const ReferralStats({
    required this.totalClicks,
    required this.totalBookings,
    required this.conversionRate,
    required this.totalEarned,
    required this.balance,
    required this.campaigns,
    required this.recentBookings,
  });

  final int totalClicks;
  final int totalBookings;
  final double conversionRate;
  final int totalEarned;
  final int balance;
  final List<ReferralCampaign> campaigns;
  final List<ReferralBookingItem> recentBookings;

  factory ReferralStats.fromJson(Map<String, dynamic> json) {
    final listCamps = json['campaigns'] as List<dynamic>? ?? [];
    final listBookings = json['recentBookings'] as List<dynamic>? ?? json['recent_bookings'] as List<dynamic>? ?? [];

    return ReferralStats(
      totalClicks: (json['totalClicks'] as num? ?? json['total_clicks'] as num?)?.toInt() ?? 0,
      totalBookings: (json['totalBookings'] as num? ?? json['total_bookings'] as num?)?.toInt() ?? 0,
      conversionRate: (json['conversionRate'] as num? ?? json['conversion_rate'] as num?)?.toDouble() ?? 0.0,
      totalEarned: (json['totalEarned'] as num? ?? json['total_earned'] as num?)?.toInt() ?? 0,
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      campaigns: listCamps.map((e) => ReferralCampaign.fromJson(e as Map<String, dynamic>)).toList(),
      recentBookings: listBookings.map((e) => ReferralBookingItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ReferralCheckResult {
  const ReferralCheckResult({
    required this.valid,
    required this.code,
    this.campaignName,
    this.bloggerName,
    this.discountPercent = 3.0,
    required this.message,
  });

  final bool valid;
  final String code;
  final String? campaignName;
  final String? bloggerName;
  final double discountPercent;
  final String message;

  factory ReferralCheckResult.fromJson(Map<String, dynamic> json) {
    return ReferralCheckResult(
      valid: json['valid'] as bool? ?? false,
      code: json['code'] as String? ?? '',
      campaignName: json['campaignName'] as String? ?? json['campaign_name'] as String?,
      bloggerName: json['bloggerName'] as String? ?? json['blogger_name'] as String?,
      discountPercent: (json['discountPercent'] as num? ?? json['discount_percent'] as num?)?.toDouble() ?? 3.0,
      message: json['message'] as String? ?? '',
    );
  }
}
