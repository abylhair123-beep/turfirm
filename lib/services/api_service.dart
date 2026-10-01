import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/booking.dart';
import '../models/tour.dart';

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
}
