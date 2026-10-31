import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking.dart';
import '../models/review.dart';
import '../models/tour.dart';
import '../models/user.dart';

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
      provider: json['provider'] as String? ?? 'Kaspi Pay',
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
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : '192.168.10.12';
      return 'http://$host:8000/api/v1';
    }
    return 'http://192.168.10.12:8000/api/v1';
  }

  static String baseUrl = defaultBaseUrl;

  // Сессия и токен
  static String? _token;
  static AppUser? _currentUser;
  static bool hasSeenOnboarding = false;
  static final Set<String> _localFavoriteIds = {};
  static final ValueNotifier<AppUser?> userNotifier = ValueNotifier<AppUser?>(null);
  static final ValueNotifier<Set<String>> favoritesNotifier = ValueNotifier<Set<String>>({});

  static String? get token => _token;
  static AppUser? get currentUser => _currentUser;
  static bool get isLoggedIn => _token != null && _currentUser != null;

  /// Инициализация сохраненной сессии при старте
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
      _token = prefs.getString('auth_token');
      final userJson = prefs.getString('auth_user');
      if (userJson != null) {
        _currentUser = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        userNotifier.value = _currentUser;
      }
      final favList = prefs.getStringList('local_favorites') ?? [];
      _localFavoriteIds.addAll(favList);
      favoritesNotifier.value = Set.from(_localFavoriteIds);
    } catch (e) {
      debugPrint('[ApiService] Init error: $e');
    }
  }

  static Future<void> markOnboardingSeen() async {
    hasSeenOnboarding = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);
    } catch (_) {}
  }

  static Map<String, String> _headers({bool withAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (withAuth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // ==================== АУТЕНТИФИКАЦИЯ ====================

  /// Вход по логину и паролю
  static Future<AppUser?> login(String email, String password) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/login');
      final response = await http
          .post(
            uri,
            headers: _headers(withAuth: false),
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        _token = data['access_token'] as String?;
        _currentUser = AppUser(
          id: data['user_id'] as String? ?? '',
          email: data['email'] as String? ?? email,
          fullName: data['full_name'] as String? ?? 'Пользователь',
          role: data['role'] as String? ?? 'client',
        );
        userNotifier.value = _currentUser;

        final prefs = await SharedPreferences.getInstance();
        if (_token != null) await prefs.setString('auth_token', _token!);
        await prefs.setString('auth_user', jsonEncode(_currentUser!.toJson()));

        await syncFavorites();
        return _currentUser;
      }
    } catch (e) {
      debugPrint('[ApiService] Login error: $e');
    }
    return null;
  }

  /// Регистрация нового аккаунта
  static Future<AppUser?> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String role = 'client',
    String? agencyName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/register');
      final response = await http
          .post(
            uri,
            headers: _headers(withAuth: false),
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
              'full_name': fullName.trim(),
              'phone': phone?.trim(),
              'role': role,
              'agency_name': agencyName?.trim(),
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        _token = data['access_token'] as String?;
        _currentUser = AppUser(
          id: data['user_id'] as String? ?? '',
          email: data['email'] as String? ?? email,
          fullName: data['full_name'] as String? ?? fullName,
          phone: phone,
          role: data['role'] as String? ?? role,
        );
        userNotifier.value = _currentUser;

        final prefs = await SharedPreferences.getInstance();
        if (_token != null) await prefs.setString('auth_token', _token!);
        await prefs.setString('auth_user', jsonEncode(_currentUser!.toJson()));

        return _currentUser;
      }
    } catch (e) {
      debugPrint('[ApiService] Register error: $e');
    }
    return null;
  }

  /// Получение профиля текущего пользователя
  static Future<AppUser?> refreshCurrentUser() async {
    if (_token == null) return null;
    try {
      final uri = Uri.parse('$baseUrl/auth/me');
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        _currentUser = AppUser.fromJson(data);
        userNotifier.value = _currentUser;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_user', jsonEncode(_currentUser!.toJson()));
        return _currentUser;
      }
    } catch (e) {
      debugPrint('[ApiService] refreshCurrentUser error: $e');
    }
    return _currentUser;
  }

  /// Выход из аккаунта
  static Future<void> logout() async {
    _token = null;
    _currentUser = null;
    userNotifier.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
  }

  // ==================== ТУРЫ ====================

  /// Создание тура турагентством (B2B)
  static Future<bool> createTour(Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('$baseUrl/tours');
      final response = await http
          .post(uri, headers: _headers(), body: jsonEncode(data))
          .timeout(const Duration(seconds: 6));
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] createTour error: $e');
      return true;
    }
  }

  /// Получение каталога туров с поддержкой фильтрации
  static Future<List<Tour>> getTours({
    String? category,
    String? search,
    String? departureCity,
    int? minPrice,
    int? maxPrice,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (category != null && category.isNotEmpty && category != 'Все') {
        queryParams['category'] = category;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (departureCity != null && departureCity.isNotEmpty && departureCity != 'Любой') {
        queryParams['departureCity'] = departureCity;
      }
      if (minPrice != null && minPrice > 0) {
        queryParams['minPrice'] = minPrice.toString();
      }
      if (maxPrice != null && maxPrice > 0) {
        queryParams['maxPrice'] = maxPrice.toString();
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

    // Офлайн-фоллбек
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
    if (departureCity != null && departureCity.isNotEmpty && departureCity != 'Любой') {
      filtered = filtered.where((t) => t.departureCity == departureCity).toList();
    }
    if (minPrice != null && minPrice > 0) {
      filtered = filtered.where((t) => t.priceFrom >= minPrice).toList();
    }
    if (maxPrice != null && maxPrice > 0) {
      filtered = filtered.where((t) => t.priceFrom <= maxPrice).toList();
    }
    return filtered;
  }

  // ==================== БРОНИРОВАНИЯ ====================

  /// Создание бронирования
  static Future<BookingResult> createBooking(BookingRequest request) async {
    try {
      final uri = Uri.parse('$baseUrl/bookings');
      final response = await http
          .post(
            uri,
            headers: _headers(),
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

    // Фоллбек
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

  /// Получение списка бронирований текущего пользователя
  static Future<List<BookingResult>> getMyBookings() async {
    try {
      final queryParams = <String, String>{};
      if (_currentUser?.email != null) {
        queryParams['email'] = _currentUser!.email;
      }
      final uri = Uri.parse('$baseUrl/bookings').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return list.map((item) => BookingResult.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService] getMyBookings error: $e');
    }

    // Демо-бронирования для офлайна
    return [
      BookingResult(
        id: 'BK-782109',
        tourId: 'antalya-all-inclusive-7n',
        agencyId: 'agn-turan-travel',
        customerName: _currentUser?.fullName ?? 'Айгерим Сериковна',
        customerPhone: _currentUser?.phone ?? '+7 701 234 56 78',
        customerEmail: _currentUser?.email ?? 'aigerim@mail.kz',
        guestsCount: 2,
        paymentMethod: 'Kaspi Pay',
        tourPrice: 245000,
        serviceFee: 9800,
        totalPrice: 499800,
        status: 'paid',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  // ==================== ПЛАТЕЖИ ====================

  /// Инициализация платежа (Kaspi Pay QR, Карта, Halyk)
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
            headers: _headers(withAuth: false),
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

    // Фоллбек для демонстрации в оффлайне
    return PaymentResponseData(
      paymentId: 'pay-${DateTime.now().millisecondsSinceEpoch}',
      bookingId: bookingId,
      amount: 499800,
      provider: paymentMethod,
      status: 'pending',
      qrCodeData: 'https://kaspi.kz/pay?service_id=sapar&order_id=$bookingId&amount=499800',
      paymentUrl: 'https://kaspi.kz/pay?service_id=sapar&order_id=$bookingId',
    );
  }

  /// Подтверждение платежа
  static Future<bool> confirmPayment(String paymentId) async {
    try {
      final uri = Uri.parse('$baseUrl/payments/$paymentId/confirm');
      final response = await http.post(uri, headers: _headers(withAuth: false)).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] Payment confirmation error: $e');
      return true; // для мок-режима
    }
  }

  // ==================== ИЗБРАННОЕ ====================

  static bool isFavorite(String tourId) {
    return _localFavoriteIds.contains(tourId);
  }

  static Future<void> syncFavorites() async {
    if (!isLoggedIn) return;
    try {
      final uri = Uri.parse('$baseUrl/favorites');
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        _localFavoriteIds.clear();
        for (final item in list) {
          final id = item['id'] as String?;
          if (id != null) _localFavoriteIds.add(id);
        }
        favoritesNotifier.value = Set.from(_localFavoriteIds);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('local_favorites', _localFavoriteIds.toList());
      }
    } catch (e) {
      debugPrint('[ApiService] syncFavorites error: $e');
    }
  }

  static Future<List<Tour>> getFavorites() async {
    if (isLoggedIn) {
      try {
        final uri = Uri.parse('$baseUrl/favorites');
        final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
          return list.map((item) => Tour.fromJson(item as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        debugPrint('[ApiService] getFavorites error: $e');
      }
    }
    // Из локального списка
    return mockTours.where((t) => _localFavoriteIds.contains(t.id)).toList();
  }

  static Future<bool> toggleFavorite(String tourId) async {
    final willBeFavorite = !_localFavoriteIds.contains(tourId);
    if (willBeFavorite) {
      _localFavoriteIds.add(tourId);
    } else {
      _localFavoriteIds.remove(tourId);
    }
    favoritesNotifier.value = Set.from(_localFavoriteIds);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('local_favorites', _localFavoriteIds.toList());

    if (isLoggedIn) {
      try {
        final uri = Uri.parse('$baseUrl/favorites/$tourId');
        if (willBeFavorite) {
          await http.post(uri, headers: _headers()).timeout(const Duration(seconds: 3));
        } else {
          await http.delete(uri, headers: _headers()).timeout(const Duration(seconds: 3));
        }
      } catch (e) {
        debugPrint('[ApiService] toggleFavorite remote error: $e');
      }
    }
    return willBeFavorite;
  }

  // ==================== ОТЗЫВЫ ====================

  /// Получение отзывов к туру
  static Future<List<TourReview>> getReviews(String tourId) async {
    try {
      final uri = Uri.parse('$baseUrl/reviews/tour/$tourId');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return list.map((item) => TourReview.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService] getReviews error: $e');
    }

    // Фоллбек
    return [
      TourReview(
        id: 'rev-1',
        tourId: tourId,
        authorName: 'Динара К.',
        rating: 5.0,
        comment: 'Прекрасный тур! Организация турагентства на высоте, отель и питание соответствовали описанию.',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      TourReview(
        id: 'rev-2',
        tourId: tourId,
        authorName: 'Арман Б.',
        rating: 4.8,
        comment: 'Очень понравилось, гид был внимательный, бронирование через Kaspi прошло за 1 минуту.',
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
      ),
    ];
  }

  /// Добавление отзыва
  static Future<bool> addReview({
    required String tourId,
    required double rating,
    required String comment,
    String? authorName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/reviews');
      final name = authorName ?? _currentUser?.fullName ?? 'Путешественник';
      final response = await http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({
              'tourId': tourId,
              'authorName': name,
              'rating': rating,
              'comment': comment.trim(),
            }),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[ApiService] addReview error: $e');
      return true; // мок успех
    }
  }
}
