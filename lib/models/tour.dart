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
    required this.dates,
    required this.meal,
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
  }) : _photoUrls = photoUrls;

  final String id;
  final String agency;
  final bool agencyVerified;
  final String destination;
  final String title;
  final String category;
  final String nights;
  final String dates;
  final String meal;
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
      dates: json['dates'] as String? ?? '',
      meal: json['meal'] as String? ?? '',
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
    );
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
      'dates': dates,
      'meal': meal,
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
    dates: '12–19 окт',
    meal: 'Всё вкл.',
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
    dates: '18–23 окт',
    meal: 'Завтраки',
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
    dates: '20–23 нояб',
    meal: 'Завтраки',
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
