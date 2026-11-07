import 'package:flutter/material.dart';

/// Модель тура, поддерживает десериализацию из REST API бэкенда Sapar (FastAPI)
/// и офлайн мок-данные.
class Tour {
  const Tour({
    required this.id,
    required this.agency,
    required this.agencyVerified,
    required this.destination,
    required this.title,
    this.category = 'Пляжный отдых',
    required this.nights,
    this.durationNights = 7,
    required this.dates,
    required this.meal,
    this.mealType = 'AI',
    this.hotelStars = 4,
    this.beachLine = 1,
    required this.departureCity,
    required this.meta,
    required this.rating,
    required this.reviewsCount,
    required this.priceFrom,
    required this.photoColor,
    this.photoUrl,
    List<String>? photoUrls,
    required this.description,
    required this.included,
    this.isActive = true,
    this.oldPrice,
    this.discountPercent = 0,
    this.isHot = false,
    this.hotUntil,
    this.seatsLeft,
    this.installmentMonths = 0,
    this.monthlyPayment,
    this.maxGuests = 4,
    this.childrenAllowed = true,
    this.amenityTags = const [],
    this.hotelName,
    this.hotelDescription,
    this.hotelPhotos = const [],
    this.hotelAmenities = const {},
    this.isPromoted = false,
    this.promotedUntil,
    this.promotionTier,
  }) : _photoUrls = photoUrls;

  final String id;
  final String agency;
  final bool agencyVerified;
  final String destination;
  final String title;
  final String category;
  final String nights;
  final int durationNights;
  final String dates;
  final String meal;
  final String mealType;
  final int hotelStars;
  final int beachLine;
  final String departureCity;
  final String meta;
  final double rating;
  final int reviewsCount;
  final int priceFrom;
  final Color photoColor;
  final String? photoUrl;
  final List<String>? _photoUrls;
  final String description;
  final List<String> included;
  final bool isActive;
  final bool isPromoted;
  final DateTime? promotedUntil;
  final String? promotionTier;

  // --- Маркетинг ---
  final int? oldPrice;          // Цена до скидки
  final int discountPercent;    // Процент скидки
  final bool isHot;             // «Горящий тур»
  final DateTime? hotUntil;     // Дедлайн горящего предложения (для таймера)
  final int? seatsLeft;         // Осталось мест
  final int installmentMonths;  // Рассрочка на N месяцев (0 = нет)
  final int? monthlyPayment;    // Платёж в месяц при рассрочке

  // --- Вместимость и фильтры ---
  final int maxGuests;          // Максимум гостей на бронь
  final bool childrenAllowed;   // Можно ли с детьми
  final List<String> amenityTags; // Теги удобств: all_inclusive, beach_first_line, ...

  // --- Карточка отеля (заполняет турагентство) ---
  // hotelStars объявлена выше (общее поле со звёздностью)
  final String? hotelName;
  final String? hotelDescription;
  final List<String> hotelPhotos;
  final Map<String, List<String>> hotelAmenities; // {"Для детей": [...], ...}

  bool get hasHotelInfo => (hotelName != null && hotelName!.isNotEmpty) ||
      hotelDescription != null || hotelAmenities.isNotEmpty;

  bool get hasDiscount => oldPrice != null && oldPrice! > priceFrom;
  String? get oldPriceFormatted => oldPrice != null ? '${_formatThousands(oldPrice!)} ₸' : null;
  String? get monthlyFormatted => monthlyPayment != null ? '${_formatThousands(monthlyPayment!)} ₸' : null;

