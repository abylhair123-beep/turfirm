import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turfirm/models/booking.dart';
import 'package:turfirm/models/review.dart';
import 'package:turfirm/models/tour.dart';
import 'package:turfirm/models/user.dart';
import 'package:turfirm/services/api_service.dart';
import 'package:turfirm/services/locale_service.dart';
import 'package:turfirm/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Models Unit Tests', () {
    test('AppUser fromJson / toJson', () {
      final json = {
        'id': 'usr-1',
        'email': 'test@sapar.kz',
        'fullName': 'Асем Сериковна',
        'phone': '+7 777 123 45 67',
        'role': 'agency',
        'isActive': true,
      };

      final user = AppUser.fromJson(json);
      expect(user.id, 'usr-1');
      expect(user.email, 'test@sapar.kz');
      expect(user.fullName, 'Асем Сериковна');
      expect(user.isAgency, isTrue);
      expect(user.isAdmin, isFalse);

      final map = user.toJson();
      expect(map['email'], 'test@sapar.kz');
      expect(map['role'], 'agency');
    });

    test('TourReview fromJson / toJson', () {
      final json = {
        'id': 'rev-100',
        'tourId': 'antalya-7n',
        'authorName': 'Данияр',
        'rating': 4.5,
        'comment': 'Всё понравилось, особенно пляж!',
        'createdAt': '2026-10-31T12:00:00Z',
      };

      final review = TourReview.fromJson(json);
      expect(review.id, 'rev-100');
      expect(review.authorName, 'Данияр');
      expect(review.rating, 4.5);
      expect(review.comment, 'Всё понравилось, особенно пляж!');
    });

    test('Tour parsing and photo gallery (List<String> photoUrls)', () {
      expect(mockTours.isNotEmpty, isTrue);
      final first = mockTours.first;
      expect(first.title.isNotEmpty, isTrue);
      expect(first.priceFrom, greaterThan(0));
      expect(first.included.isNotEmpty, isTrue);
      expect(first.photoUrls.length, greaterThanOrEqualTo(2));
      expect(first.primaryPhotoUrl, isNotNull);

      // Проверка fromJson с photo_urls списком
      final jsonWithGallery = {
        'id': 'test-gallery-1',
        'agency': 'Silk Road',
        'destination': 'Алаколь',
        'title': 'Тур на Алаколь',
        'photoUrls': [
          'https://images.unsplash.com/photo-1',
          'https://images.unsplash.com/photo-2',
        ],
        'priceFrom': 75000,
        'description': 'Отдых на озере',
        'included': ['Трансфер', 'Отель'],
      };

      final parsed = Tour.fromJson(jsonWithGallery);
      expect(parsed.photoUrls.length, 2);
      expect(parsed.primaryPhotoUrl, 'https://images.unsplash.com/photo-1');
      expect(parsed.toJson()['photoUrls'], contains('https://images.unsplash.com/photo-2'));
    });

    test('Tour attributes for filtering (hotelStars, mealType, beachLine, durationNights)', () {
      final jsonWithAttrs = {
        'id': 'test-filter-1',
        'agency': 'Turan Travel',
        'destination': 'Анталия, Турция',
        'title': 'Тур в отель 5 звёзд',
        'nights': '7 ночей',
        'durationNights': 7,
        'hotelStars': 5,
        'mealType': 'AI',
        'beachLine': 1,
        'priceFrom': 320000,
        'description': 'Отель 5★ всё включено на первой линии',
        'included': ['Перелёт', 'Отель 5★'],
      };

      final tour = Tour.fromJson(jsonWithAttrs);
      expect(tour.hotelStars, 5);
      expect(tour.mealType, 'AI');
      expect(tour.beachLine, 1);
      expect(tour.durationNights, 7);

      final map = tour.toJson();
      expect(map['hotelStars'], 5);
      expect(map['mealType'], 'AI');
      expect(map['beachLine'], 1);
      expect(map['durationNights'], 7);
    });

    test('BookingRequest serialization', () {
      const request = BookingRequest(
        tourId: 'antalya-7n',
        customerName: 'Асем',
        customerPhone: '+7 777 000 11 22',
        customerEmail: 'asem@sapar.kz',
        guestsCount: 2,
        paymentMethod: 'Kaspi Pay',
      );

      final map = request.toJson();
      expect(map['tourId'], 'antalya-7n');
      expect(map['guestsCount'], 2);
      expect(map['paymentMethod'], 'Kaspi Pay');
    });

    test('BookingResult deserialization', () {
      final json = {
        'id': 'bk-123',
        'tourId': 'antalya-7n',
        'agencyId': 'agn-1',
        'customerName': 'Асем',
        'customerPhone': '+7 777 000 11 22',
        'customerEmail': 'asem@sapar.kz',
        'guestsCount': 2,
        'paymentMethod': 'Kaspi Pay',
        'tourPrice': 245000,
        'serviceFee': 9800,
        'totalPrice': 499800,
        'status': 'paid',
        'createdAt': '2026-10-31T12:00:00Z',
      };

      final result = BookingResult.fromJson(json);
      expect(result.id, 'bk-123');
      expect(result.totalPrice, 499800);
      expect(result.status, 'paid');
    });
  });

  group('Mobile & UX Services Tests', () {
    test('LocaleService translations support kk, ru, en', () {
      // Проверка русского языка
      expect(LocaleService.tr('nav_home'), 'Главная');
      expect(LocaleService.tr('book_now'), 'Забронировать тур');

      // Переключение на казахский
      LocaleService.setLanguage(AppLanguage.kk);
      expect(LocaleService.tr('nav_home'), 'Басты бет');
      expect(LocaleService.tr('book_now'), 'Турды брондау');
      expect(LocaleService.currentLanguage, AppLanguage.kk);

      // Переключение на английский
      LocaleService.setLanguage(AppLanguage.en);
      expect(LocaleService.tr('nav_home'), 'Home');
      expect(LocaleService.tr('book_now'), 'Book Tour');
      expect(LocaleService.currentLanguage, AppLanguage.en);

      // Возврат на русский
      LocaleService.setLanguage(AppLanguage.ru);
      expect(LocaleService.currentLanguage, AppLanguage.ru);
    });

    test('NotificationService handles in-app push triggers', () {
      expect(NotificationService.notificationsNotifier.value.isEmpty, isTrue);

      NotificationService.simulateBookingConfirmed(destination: 'Анталия');
      expect(NotificationService.notificationsNotifier.value.isNotEmpty, isTrue);
      expect(
        NotificationService.notificationsNotifier.value.first.title,
        contains('Бронирование подтверждено'),
      );
      expect(
        NotificationService.notificationsNotifier.value.first.body,
        contains('Анталия'),
      );
    });

    test('ApiService provides correct voucher PDF URL', () {
      final url = ApiService.getVoucherPdfUrl('BK-998877');
      expect(url, contains('/bookings/BK-998877/voucher.pdf'));
    });
  });
}
