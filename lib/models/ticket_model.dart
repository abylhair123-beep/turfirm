class TicketFlight {
  final String id;
  final String transportType; // 'flight' or 'train'
  final String carrierName;
  final String carrierCode;
  final String flightNumber;
  final String departureCity;
  final String arrivalCity;
  final String departureAirport;
  final String arrivalAirport;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final int durationMinutes;
  final bool isDirect;
  final int stopsCount;
  final bool baggageIncluded;
  final int baggageWeightKg;
  final int handLuggageKg;
  final String seatClass;
  final int price;
  final int availableSeats;
  final String? aircraftOrTrainModel;
  final String provider;

  const TicketFlight({
    required this.id,
    required this.transportType,
    required this.carrierName,
    required this.carrierCode,
    required this.flightNumber,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureAirport,
    required this.arrivalAirport,
    required this.departureTime,
    required this.arrivalTime,
    required this.durationMinutes,
    required this.isDirect,
    required this.stopsCount,
    required this.baggageIncluded,
    required this.baggageWeightKg,
    required this.handLuggageKg,
    required this.seatClass,
    required this.price,
    required this.availableSeats,
    this.aircraftOrTrainModel,
    required this.provider,
  });

  factory TicketFlight.fromJson(Map<String, dynamic> json) {
    return TicketFlight(
      id: json['id'] as String? ?? '',
      transportType: json['transport_type'] as String? ?? 'flight',
      carrierName: json['carrier_name'] as String? ?? 'Авиалинии',
      carrierCode: json['carrier_code'] as String? ?? '',
      flightNumber: json['flight_number'] as String? ?? '',
      departureCity: json['departure_city'] as String? ?? '',
      arrivalCity: json['arrival_city'] as String? ?? '',
      departureAirport: json['departure_airport'] as String? ?? '',
      arrivalAirport: json['arrival_airport'] as String? ?? '',
      departureTime: json['departure_time'] != null
          ? DateTime.tryParse(json['departure_time'] as String) ?? DateTime.now()
          : DateTime.now(),
      arrivalTime: json['arrival_time'] != null
          ? DateTime.tryParse(json['arrival_time'] as String) ?? DateTime.now()
          : DateTime.now(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      isDirect: json['is_direct'] as bool? ?? true,
      stopsCount: (json['stops_count'] as num?)?.toInt() ?? 0,
      baggageIncluded: json['baggage_included'] as bool? ?? true,
      baggageWeightKg: (json['baggage_weight_kg'] as num?)?.toInt() ?? 20,
      handLuggageKg: (json['hand_luggage_kg'] as num?)?.toInt() ?? 8,
      seatClass: json['seat_class'] as String? ?? 'economy',
      price: (json['price'] as num?)?.toInt() ?? 0,
      availableSeats: (json['available_seats'] as num?)?.toInt() ?? 0,
      aircraftOrTrainModel: json['aircraft_or_train_model'] as String?,
      provider: json['provider'] as String? ?? 'sapar_charter',
    );
  }

  String get departureTimeFormatted {
    final h = departureTime.hour.toString().padLeft(2, '0');
    final m = departureTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get arrivalTimeFormatted {
    final h = arrivalTime.hour.toString().padLeft(2, '0');
    final m = arrivalTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get durationFormatted {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h == 0) return '$m мин';
    if (m == 0) return '$h ч';
    return '$h ч $m мин';
  }

  String get departureDateFormatted {
    final d = departureTime.day.toString().padLeft(2, '0');
    final m = departureTime.month.toString().padLeft(2, '0');
    return '$d.$m';
  }

  bool get isFlight => transportType == 'flight';
  bool get isTrain => transportType == 'train';
}

class TicketBooking {
  final String id;
  final String flightId;
  final TicketFlight? flight;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String documentNumber;
  final int passengersCount;
  final int totalPrice;
  final String paymentMethod;
  final String status;
  final String ticketNumber;
  final String? pnrCode;
  final String? seatNumbers;
  final DateTime createdAt;

  const TicketBooking({
    required this.id,
    required this.flightId,
    this.flight,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.documentNumber,
    required this.passengersCount,
    required this.totalPrice,
    required this.paymentMethod,
    required this.status,
    required this.ticketNumber,
    this.pnrCode,
    this.seatNumbers,
    required this.createdAt,
  });

  factory TicketBooking.fromJson(Map<String, dynamic> json) {
    return TicketBooking(
      id: json['id'] as String? ?? '',
      flightId: json['flight_id'] as String? ?? '',
      flight: json['flight'] != null ? TicketFlight.fromJson(json['flight'] as Map<String, dynamic>) : null,
      customerName: json['customer_name'] as String? ?? '',
      customerPhone: json['customer_phone'] as String? ?? '',
      customerEmail: json['customer_email'] as String? ?? '',
      documentNumber: json['document_number'] as String? ?? '',
      passengersCount: (json['passengers_count'] as num?)?.toInt() ?? 1,
      totalPrice: (json['total_price'] as num?)?.toInt() ?? 0,
      paymentMethod: json['payment_method'] as String? ?? 'Kaspi Pay',
      status: json['status'] as String? ?? 'paid',
      ticketNumber: json['ticket_number'] as String? ?? '',
      pnrCode: json['pnr_code'] as String? ?? json['ticket_number'] as String? ?? '',
      seatNumbers: json['seat_numbers'] as String? ?? json['seat_number'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get seatNumber => seatNumbers ?? '';
  String get statusLabel {
    switch (status) {
      case 'confirmed':
      case 'paid':
        return 'Подтверждён';
      case 'cancelled':
        return 'Отменён';
      default:
        return 'Оформлен';
    }
  }
}

class CityOption {
  final String city;
  final String airportCode;
  final String country;
  final bool isPopular;

  const CityOption({
    required this.city,
    required this.airportCode,
    required this.country,
    this.isPopular = false,
  });

  factory CityOption.fromJson(Map<String, dynamic> json) {
    return CityOption(
      city: json['city'] as String? ?? '',
      airportCode: json['airport_code'] as String? ?? '',
      country: json['country'] as String? ?? '',
      isPopular: json['is_popular'] as bool? ?? false,
    );
  }
}
