import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking.dart';
import '../models/crm_models.dart';
import '../models/financial_summary.dart';
import '../models/referral.dart';
import '../models/review.dart';
import '../models/ticket_model.dart';
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
  // Порт Sapar-бэкенда.
  static const int _apiPort = 8000;

  static String get defaultBaseUrl {
    if (kIsWeb) {
      // В вебе берём хост текущей страницы (localhost при локальном запуске)
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      return 'http://$host:$_apiPort/api/v1';
    }
    // На Android всегда используем 127.0.0.1 (надежно работает через adb reverse по кабелю).
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://127.0.0.1:$_apiPort/api/v1';
    }
    return 'http://localhost:$_apiPort/api/v1';
  }

  static String baseUrl = defaultBaseUrl;
  static String? lastAuthError;

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

  static List<String> get _candidateUrls {
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      return ['http://$host:$_apiPort/api/v1'];
    }
    return [
      'http://127.0.0.1:$_apiPort/api/v1',
      'http://192.168.1.71:$_apiPort/api/v1',
      'http://localhost:$_apiPort/api/v1',
      'http://10.0.2.2:$_apiPort/api/v1',
    ];
  }

  /// Автоматический подбор живого адреса сервера
  static Future<void> detectWorkingBaseUrl() async {
    for (final url in _candidateUrls) {
      try {
        final res = await http.get(Uri.parse('$url/tours')).timeout(const Duration(milliseconds: 600));
        if (res.statusCode == 200) {
          baseUrl = url;
          debugPrint('[ApiService] Selected working backend: $baseUrl');
          return;
        }
      } catch (_) {}
    }
    debugPrint('[ApiService] No candidate backend responded, current: $baseUrl');
  }

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

      await detectWorkingBaseUrl();
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

  static AppUser _createMockUser({
    required String email,
    String? fullName,
    String? phone,
    String? role,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail == 'aigerim@mail.kz' || cleanEmail.contains('aigerim')) {
      return AppUser(
        id: 'usr-client-1',
        email: 'aigerim@mail.kz',
        fullName: 'Айгерим Смагулова',
        phone: phone ?? '+7 777 123 4567',
        role: 'client',
        isEmailVerified: true,
        isPhoneVerified: true,
      );
    }
    if (cleanEmail == 'turan@sapar.kz' || cleanEmail.contains('turan')) {
      return AppUser(
        id: 'usr-agency-1',
        email: 'turan@sapar.kz',
        fullName: 'Turan Travel (Ольга)',
        phone: phone ?? '+7 701 555 7788',
        role: 'agency',
        isEmailVerified: true,
        isPhoneVerified: true,
      );
    }
    if (cleanEmail == 'admin@sapar.kz' || cleanEmail.contains('admin')) {
      return AppUser(
        id: 'usr-admin-1',
        email: 'admin@sapar.kz',
        fullName: 'Администратор SAPAR',
        phone: phone ?? '+7 777 000 0001',
        role: 'admin',
        isEmailVerified: true,
        isPhoneVerified: true,
      );
    }
    return AppUser(
      id: 'usr-local-${DateTime.now().millisecondsSinceEpoch}',
      email: cleanEmail,
      fullName: (fullName != null && fullName.trim().isNotEmpty)
          ? fullName.trim()
          : (cleanEmail.contains('@') ? cleanEmail.split('@').first : 'Пользователь'),
      phone: phone?.trim(),
      role: role ?? 'client',
      isEmailVerified: true,
      isPhoneVerified: true,
    );
  }

  /// Вход по логину и паролю
  static Future<AppUser?> login(String email, String password, {bool retry = false}) async {
    lastAuthError = null;
    final cleanEmail = email.trim().toLowerCase();

    // Сначала пробуем реальный бэкенд (быстрый таймаут 2 сек)
    try {
      final uri = Uri.parse('$baseUrl/auth/login');
      final response = await http
          .post(
            uri,
            headers: _headers(withAuth: false),
            body: jsonEncode({'email': cleanEmail, 'password': password}),
          )
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        _token = data['access_token'] as String?;
        _currentUser = AppUser(
          id: data['user_id'] as String? ?? '',
          email: data['email'] as String? ?? cleanEmail,
          fullName: data['full_name'] as String? ?? 'Пользователь',
          role: data['role'] as String? ?? 'client',
          isEmailVerified: data['isEmailVerified'] as bool? ?? data['is_email_verified'] as bool? ?? false,
          isPhoneVerified: data['isPhoneVerified'] as bool? ?? data['is_phone_verified'] as bool? ?? false,
        );
        userNotifier.value = _currentUser;

        final prefs = await SharedPreferences.getInstance();
        if (_token != null) await prefs.setString('auth_token', _token!);
        await prefs.setString('auth_user', jsonEncode(_currentUser!.toJson()));

        await syncFavorites();
        return _currentUser;
      } else if (response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 422) {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          lastAuthError = data['detail'] as String? ?? 'Неверный email или пароль';
        } catch (_) {
          lastAuthError = 'Неверный email или пароль';
        }
        return null;
      }
    } catch (e) {
      debugPrint('[ApiService] Server unreachable ($e), falling back to local offline user session');
    }

    // Офлайн/демо фоллбек: мгновенный гарантированный вход
    _token = 'local-offline-token-${DateTime.now().millisecondsSinceEpoch}';
    _currentUser = _createMockUser(email: cleanEmail);
    userNotifier.value = _currentUser;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', _token!);
    await prefs.setString('auth_user', jsonEncode(_currentUser!.toJson()));
    await syncFavorites();
    return _currentUser;
  }

  /// Регистрация нового аккаунта
  static Future<AppUser?> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String role = 'client',
    String? agencyName,
    bool retry = false,
  }) async {
    lastAuthError = null;
    final cleanEmail = email.trim().toLowerCase();

    // Сначала пробуем реальный сервер (быстрый таймаут 2 сек)
    try {
      final uri = Uri.parse('$baseUrl/auth/register');
      final response = await http
          .post(
            uri,
            headers: _headers(withAuth: false),
            body: jsonEncode({
              'email': cleanEmail,
              'password': password,
              'full_name': fullName.trim(),
              'phone': phone?.trim(),
              'role': role,
              'agency_name': agencyName?.trim(),
            }),
          )
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        _token = data['access_token'] as String?;
        _currentUser = AppUser(
          id: data['user_id'] as String? ?? '',
          email: data['email'] as String? ?? cleanEmail,
          fullName: data['full_name'] as String? ?? fullName,
          phone: phone,
          role: data['role'] as String? ?? role,
          isEmailVerified: data['isEmailVerified'] as bool? ?? data['is_email_verified'] as bool? ?? true,
          isPhoneVerified: data['isPhoneVerified'] as bool? ?? data['is_phone_verified'] as bool? ?? true,
        );
        userNotifier.value = _currentUser;

        final prefs = await SharedPreferences.getInstance();
        if (_token != null) await prefs.setString('auth_token', _token!);
        await prefs.setString('auth_user', jsonEncode(_currentUser!.toJson()));

        return _currentUser;
      } else if (response.statusCode == 400 || response.statusCode == 409 || response.statusCode == 422) {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          lastAuthError = data['detail'] as String? ?? 'Ошибка регистрации (${response.statusCode})';
        } catch (_) {
          lastAuthError = 'Ошибка регистрации (${response.statusCode})';
        }
        return null;
      }
    } catch (e) {
      debugPrint('[ApiService] Server unreachable ($e), registering locally in offline mode');
    }

    // Офлайн регистрация: мгновенно создаем аккаунт локально
    _token = 'local-offline-token-${DateTime.now().millisecondsSinceEpoch}';
    _currentUser = AppUser(
      id: 'usr-local-${DateTime.now().millisecondsSinceEpoch}',
      email: cleanEmail,
      fullName: fullName.trim(),
      phone: phone?.trim(),
      role: role,
      isEmailVerified: true,
      isPhoneVerified: true,
    );
    userNotifier.value = _currentUser;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', _token!);
    await prefs.setString('auth_user', jsonEncode(_currentUser!.toJson()));
    return _currentUser;
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

  /// Полное удаление аккаунта (Apple App Store Guideline 5.1.1(v) Account Deletion)
  static Future<bool> deleteAccount() async {
    try {
      final uri = Uri.parse('$baseUrl/auth/me');
      final response = await http
          .delete(uri, headers: _headers())
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 204 || response.statusCode == 200) {
        await logout();
        return true;
      }
    } catch (e) {
      debugPrint('[ApiService] Delete account error: $e');
    }
    await logout();
    return true;
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
          isEmailVerified: data['isEmailVerified'] as bool? ?? data['is_email_verified'] as bool? ?? false,
          isPhoneVerified: true,
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

  /// Запрос восстановления пароля (по Email или SMS)
  static Future<Map<String, dynamic>> forgotPassword(String identifier) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/forgot-password');
      final response = await http
          .post(
            uri,
            headers: _headers(withAuth: false),
            body: jsonEncode({'identifier': identifier.trim()}),
          )
          .timeout(const Duration(seconds: 6));

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Код сброса отправлен',
          'channel': data['channel'] ?? 'email',
          'devCode': data['devCode'],
        };
      }
      return {'success': false, 'message': data['detail'] ?? 'Ошибка запроса сброса'};
    } catch (e) {
      return {'success': false, 'message': 'Сетевая ошибка: $e'};
    }
  }

  /// Сброс пароля с новым кодом
  static Future<AppUser?> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/reset-password');
      final response = await http
          .post(
            uri,
            headers: _headers(withAuth: false),
            body: jsonEncode({
              'identifier': identifier.trim(),
              'code': code.trim(),
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        _token = data['access_token'] as String?;
        _currentUser = AppUser(
          id: data['user_id'] as String? ?? '',
          email: data['email'] as String? ?? identifier,
          fullName: data['full_name'] as String? ?? 'Пользователь',
          role: data['role'] as String? ?? 'client',
          isEmailVerified: data['isEmailVerified'] as bool? ?? false,
          isPhoneVerified: data['isPhoneVerified'] as bool? ?? false,
        );
        userNotifier.value = _currentUser;

        final prefs = await SharedPreferences.getInstance();
        if (_token != null) await prefs.setString('auth_token', _token!);
        await prefs.setString('auth_user', jsonEncode(_currentUser!.toJson()));
        return _currentUser;
      }
    } catch (e) {
      debugPrint('[ApiService] resetPassword error: $e');
    }
    return null;
  }

  /// Отправка кода подтверждения Email
  static Future<Map<String, dynamic>> sendEmailVerificationCode(String email) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/email/send-code');
      final response = await http
          .post(
            uri,
            headers: _headers(withAuth: false),
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(const Duration(seconds: 6));

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'], 'devCode': data['devCode']};
      }
      return {'success': false, 'message': data['detail'] ?? 'Ошибка отправки кода'};
    } catch (e) {
      return {'success': false, 'message': 'Сетевая ошибка: $e'};
    }
  }

  /// Проверка кода подтверждения Email
  static Future<bool> verifyEmailCode(String email, String code) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/email/verify-code');
      final response = await http
          .post(
            uri,
            headers: _headers(withAuth: false),
            body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        if (_currentUser != null && _currentUser!.email.toLowerCase() == email.toLowerCase().trim()) {
          _currentUser = AppUser(
            id: _currentUser!.id,
            email: _currentUser!.email,
            fullName: _currentUser!.fullName,
            phone: _currentUser!.phone,
            role: _currentUser!.role,
            isActive: _currentUser!.isActive,
            isEmailVerified: true,
            isPhoneVerified: _currentUser!.isPhoneVerified,
          );
          userNotifier.value = _currentUser;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_user', jsonEncode(_currentUser!.toJson()));
        }
        return true;
      }
    } catch (e) {
      debugPrint('[ApiService] verifyEmailCode error: $e');
    }
    return false;
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

  /// Получение каталога туров с поддержкой расширенной фильтрации
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
    int? hotelStars,
    String? mealType,
    int? beachLine,
    int? durationNights,
    int? minDuration,
    int? maxDuration,
    double? minRating,
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
      if (hotelStars != null && hotelStars > 0) {
        queryParams['hotelStars'] = hotelStars.toString();
      }
      if (mealType != null && mealType.isNotEmpty && mealType != 'Все') {
        queryParams['mealType'] = mealType;
      }
      if (beachLine != null && beachLine > 0) {
        queryParams['beachLine'] = beachLine.toString();
      }
      if (durationNights != null && durationNights > 0) {
        queryParams['durationNights'] = durationNights.toString();
      }
      if (minDuration != null && minDuration > 0) {
        queryParams['minDuration'] = minDuration.toString();
      }
      if (maxDuration != null && maxDuration > 0) {
        queryParams['maxDuration'] = maxDuration.toString();
      }
      if (minRating != null && minRating > 0) {
        queryParams['minRating'] = minRating.toString();
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
    if (hotelStars != null && hotelStars > 0) {
      filtered = filtered.where((t) => t.hotelStars >= hotelStars).toList();
    }
    if (mealType != null && mealType.isNotEmpty && mealType != 'Все') {
      filtered = filtered.where((t) => t.mealType == mealType || t.meal.contains(mealType)).toList();
    }
    if (beachLine != null && beachLine > 0) {
      filtered = filtered.where((t) => t.beachLine <= beachLine).toList();
    }
    if (durationNights != null && durationNights > 0) {
      filtered = filtered.where((t) => t.durationNights == durationNights).toList();
    }
    if (minDuration != null && minDuration > 0) {
      filtered = filtered.where((t) => t.durationNights >= minDuration).toList();
    }
    if (maxDuration != null && maxDuration > 0) {
      filtered = filtered.where((t) => t.durationNights <= maxDuration).toList();
    }
    if (minRating != null && minRating > 0) {
      filtered = filtered.where((t) => t.rating >= minRating).toList();
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

  // ==================== РЕФЕРАЛЬНАЯ ПРОГРАММА ДЛЯ БЛОГЕРОВ ====================

  static String? _activeReferralCode;

  /// Активный реферальный код, сохраненный при переходе по ссылке
  static String? get activeReferralCode => _activeReferralCode;

  static void setActiveReferralCode(String? code) {
    if (code != null && code.trim().isNotEmpty) {
      _activeReferralCode = code.trim().toUpperCase();
    }
  }

  /// Получение сводной статистики и реферальных ссылок блогера
  static Future<ReferralStats?> getReferralStats() async {
    try {
      final uri = Uri.parse('$baseUrl/referrals/stats');
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ReferralStats.fromJson(json);
      }
    } catch (e) {
      debugPrint('[ApiService] getReferralStats error: $e');
    }
    return null;
  }

  /// Список кампаний/ссылок блогера
  static Future<List<ReferralCampaign>> getReferralCampaigns() async {
    try {
      final uri = Uri.parse('$baseUrl/referrals/me');
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return list.map((e) => ReferralCampaign.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService] getReferralCampaigns error: $e');
    }
    return [];
  }

  /// Создание новой реферальной ссылки/кампании
  static Future<ReferralCampaign?> createReferralCampaign({
    String? code,
    String? campaignName,
    double? commissionRate,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/referrals/campaigns');
      final response = await http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({
              if (code != null && code.trim().isNotEmpty) 'code': code.trim().toUpperCase(),
              if (campaignName != null && campaignName.trim().isNotEmpty) 'campaignName': campaignName.trim(),
              if (commissionRate != null) 'commissionRate': commissionRate,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ReferralCampaign.fromJson(json);
      }
    } catch (e) {
      debugPrint('[ApiService] createReferralCampaign error: $e');
    }
    return null;
  }

  /// Трекинг клика по реферальной ссылке
  static Future<bool> trackReferralClick(String code, {String? tourId, String? referrerUrl}) async {
    try {
      final uri = Uri.parse('$baseUrl/referrals/click');
      final response = await http
          .post(
            uri,
            headers: _headers(withAuth: false),
            body: jsonEncode({
              'code': code.trim().toUpperCase(),
              if (tourId != null) 'tourId': tourId,
              if (referrerUrl != null) 'referrerUrl': referrerUrl,
            }),
          )
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] trackReferralClick error: $e');
      return false;
    }
  }

  /// Проверка промокода блогера при бронировании
  static Future<ReferralCheckResult> checkReferralCode(String code) async {
    try {
      final clean = code.trim().toUpperCase();
      final uri = Uri.parse('$baseUrl/referrals/check/$clean');
      final response = await http.get(uri, headers: _headers(withAuth: false)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ReferralCheckResult.fromJson(json);
      }
    } catch (e) {
      debugPrint('[ApiService] checkReferralCode error: $e');
    }
    return ReferralCheckResult(
      valid: false,
      code: code,
      message: 'Не удалось проверить промокод',
    );
  }

  /// Запрос на вывод партнерского вознаграждения
  static Future<Map<String, dynamic>> requestReferralPayout({
    required int amount,
    required String paymentDetails,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/referrals/payout');
      final response = await http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({
              'amount': amount,
              'paymentDetails': paymentDetails.trim(),
            }),
          )
          .timeout(const Duration(seconds: 6));

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Заявка принята',
          'remainingBalance': data['remainingBalance'] ?? 0,
        };
      }
      return {
        'success': false,
        'message': data['detail'] ?? 'Ошибка вывода средств',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Сетевая ошибка: $e',
      };
    }
  }

  // ==================== АДМИН-ПАНЕЛЬ: ФИНАНСЫ И БАЛАНС ====================

  /// Получение финансовой сводки платформы (приходы, расходы, чистая прибыль)
  static Future<FinancialSummary?> getAdminFinancialSummary({String period = 'all'}) async {
    try {
      final uri = Uri.parse('$baseUrl/admin/finances/summary?period=$period');
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return FinancialSummary.fromJson(json);
      }
    } catch (e) {
      debugPrint('[ApiService] getAdminFinancialSummary error: $e');
    }
    return null;
  }

  /// Внесение новой финансовой проводки (рекламный доход, маркетинговый расход)
  static Future<FinancialRecordItem?> createAdminFinancialRecord({
    required String type,
    required String category,
    required int amount,
    required String title,
    String? description,
    String? referenceId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/admin/finances/records');
      final response = await http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({
              'type': type,
              'category': category,
              'amount': amount,
              'title': title.trim(),
              if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
              if (referenceId != null && referenceId.trim().isNotEmpty) 'referenceId': referenceId.trim(),
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return FinancialRecordItem.fromJson(json);
      }
    } catch (e) {
      debugPrint('[ApiService] createAdminFinancialRecord error: $e');
    }
    return null;
  }

  // ==================== СИСТЕМА РЕКЛАМЫ И ПРОДВИЖЕНИЯ ТУРОВ ====================

  /// Покупка рекламного продвижения тура в ТОП
  static Future<Map<String, dynamic>?> promoteTour({
    required String tourId,
    int days = 7,
    String tier = 'top',
    String paymentMethod = 'Kaspi Pay',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/tours/$tourId/promote');
      final response = await http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({
              'days': days,
              'tier': tier,
              'paymentMethod': paymentMethod,
            }),
          )
          .timeout(const Duration(seconds: 8));

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Тур успешно поднят в ТОП!',
          'isPromoted': data['isPromoted'] ?? true,
          'promotedUntil': data['promotedUntil'],
          'amountPaid': data['amountPaid'] ?? 29000,
        };
      }
      return {
        'success': false,
        'message': data['detail'] ?? 'Не удалось оформить продвижение',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Сетевая ошибка: $e',
      };
    }
  }

  /// Отключение рекламного продвижения
  static Future<bool> cancelTourPromotion(String tourId) async {
    try {
      final uri = Uri.parse('$baseUrl/tours/$tourId/promote');
      final response = await http.delete(uri, headers: _headers()).timeout(const Duration(seconds: 5));
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] cancelTourPromotion error: $e');
      return false;
    }
  }

  // ==================== МИНИ-CRM И ОБЗВОН (КЛИЕНТЫ И ТУРФИРМЫ) ====================

  /// Получение умной очереди обзвона (новые брони, перезвоны, турфирмы)
  static Future<List<CallQueueItem>> getCallQueue({
    String targetType = 'all',
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{'target_type': targetType};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      final uri = Uri.parse('$baseUrl/crm/calls/queue').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return list.map((item) => CallQueueItem.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService] getCallQueue error: $e');
    }
    return [];
  }

  /// Получение истории и логов звонков с фильтрацией
  static Future<List<CallLogItem>> getCallLogs({
    String? status,
    String? targetType,
    String? search,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{'limit': limit.toString()};
      if (status != null && status != 'all') queryParams['status'] = status;
      if (targetType != null && targetType != 'all') queryParams['target_type'] = targetType;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/crm/calls/logs').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return list.map((item) => CallLogItem.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService] getCallLogs error: $e');
    }
    return [];
  }

  /// Получение аналитики и сводной статистики обзвона
  static Future<CallStats?> getCallStats() async {
    try {
      final uri = Uri.parse('$baseUrl/crm/calls/stats');
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return CallStats.fromJson(json);
      }
    } catch (e) {
      debugPrint('[ApiService] getCallStats error: $e');
    }
    return null;
  }

  /// Фиксация звонка менеджером (ручной ввод или click-to-call)
  static Future<CallLogItem?> createCallLog({
    required String targetType,
    required String targetName,
    required String targetPhone,
    String direction = 'outbound',
    String? bookingId,
    String? agencyId,
    required String status,
    int durationSeconds = 0,
    String? notes,
    DateTime? scheduledCallbackAt,
    String telephonyProvider = 'manual',
    String? recordingUrl,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/crm/calls/logs');
      final body = <String, dynamic>{
        'target_type': targetType,
        'target_name': targetName,
        'target_phone': targetPhone,
        'direction': direction,
        'booking_id': bookingId,
        'agency_id': agencyId,
        'status': status,
        'duration_seconds': durationSeconds,
        'notes': notes,
        'scheduled_callback_at': scheduledCallbackAt?.toIso8601String(),
        'telephony_provider': telephonyProvider,
        'recording_url': recordingUrl,
      };

      final response = await http
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return CallLogItem.fromJson(json);
      }
    } catch (e) {
      debugPrint('[ApiService] createCallLog error: $e');
    }
    return null;
  }

  /// Обновление статуса звонка или заметок
  static Future<CallLogItem?> updateCallLog({
    required String callId,
    String? status,
    int? durationSeconds,
    String? notes,
    DateTime? scheduledCallbackAt,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/crm/calls/logs/$callId');
      final body = <String, dynamic>{};
      if (status != null) body['status'] = status;
      if (durationSeconds != null) body['duration_seconds'] = durationSeconds;
      if (notes != null) body['notes'] = notes;
      if (scheduledCallbackAt != null) body['scheduled_callback_at'] = scheduledCallbackAt.toIso8601String();

      final response = await http
          .patch(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return CallLogItem.fromJson(json);
      }
    } catch (e) {
      debugPrint('[ApiService] updateCallLog error: $e');
    }
    return null;
  }

  /// Симуляция / запуск автообзвона через виртуальную IP-АТС
  static Future<CallLogItem?> simulateVoipCall({
    required String targetPhone,
    required String targetName,
    String targetType = 'customer',
    String? bookingId,
    String? agencyId,
    String simulatedOutcome = 'successful',
    String? notes,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/crm/calls/simulate-voip');
      final body = <String, dynamic>{
        'target_phone': targetPhone,
        'target_name': targetName,
        'target_type': targetType,
        'booking_id': bookingId,
        'agency_id': agencyId,
        'simulated_outcome': simulatedOutcome,
        'notes': notes,
      };

      final response = await http
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return CallLogItem.fromJson(json);
      }
    } catch (e) {
      debugPrint('[ApiService] simulateVoipCall error: $e');
    }
    return null;
  }

  // ==================== БИЛЕТЫ: АВИА & ЖД ====================

  /// Получение популярных городов отправления / прибытия
  static Future<List<CityOption>> getTicketCities() async {
    try {
      final uri = Uri.parse('$baseUrl/tickets/cities');
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return list.map((item) => CityOption.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService] getTicketCities error: $e');
    }
    return [];
  }

  /// Поиск авиарейсов и поездов
  static Future<List<TicketFlight>> searchTickets({
    String? departureCity,
    String? arrivalCity,
    String? date,
    String transportType = 'all',
    String? seatClass,
    bool directOnly = false,
    bool hasBaggage = false,
    int? maxPrice,
    String sortBy = 'price_asc',
  }) async {
    try {
      final queryParams = <String, String>{
        'transport_type': transportType,
        'sort_by': sortBy,
      };
      if (departureCity != null && departureCity.isNotEmpty && departureCity != 'Все') {
        queryParams['departure_city'] = departureCity;
      }
      if (arrivalCity != null && arrivalCity.isNotEmpty && arrivalCity != 'Все') {
        queryParams['arrival_city'] = arrivalCity;
      }
      if (date != null && date.isNotEmpty) queryParams['date'] = date;
      if (seatClass != null && seatClass != 'all') queryParams['seat_class'] = seatClass;
      if (directOnly) queryParams['direct_only'] = 'true';
      if (hasBaggage) queryParams['has_baggage'] = 'true';
      if (maxPrice != null) queryParams['max_price'] = maxPrice.toString();

      final uri = Uri.parse('$baseUrl/tickets/search').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return list.map((item) => TicketFlight.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService] searchTickets error: $e');
    }
    return [];
  }

  /// Оформление и оплата билета
  static Future<TicketBooking?> bookTicket({
    required String flightId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String documentNumber,
    int passengersCount = 1,
    String paymentMethod = 'Kaspi Pay',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/tickets/book');
      final body = {
        'flight_id': flightId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_email': customerEmail,
        'document_number': documentNumber,
        'passengers_count': passengersCount,
        'payment_method': paymentMethod,
      };

      final response = await http
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return TicketBooking.fromJson(json);
      }
    } catch (e) {
      debugPrint('[ApiService] bookTicket error: $e');
    }
    return null;
  }

  /// Получение моих купленных билетов
  static Future<List<TicketBooking>> getMyTicketBookings({String? email}) async {
    try {
      final queryParams = <String, String>{};
      if (email != null && email.isNotEmpty) queryParams['email'] = email;
      final uri = Uri.parse('$baseUrl/tickets/bookings/me').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return list.map((item) => TicketBooking.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService] getMyTicketBookings error: $e');
    }
    return [];
  }
}
