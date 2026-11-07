import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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

/// Доступный тег удобства для фильтра (из реального каталога).
class AmenityOption {
  const AmenityOption({required this.tag, required this.label, required this.count});
  final String tag;
  final String label;
  final int count;
}

/// Доступные значения фильтров, собранные из каталога (`/tours/filters`).
class FilterOptions {
  const FilterOptions({required this.amenities, required this.stars});
  final List<AmenityOption> amenities;
  final List<int> stars;
}

/// Подсказка в поиске (результат `/search/suggest` или `/search/popular`).
class SearchSuggestion {
  const SearchSuggestion({
    required this.type,
    required this.text,
    this.subtitle,
    this.tourId,
  });

  final String type; // 'destination' | 'tour' | 'agency' | 'category' | 'recent'
  final String text;
  final String? subtitle;
  final String? tourId;

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchSuggestion(
      type: json['type'] as String? ?? 'destination',
      text: json['text'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      tourId: json['tour_id'] as String?,
    );
  }
}

/// Результат проверки промокода (`/promo/validate`).
class PromoResult {
  const PromoResult({
    required this.valid,
    required this.code,
    required this.discountPercent,
    required this.discountAmount,
    required this.finalAmount,
    required this.message,
  });

  final bool valid;
  final String code;
  final int discountPercent;
  final int discountAmount;
  final int finalAmount;
  final String message;

  factory PromoResult.fromJson(Map<String, dynamic> json, int fallbackAmount) {
    return PromoResult(
      valid: json['valid'] as bool? ?? false,
      code: json['code'] as String? ?? '',
      discountPercent: (json['discountPercent'] as num? ?? json['discount_percent'] as num?)?.toInt() ?? 0,
      discountAmount: (json['discountAmount'] as num? ?? json['discount_amount'] as num?)?.toInt() ?? 0,
      finalAmount: (json['finalAmount'] as num? ?? json['final_amount'] as num?)?.toInt() ?? fallbackAmount,
      message: json['message'] as String? ?? '',
    );
  }
}

class ApiService {
  // Порт Sapar-бэкенда. Сейчас 8001, т.к. порт 8000 занят другим проектом.
  // Когда освободишь 8000 — верни сюда 8000 (одно место).
  static const int _apiPort = 8001;

  static String get defaultBaseUrl {
    if (kIsWeb) {
      // В вебе берём хост текущей страницы (localhost при локальном запуске)
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      return 'http://$host:$_apiPort/api/v1';
    }
    // Android-эмулятор видит хост-машину как 10.0.2.2, остальное — localhost.
    // Для теста на реальном телефоне по локалке задайте ApiService.baseUrl вручную
    // (например, 'http://192.168.10.12:$_apiPort/api/v1' — IP вашего ПК).
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$_apiPort/api/v1';
    }
    return 'http://localhost:$_apiPort/api/v1';
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