  /// Список всех фото тура (если передан photoUrls — используем его,
  /// иначе оборачиваем одиночный photoUrl, либо пустой список).
  List<String> get photoUrls {
    if (_photoUrls != null && _photoUrls.isNotEmpty) {
      return _photoUrls;
    }
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return [photoUrl!];
    }
    return const [];
  }

  /// Главное превью-фото тура.
  String? get primaryPhotoUrl {
    final list = photoUrls;
    return list.isNotEmpty ? list.first : photoUrl;
  }

  String get priceFormatted => '${_formatThousands(priceFrom)} ₸';

  static String _formatThousands(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  static Color _parseColor(dynamic colorValue) {
    if (colorValue is int) return Color(colorValue);
    if (colorValue is String) {
      var hex = colorValue.replaceAll('#', '').replaceAll('0x', '').replaceAll('0X', '');
      if (hex.length == 6) hex = 'FF$hex';
      final val = int.tryParse(hex, radix: 16);
      if (val != null) return Color(val);
    }
    return const Color(0xFF0E7C77);
  }

  factory Tour.fromJson(Map<String, dynamic> json) {
    // Извлекаем список фото
    List<String> urls = [];
    if (json['photoUrls'] is List) {
      urls = (json['photoUrls'] as List).map((e) => e.toString()).toList();
    } else if (json['photo_urls'] is List) {
      urls = (json['photo_urls'] as List).map((e) => e.toString()).toList();
    }
    final singleUrl = json['photoUrl'] as String? ?? json['photo_url'] as String?;
    if (urls.isEmpty && singleUrl != null && singleUrl.isNotEmpty) {
      urls = [singleUrl];
    }

    return Tour(
      id: json['id'] as String? ?? '',
      agency: json['agency'] as String? ?? 'Турагентство',
      agencyVerified: json['agencyVerified'] as bool? ?? json['agency_verified'] as bool? ?? false,
      destination: json['destination'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'Пляжный отдых',
      nights: json['nights'] as String? ?? '',
      durationNights: (json['durationNights'] as num? ?? json['duration_nights'] as num?)?.toInt() ?? 7,
      dates: json['dates'] as String? ?? '',
      meal: json['meal'] as String? ?? '',
      mealType: json['mealType'] as String? ?? json['meal_type'] as String? ?? 'AI',
      hotelStars: (json['hotelStars'] as num? ?? json['hotel_stars'] as num?)?.toInt() ?? 4,
      beachLine: (json['beachLine'] as num? ?? json['beach_line'] as num?)?.toInt() ?? 1,
      departureCity: json['departureCity'] as String? ?? json['departure_city'] as String? ?? 'Алматы',
      meta: json['meta'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewsCount: (json['reviewsCount'] as num? ?? json['reviews_count'] as num?)?.toInt() ?? 0,
      priceFrom: (json['priceFrom'] as num? ?? json['price_from'] as num?)?.toInt() ?? 0,
      photoColor: _parseColor(json['photoColor'] ?? json['photo_color']),
      photoUrl: singleUrl,
      photoUrls: urls,
      description: json['description'] as String? ?? '',
      included: (json['included'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      oldPrice: (json['oldPrice'] as num? ?? json['old_price'] as num?)?.toInt(),
      discountPercent: (json['discountPercent'] as num? ?? json['discount_percent'] as num?)?.toInt() ?? 0,
      isHot: json['isHot'] as bool? ?? json['is_hot'] as bool? ?? false,
      hotUntil: _parseDate(json['hotUntil'] ?? json['hot_until']),
      seatsLeft: (json['seatsLeft'] as num? ?? json['seats_left'] as num?)?.toInt(),
      installmentMonths: (json['installmentMonths'] as num? ?? json['installment_months'] as num?)?.toInt() ?? 0,
      monthlyPayment: (json['monthlyPayment'] as num? ?? json['monthly_payment'] as num?)?.toInt(),
      maxGuests: (json['maxGuests'] as num? ?? json['max_guests'] as num?)?.toInt() ?? 4,
      childrenAllowed: json['childrenAllowed'] as bool? ?? json['children_allowed'] as bool? ?? true,
      amenityTags: _parseStringList(json['amenityTags'] ?? json['amenity_tags']),
      hotelName: json['hotelName'] as String? ?? json['hotel_name'] as String?,
      hotelDescription: json['hotelDescription'] as String? ?? json['hotel_description'] as String?,
      hotelPhotos: _parseStringList(json['hotelPhotos'] ?? json['hotel_photos']),
      hotelAmenities: _parseAmenities(json['hotelAmenities'] ?? json['hotel_amenities']),
      isPromoted: json['isPromoted'] as bool? ?? json['is_promoted'] as bool? ?? false,
      promotedUntil: json['promotedUntil'] != null
          ? DateTime.tryParse(json['promotedUntil'].toString())
          : json['promoted_until'] != null
              ? DateTime.tryParse(json['promoted_until'].toString())
              : null,
      promotionTier: json['promotionTier'] as String? ?? json['promotion_tier'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }

  static Map<String, List<String>> _parseAmenities(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(
            key.toString(),
            (val is List) ? val.map((e) => e.toString()).toList() : <String>[],
          ));
    }
    return const {};
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'agency': agency,
      'agencyVerified': agencyVerified,
      'destination': destination,
      'title': title,
      'category': category,
      'nights': nights,
      'durationNights': durationNights,
      'dates': dates,
      'meal': meal,
      'mealType': mealType,
      'hotelStars': hotelStars,
      'beachLine': beachLine,
      'departureCity': departureCity,
      'meta': meta,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'priceFrom': priceFrom,
      'photoColor': '0x${photoColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
      'photoUrl': primaryPhotoUrl,
      'photoUrls': photoUrls,
      'description': description,
      'included': included,
      'isActive': isActive,
      'isPromoted': isPromoted,
      if (promotedUntil != null) 'promotedUntil': promotedUntil!.toIso8601String(),
      if (promotionTier != null) 'promotionTier': promotionTier,
    };
  }
}

final mockTours = <Tour>[
  const Tour(
    id: 'antalya-7n',
    agency: 'Turan Travel',
    agencyVerified: true,
    destination: 'Анталия, Турция',
    title: 'Тур в Анталию',
    category: 'Пляжный отдых',
    nights: '7 ночей',
    durationNights: 7,
    dates: '12–19 окт',
    meal: 'Всё вкл.',
    mealType: 'AI',
    hotelStars: 4,
    beachLine: 1,
    departureCity: 'Алматы',
    meta: '7 ночей · вылет 12 окт · всё включено',
    rating: 4.8,
    reviewsCount: 213,
    priceFrom: 245000,
    photoColor: Color(0xFF0E7C77),
    photoUrl: 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80',
    photoUrls: [
      'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1571896349842-33c89424de2d?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80',
    ],
    description:
        'Отель 4★ на первой линии с собственным пляжем, бассейном и вечерней '
        'анимацией. Идеально для семейного отдыха и пар — 12 минут от '
        'аэропорта Антальи.',
    included: [
      'Перелёт туда–обратно',
      'Отель 4★, всё включено',
      'Трансфер аэропорт–отель',
      'Медицинская страховка',
    ],
  ),
  const Tour(
    id: 'dubai-5n',
    agency: 'Voyage Asia',
    agencyVerified: true,
    destination: 'Дубай, ОАЭ',
    title: 'Дубай Delight',
    category: 'Пляжный отдых',
    nights: '5 ночей',
    durationNights: 5,
    dates: '18–23 окт',
    meal: 'Завтраки',
    mealType: 'BB',
    hotelStars: 5,
    beachLine: 2,
    departureCity: 'Алматы',
    meta: '5 ночей · вылет 18 окт · завтраки',
    rating: 4.9,
    reviewsCount: 98,
    priceFrom: 398000,
    photoColor: Color(0xFFFF6F59),
    photoUrl: 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=1200&q=80',
    photoUrls: [
      'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1580674684081-7617fbf3d745?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1518684079-3c830dcef090?auto=format&fit=crop&w=1200&q=80',
    ],
    description:
        'Отель 5★ в центре Дубая, вид на Бурдж-Халифа, шаттл до пляжа '
        'каждый час. Подходит для первой поездки в ОАЭ.',
    included: [
      'Перелёт туда–обратно',
      'Отель 5★, завтраки',
      'Трансфер аэропорт–отель',
      'Медицинская страховка',
    ],
  ),
  const Tour(
    id: 'shymbulak-3n',
    agency: 'Nomad Explore',
    agencyVerified: true,
    destination: 'Шымбулак, Казахстан',
    title: 'Горный уикенд Шымбулак',
    category: 'Горы',
    nights: '3 ночи',
    durationNights: 3,
    dates: '20–23 нояб',
    meal: 'Завтраки',
    mealType: 'BB',
    hotelStars: 4,
    beachLine: 0,
    departureCity: 'Алматы',
    meta: '3 ночи · отель на высоте 2200м',
    rating: 4.95,
    reviewsCount: 142,
    priceFrom: 115000,
    photoColor: Color(0xFF1E3A8A),
    photoUrl: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=80',
    photoUrls: [
      'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1486870591958-9b9d0d1dda99?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=1200&q=80',
    ],
    description:
        'Уютное горное шале в ущелье Медеу с панорамным видом на пик Талгар. Включен ски-пасс на канатную дорогу и СПА-комплекс.',
    included: [
      'Проживание в шале 4★',
      'Завтраки шведский стол',
      'Ски-пасс на канатную дорогу',
      'Трансфер из аэропорта Алматы',
    ],
  ),
];
