import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  kk('kk', 'Қазақша', '🇰🇿'),
  ru('ru', 'Русский', '🇷🇺'),
  en('en', 'English', '🇬🇧');

  const AppLanguage(this.code, this.name, this.flag);

  final String code;
  final String name;
  final String flag;

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.ru,
    );
  }
}

class LocaleService {
  static const String _prefKey = 'app_language_code';
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier<Locale>(const Locale('ru'));

  static AppLanguage get currentLanguage => AppLanguage.fromCode(localeNotifier.value.languageCode);

  /// Инициализация языка из сохраненных настроек
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey) ?? 'ru';
      localeNotifier.value = Locale(code);
    } catch (e) {
      debugPrint('[LocaleService] Init error: $e');
    }
  }

  /// Смена языка с сохранением
  static Future<void> setLanguage(AppLanguage language) async {
    localeNotifier.value = Locale(language.code);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language.code);
    } catch (e) {
      debugPrint('[LocaleService] Save error: $e');
    }
  }

  /// Получение локализованного текста по ключу
  static String tr(String key) {
    final code = localeNotifier.value.languageCode;
    return _translations[code]?[key] ?? _translations['ru']?[key] ?? key;
  }

  static const Map<String, Map<String, String>> _translations = {
    'ru': {
      // Табы
      'nav_home': 'Главная',
      'nav_tickets': 'Билеты',
      'nav_search': 'Поиск',
      'nav_bookings': 'Брони',
      'nav_profile': 'Профиль',

      // Главная
      'hello': 'Здравствуйте',
      'where_to_fly': 'Куда полетим?',
      'popular_tours': 'Популярные туры',
      'all_tours': 'Все туры ›',
      'promo_title': 'Турция и ОАЭ\nэтой осенью',
      'promo_discount': 'СКИДКА ДО 15%',
      'not_found': 'Туров не найдено',
      'search_hint': 'Поиск страны, города, тура или агентства…',

      // Категории
      'cat_beach': 'Пляжный отдых',
      'cat_mountains': 'Горы',
      'cat_visa': 'Визовые туры',
      'cat_resorts': 'Санатории',
      'cat_cruises': 'Круизы',
      'cat_all': 'Все',

      // Детали тура
      'flight_departure': 'Вылет из',
      'price_from': 'от',
      'book_now': 'Забронировать тур',
      'included_title': 'Что включено в стоимость',
      'about_tour': 'Об этом туре',
      'reviews_title': 'Отзывы путешественников',
      'write_review': 'Написать отзыв',
      'verified_agency': 'Проверенное агентство',

      // Бронирование
      'booking_title': 'Бронирование тура',
      'tourist_info': 'Данные туриста',
      'full_name': 'ФИО туриста',
      'phone_number': 'Номер телефона',
      'email': 'Электронная почта',
      'guests_count': 'Количество гостей',
      'payment_method': 'Способ оплаты',
      'kaspi_qr': 'Kaspi Pay (QR / Диплинк)',
      'bank_card': 'Банковская карта (Visa / MasterCard)',
      'price_breakdown': 'Детализация стоимости',
      'tour_price': 'Стоимость тура',
      'service_fee': 'Сервисный сбор',
      'total_amount': 'Итого к оплате',
      'pay_kaspi_btn': 'Оплатить через Kaspi Pay',

      // Профиль
      'profile_header': 'Мой профиль',
      'login_title': 'Войдите в профиль',
      'login_desc': 'Чтобы сохранять туры в избранное, просматривать билеты и историю бронирований',
      'login_btn': 'Войти / Зарегистрироваться',
      'language_title': 'Язык приложения',
      'select_language': 'Выберите язык интерфейса',
      'my_favorites': 'Избранные туры',
      'notifications_title': 'Push-уведомления',
      'test_notification': 'Отправить тестовый Push',
      'agency_cabinet': 'Кабинет турагентства',
      'add_new_tour': 'Создать тур',
      'logout_btn': 'Выйти из аккаунта',
      'notifications_empty': 'Новых уведомлений нет',

      // Статусы
      'status_paid': 'Оплачено',
      'status_confirmed': 'Подтвержден',
      'status_pending': 'Ожидает оплаты',

      // Push
      'push_booking_title': 'Бронирование подтверждено! 🎉',
      'push_booking_body': 'Ваша поездка успешно оформлена. Электронный билет и ваучер доступны в разделе «Брони».',
    },
    'kk': {
      // Табы
      'nav_home': 'Басты бет',
      'nav_tickets': 'Билеттер',
      'nav_search': 'Іздеу',
      'nav_bookings': 'Брондар',
      'nav_profile': 'Профиль',

      // Главная
      'hello': 'Сәлеметсіз бе',
      'where_to_fly': 'Қайда ұшамыз?',
      'popular_tours': 'Танымал турлар',
      'all_tours': 'Барлық турлар ›',
      'promo_title': 'Түркия және БӘА\nосы күзде',
      'promo_discount': '15%-ҒА ДЕЙІН ЖЕҢІЛДІК',
      'not_found': 'Турлар табылмады',
      'search_hint': 'Ел, қала, тур немесе агенттік іздеу…',

      // Категории
      'cat_beach': 'Жағажай демалысы',
      'cat_mountains': 'Таулар',
      'cat_visa': 'Визалық турлар',
      'cat_resorts': 'Шипажайлар',
      'cat_cruises': 'Круиздер',
      'cat_all': 'Барлығы',

      // Детали тура
      'flight_departure': 'Ұшу қаласы',
      'price_from': 'бастап',
      'book_now': 'Турды брондау',
      'included_title': 'Бағаға не кіреді',
      'about_tour': 'Тур туралы',
      'reviews_title': 'Саяхатшылардың пікірлері',
      'write_review': 'Пікір қалдыру',
      'verified_agency': 'Тексерілген агенттік',

      // Бронирование
      'booking_title': 'Турды брондау',
      'tourist_info': 'Саяхатшы деректері',
      'full_name': 'Аты-жөні',
      'phone_number': 'Телефон нөмірі',
      'email': 'Электронды пошта',
      'guests_count': 'Қонақтар саны',
      'payment_method': 'Төлем әдісі',
      'kaspi_qr': 'Kaspi Pay (QR / Диплинк)',
      'bank_card': 'Банк картасы (Visa / MasterCard)',
      'price_breakdown': 'Баға егжей-тегжейі',
      'tour_price': 'Тур құны',
      'service_fee': 'Қызмет ақысы',
      'total_amount': 'Барлығы төлеуге',
      'pay_kaspi_btn': 'Kaspi Pay арқылы төлеу',

      // Профиль
      'profile_header': 'Менің профилім',
      'login_title': 'Профильге кіріңіз',
      'login_desc': 'Турларды таңдаулыларға сақтау, билеттерді және брондау тарихын көру үшін',
      'login_btn': 'Кіру / Тіркелу',
      'language_title': 'Қосымша тілі',
      'select_language': 'Интерфейс тілін таңдаңыз',
      'my_favorites': 'Таңдаулы турлар',
      'notifications_title': 'Push-хабарламалар',
      'test_notification': 'Сынақ хабарламасын жіберу',
      'agency_cabinet': 'Турагенттік кабинеті',
      'add_new_tour': 'Тур жасау',
      'logout_btn': 'Аккаунттан шығу',
      'notifications_empty': 'Жаңа хабарламалар жоқ',

      // Статусы
      'status_paid': 'Төленді',
      'status_confirmed': 'Расталды',
      'status_pending': 'Төлем күтілуде',

      // Push
      'push_booking_title': 'Брондау расталды! 🎉',
      'push_booking_body': 'Сіздің саяхатыңыз сәтті ресімделді. Электронды билет пен ваучер «Брондар» бөлімінде қолжетімді.',
    },
    'en': {
      // Табы
      'nav_home': 'Home',
      'nav_tickets': 'Tickets',
      'nav_search': 'Search',
      'nav_bookings': 'Bookings',
      'nav_profile': 'Profile',

      // Главная
      'hello': 'Hello',
      'where_to_fly': 'Where to next?',
      'popular_tours': 'Popular Tours',
      'all_tours': 'All tours ›',
      'promo_title': 'Turkey & UAE\nThis Autumn',
      'promo_discount': 'UP TO 15% OFF',
      'not_found': 'No tours found',
      'search_hint': 'Search destination, hotel, tour or agency…',

      // Категории
      'cat_beach': 'Beach Holidays',
      'cat_mountains': 'Mountains',
      'cat_visa': 'Visa Tours',
      'cat_resorts': 'Health Resorts',
      'cat_cruises': 'Cruises',
      'cat_all': 'All',

      // Детали тура
      'flight_departure': 'Departure from',
      'price_from': 'from',
      'book_now': 'Book Tour',
      'included_title': "What's Included",
      'about_tour': 'About this tour',
      'reviews_title': 'Traveler Reviews',
      'write_review': 'Write a Review',
      'verified_agency': 'Verified Agency',

      // Бронирование
      'booking_title': 'Book Your Tour',
      'tourist_info': 'Traveler Information',
      'full_name': 'Full Name',
      'phone_number': 'Phone Number',
      'email': 'Email Address',
      'guests_count': 'Number of Guests',
      'payment_method': 'Payment Method',
      'kaspi_qr': 'Kaspi Pay (QR / Deeplink)',
      'bank_card': 'Bank Card (Visa / MasterCard)',
      'price_breakdown': 'Price Breakdown',
      'tour_price': 'Tour Price',
      'service_fee': 'Service Fee',
      'total_amount': 'Total to Pay',
      'pay_kaspi_btn': 'Pay with Kaspi Pay',

      // Профиль
      'profile_header': 'My Profile',
      'login_title': 'Sign In to Profile',
      'login_desc': 'To save tours to favorites, view e-tickets and manage booking history',
      'login_btn': 'Sign In / Register',
      'language_title': 'App Language',
      'select_language': 'Select Interface Language',
      'my_favorites': 'Favorite Tours',
      'notifications_title': 'Push Notifications',
      'test_notification': 'Send Test Push',
      'agency_cabinet': 'Travel Agency Portal',
      'add_new_tour': 'Create Tour',
      'logout_btn': 'Sign Out',
      'notifications_empty': 'No new notifications',

      // Статусы
      'status_paid': 'Paid',
      'status_confirmed': 'Confirmed',
      'status_pending': 'Pending Payment',

      // Push
      'push_booking_title': 'Booking Confirmed! 🎉',
      'push_booking_body': 'Your tour has been successfully booked. E-ticket and voucher are available under Bookings.',
    },
  };
}