  /// Запрос 4-значного OTP-кода по SMS
  static Future<Map<String, dynamic>> sendSmsOtp(String phone) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/sms/send-otp');
      final response = await http
          .post(
            uri,
            headers: _headers(withAuth: false),
            body: jsonEncode({'phone': phone.trim()}),
          )
          .timeout(const Duration(seconds: 6));

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'], 'devCode': data['devCode']};
      }
      return {'success': false, 'message': data['detail'] ?? 'Ошибка отправки SMS'};
    } catch (e) {
      return {'success': false, 'message': 'Сетевая ошибка: $e'};
    }
  }

  /// Верификация OTP-кода из SMS и вход/регистрация
  static Future<AppUser?> verifySmsOtp(String phone, String code) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/sms/verify-otp');
      final response = await http
          .post(
            uri,
            headers: _headers(withAuth: false),
            body: jsonEncode({'phone': phone.trim(), 'code': code.trim()}),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        _token = data['access_token'] as String?;
        _currentUser = AppUser(
          id: data['user_id'] as String? ?? '',
          email: data['email'] as String? ?? '',
          fullName: data['full_name'] as String? ?? 'Турист',
          phone: phone,
          role: data['role'] as String? ?? 'client',
        );
        userNotifier.value = _currentUser;

        final prefs = await SharedPreferences.getInstance();
        if (_token != null) await prefs.setString('auth_token', _token!);
        await prefs.setString('auth_user', jsonEncode(_currentUser!.toJson()));
        return _currentUser;
      }
    } catch (e) {
      debugPrint('[ApiService] verifySmsOtp error: $e');
    }
    return null;
  }

  /// Получить URL для открытия или скачивания официального PDF-ваучера
  static String getVoucherPdfUrl(String bookingId) {
    return '$baseUrl/bookings/$bookingId/voucher.pdf';
  }

  /// Скачивание бинарного PDF-файла ваучера
  static Future<Uint8List?> downloadVoucherPdf(String bookingId) async {
    try {
      final uri = Uri.parse(getVoucherPdfUrl(bookingId));
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('[ApiService] downloadVoucherPdf error: $e');
    }
    return null;
  }

  // ==================== ТУРЫ ====================

  /// Получение каталога туров с поддержкой фильтрации
  static Future<List<Tour>> getTours({
    String? category,
    String? search,
    String? departureCity,
    int? minPrice,
    int? maxPrice,
    int? guests,
    int? children,
    List<String>? amenities,
    List<int>? stars,
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
      if (guests != null && guests > 0) {
        queryParams['guests'] = guests.toString();
      }
      if (children != null && children > 0) {
        queryParams['children'] = children.toString();
      }
      if (amenities != null && amenities.isNotEmpty) {
        queryParams['amenities'] = amenities.join(',');
      }
      if (stars != null && stars.isNotEmpty) {
        queryParams['stars'] = stars.join(',');
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

  // ==================== ПОИСК И ПОДСКАЗКИ ====================

  /// Живые подсказки по мере ввода (направления, туры, агентства, категории).
  static Future<List<SearchSuggestion>> getSuggestions(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final uri = Uri.parse('$baseUrl/search/suggest').replace(
        queryParameters: {'q': q},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return decoded
            .map((e) => SearchSuggestion.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[ApiService] getSuggestions failed: $e');
    }
    return [];
  }

  /// Популярные направления — для пустой строки поиска.
  static Future<List<SearchSuggestion>> getPopularSearches() async {
    try {
      final uri = Uri.parse('$baseUrl/search/popular');
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return decoded
            .map((e) => SearchSuggestion.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[ApiService] getPopularSearches failed: $e');
    }
    return [];
  }

  // Недавние запросы храним локально в SharedPreferences.
  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxRecentSearches = 8;

  static Future<List<String>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_recentSearchesKey) ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentSearchesKey) ?? [];
      list.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
      list.insert(0, q);
      if (list.length > _maxRecentSearches) {
        list.removeRange(_maxRecentSearches, list.length);
      }
      await prefs.setStringList(_recentSearchesKey, list);
    } catch (_) {
      // Недоступность хранилища не должна ломать поиск.
    }
  }

  static Future<void> clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (_) {}
  }

  /// Доступные значения фильтров (удобства + звёзды) из реального каталога.
  static Future<FilterOptions> getFilterOptions() async {
    try {
      final uri = Uri.parse('$baseUrl/tours/filters');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final amenities = (data['amenities'] as List<dynamic>? ?? [])
            .map((e) => AmenityOption(
                  tag: (e as Map<String, dynamic>)['tag'] as String? ?? '',
                  label: e['label'] as String? ?? '',
                  count: (e['count'] as num?)?.toInt() ?? 0,
                ))
            .where((a) => a.tag.isNotEmpty)
            .toList();
        final stars = (data['stars'] as List<dynamic>? ?? [])
            .map((e) => (e as num).toInt())
            .toList();
        return FilterOptions(amenities: amenities, stars: stars);
      }
    } catch (e) {
      debugPrint('[ApiService] getFilterOptions failed: $e');
    }
    return const FilterOptions(amenities: [], stars: []);
  }

  // ==================== ПРОМОКОДЫ ====================

  /// Проверка промокода и расчёт скидки для суммы заказа.
  static Future<PromoResult> validatePromo(String code, int amount) async {
    try {
      final uri = Uri.parse('$baseUrl/promo/validate');
      final response = await http
          .post(
            uri,
            headers: _headers(withAuth: false),
            body: jsonEncode({'code': code, 'amount': amount}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return PromoResult.fromJson(data, amount);
      }
    } catch (e) {
      debugPrint('[ApiService] validatePromo failed: $e');
    }
    return PromoResult(
      valid: false,
      code: code,
      discountPercent: 0,
      discountAmount: 0,
      finalAmount: amount,
      message: 'Не удалось проверить промокод',
    );
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

  // ========================= Панель агентства =========================

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

  // ==================== B2B ПОРТАЛ ТУРАГЕНТСТВ ====================

  /// Получение всех туров агентства (включая неактивные)
  static Future<List<Tour>> getAgencyTours() async {
    try {
      final uri = Uri.parse('$baseUrl/agencies/me/tours');
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return list.map((item) => Tour.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService] getAgencyTours error: $e');
    }
    return [];
  }

  /// Обновление параметров тура (цены, даты, описание, активность)
  static Future<Tour?> updateTour(String tourId, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('$baseUrl/tours/$tourId');
      final response = await http
          .put(
            uri,
            headers: _headers(),
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return Tour.fromJson(json);
      }
    } catch (e) {
      debugPrint('[ApiService] updateTour error: $e');
    }
    return null;
  }

  /// Быстрая пауза / снятие с продажи в 1 клик
  static Future<Tour?> toggleTourActive(String tourId) async {
    try {
      final uri = Uri.parse('$baseUrl/tours/$tourId/toggle-active');
      final response = await http.patch(uri, headers: _headers()).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return Tour.fromJson(json);
      }
    } catch (e) {
      debugPrint('[ApiService] toggleTourActive error: $e');
    }
    return null;
  }

  /// Список бронирований клиентов агентства (для Канбан-доски)
  static Future<List<Booking>> getAgencyBookings({String? status, String? search}) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams['status'] = status;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      final uri = Uri.parse('$baseUrl/agencies/me/bookings').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return list.map((item) => Booking.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService] getAgencyBookings error: $e');
    }
    return [];
  }

  /// Смена статуса бронирования в Канбан-доске (confirmed, voucher_issued, completed, cancelled)
  static Future<Booking?> updateBookingStatus(String bookingId, String newStatus) async {
    try {
      final uri = Uri.parse('$baseUrl/bookings/$bookingId/status');
      final response = await http
          .patch(
            uri,
            headers: _headers(),
            body: jsonEncode({'status': newStatus}),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return Booking.fromJson(json);
      }
    } catch (e) {
      debugPrint('[ApiService] updateBookingStatus error: $e');
    }
    return null;
  }

  /// Расширенная аналитика агентства: выручка, комиссия, средний чек и график продаж
  static Future<Map<String, dynamic>?> getAgencyAnalytics({String period = 'month'}) async {
    try {
      final uri = Uri.parse('$baseUrl/agencies/me/analytics?period=$period');
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[ApiService] getAgencyAnalytics error: $e');
    }
    return null;
  }

  /// URL выгрузки списка туристов в Excel (XLSX)
  static String getAgencyBookingsExportUrl({String? status}) {
    if (status != null && status.isNotEmpty && status != 'all') {
      return '$baseUrl/agencies/me/bookings/export-xlsx?status=$status';
    }
    return '$baseUrl/agencies/me/bookings/export-xlsx';
  }
}
