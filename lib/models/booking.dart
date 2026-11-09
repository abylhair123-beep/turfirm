class BookingRequest {
  const BookingRequest({
    required this.tourId,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.guestsCount,
    required this.paymentMethod,
    this.referralCode,
    this.termsAccepted = true,
  });

  final String tourId;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final int guestsCount;
  final String paymentMethod;
  final String? referralCode;
  final bool termsAccepted;

  Map<String, dynamic> toJson() {
    return {
      'tourId': tourId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'guestsCount': guestsCount,
      'paymentMethod': paymentMethod,
      'termsAccepted': termsAccepted,
      if (referralCode != null && referralCode!.trim().isNotEmpty)
        'referralCode': referralCode!.trim().toUpperCase(),
    };
  }
}

class BookingResult {
  const BookingResult({
    required this.id,
    required this.tourId,
    required this.agencyId,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.guestsCount,
    required this.paymentMethod,
    required this.tourPrice,
    required this.serviceFee,
    required this.totalPrice,
    required this.status,
    this.referralCode,
    this.referralReward = 0,
    this.tourCode,
    this.termsAccepted = true,
    required this.createdAt,
  });

  final String id;
  final String tourId;
  final String agencyId;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final int guestsCount;
  final String paymentMethod;
  final int tourPrice;
  final int serviceFee;
  final int totalPrice;
  final String status;
  final String? referralCode;
  final int referralReward;
  final String? tourCode;
  final bool termsAccepted;
  final DateTime createdAt;

  factory BookingResult.fromJson(Map<String, dynamic> json) {
    return BookingResult(
      id: json['id'] as String? ?? '',
      tourId: json['tourId'] as String? ?? json['tour_id'] as String? ?? '',
      agencyId: json['agencyId'] as String? ?? json['agency_id'] as String? ?? '',
      customerName: json['customerName'] as String? ?? json['customer_name'] as String? ?? '',
      customerPhone: json['customerPhone'] as String? ?? json['customer_phone'] as String? ?? '',
      customerEmail: json['customerEmail'] as String? ?? json['customer_email'] as String? ?? '',
      guestsCount: (json['guestsCount'] as num? ?? json['guests_count'] as num?)?.toInt() ?? 1,
      paymentMethod: json['paymentMethod'] as String? ?? json['payment_method'] as String? ?? 'Kaspi Pay',
      tourPrice: (json['tourPrice'] as num? ?? json['tour_price'] as num?)?.toInt() ?? 0,
      serviceFee: (json['serviceFee'] as num? ?? json['service_fee'] as num?)?.toInt() ?? 9800,
      totalPrice: (json['totalPrice'] as num? ?? json['total_price'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'paid',
      referralCode: json['referralCode'] as String? ?? json['referral_code'] as String?,
      referralReward: (json['referralReward'] as num? ?? json['referral_reward'] as num?)?.toInt() ?? 0,
      tourCode: json['tourCode'] as String? ?? json['tour_code'] as String?,
      termsAccepted: json['termsAccepted'] as bool? ?? json['terms_accepted'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

typedef Booking = BookingResult;
