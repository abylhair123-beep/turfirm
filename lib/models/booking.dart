class BookingRequest {
  const BookingRequest({
    required this.tourId,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.guestsCount,
    required this.paymentMethod,
  });

  final String tourId;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final int guestsCount;
  final String paymentMethod;

  Map<String, dynamic> toJson() {
    return {
      'tourId': tourId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'guestsCount': guestsCount,
      'paymentMethod': paymentMethod,
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
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
