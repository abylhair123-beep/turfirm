import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/booking.dart';
import '../models/tour.dart';

class PaymentResponseData {
  const PaymentResponseData({
    required this.paymentId,
    required this.bookingId,
    required this.amount,
    required this.provider,
    required this.status,
    this.paymentUrl,
    this.qrCodeData,
    this.qrCodeUrl,
  });

  final String paymentId;
  final String bookingId;
  final int amount;
  final String provider;
  final String status;
  final String? paymentUrl;
  final String? qrCodeData;
  final String? qrCodeUrl;

  factory PaymentResponseData.fromJson(Map<String, dynamic> json) {
    return PaymentResponseData(
      paymentId: json['paymentId'] as String? ?? json['payment_id'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? json['booking_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      provider: json['provider'] as String? ?? 'kaspi',
      status: json['status'] as String? ?? 'pending',
      paymentUrl: json['paymentUrl'] as String? ?? json['payment_url'] as String?,
      qrCodeData: json['qrCodeData'] as String? ?? json['qr_code_data'] as String?,
      qrCodeUrl: json['qrCodeUrl'] as String? ?? json['qr_code_url'] as String?,
    );
  }
}

class ApiService {
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api/v1';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api/v1';
      }
    } catch (_) {
      // Platform not supported or web
    }
    return 'http://localhost:8000/api/v1';
  }

  static String baseUrl = defaultBaseUrl;

  /// Получение каталога туров с поддержкой фильтрации по категории и поисковому запросу.
  /// В случае недоступности бэкенда плавно возвращает локальные мок-данные.
  static Future<List<Tour>> getTours({
    String? category,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (category != null && category.isNotEmpty && category != 'Все') {
        queryParams['category'] = category;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final uri = Uri.parse('$baseUrl/tours').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        final tours = decoded.map((item) => Tour.fromJson(item as Map<String, dynamic>)).toList();
        if (tours.isNotEmpty) {
          return tours;
        }
      }
    } catch (e) {
      debugPrint('[ApiService] Backend unavailable ($e), using local mock data fallback.');
    }

    // Офлайн-фоллбек на mockTours
    var filtered = List<Tour>.from(mockTours);
    if (category != null && category.isNotEmpty && category != 'Все') {
      filtered = filtered.where((t) => t.category == category).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      filtered = filtered.where((t) {
        return t.title.toLowerCase().contains(q) ||
            t.destination.toLowerCase().contains(q) ||
            t.agency.toLowerCase().contains(q);
      }).toList();
    }
    return filtered;
  }

  /// Создание бронирования через API
  static Future<BookingResult> createBooking(BookingRequest request) async {
    try {
      final uri = Uri.parse('$baseUrl/bookings');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return BookingResult.fromJson(data);
      }
    } catch (e) {
      debugPrint('[ApiService] Booking API error ($e), fallback to local confirmation.');
    }

    // Фоллбек при недоступности сети
    return BookingResult(
      id: 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      tourId: request.tourId,
      agencyId: 'agency-fallback',
      customerName: request.customerName,
      customerPhone: request.customerPhone,
      customerEmail: request.customerEmail,
      guestsCount: request.guestsCount,
      paymentMethod: request.paymentMethod,
      tourPrice: 245000,
      serviceFee: 9800,
      totalPrice: (245000 * request.guestsCount) + 9800,
      status: 'paid',
      createdAt: DateTime.now(),
    );
  }

  /// Инициализация платежа через Kaspi Pay / Карту / Halyk Bank
  static Future<PaymentResponseData?> initiatePayment({
    required String bookingId,
    required String paymentMethod,
    String? customerPhone,
    String? customerEmail,
    String? customerName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/payments/initiate');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'bookingId': bookingId,
              'paymentMethod': paymentMethod,
              'customerPhone': customerPhone,
              'customerEmail': customerEmail,
              'customerName': customerName,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return PaymentResponseData.fromJson(data);
      }
    } catch (e) {
      debugPrint('[ApiService] Payment initiation error: $e');
    }
    return null;
  }

  /// Подтверждение платежа
  static Future<bool> confirmPayment(String paymentId) async {
    try {
      final uri = Uri.parse('$baseUrl/payments/$paymentId/confirm');
      final response = await http.post(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] Payment confirmation error: $e');
      return false;
    }
  }

  // ========================= Панель агентства =========================

  /// Вход турагентства/админа. Возвращает access_token или null при ошибке.
  static Future<String?> login(String email, String password) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/login');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data['access_token'] as String?;
      }
      debugPrint('[ApiService] Login failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('[ApiService] Login error: $e');
    }
    return null;
  }

  /// MIME-тип картинки по расширению имени файла.
  static MediaType _imageMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    return MediaType('image', 'jpeg');
  }

  /// Загрузка изображения на бэкенд. Возвращает публичный URL файла или null.
  /// Работает и в вебе, и на мобильных — отправляем байты.
  static Future<String?> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String token,
    String folder = 'tours',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/uploads').replace(queryParameters: {'folder': folder});
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: _imageMediaType(filename),
        ),
      );

      final streamed = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data['url'] as String?;
      }
      debugPrint('[ApiService] Upload failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('[ApiService] Upload error: $e');
    }
    return null;
  }

  /// Создание тура (нужен токен агентства). Возвращает созданный Tour или null.
  static Future<Tour?> createTour({
    required Map<String, dynamic> data,
    required String token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/tours');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return Tour.fromJson(json);
      }
      debugPrint('[ApiService] Create tour failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('[ApiService] Create tour error: $e');
    }
    return null;
  }
}
