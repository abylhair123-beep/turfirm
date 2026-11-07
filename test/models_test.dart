import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turfirm/models/booking.dart';
import 'package:turfirm/models/crm_models.dart';
import 'package:turfirm/models/financial_summary.dart';
import 'package:turfirm/models/referral.dart';
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

    test('Tour promotion attributes (isPromoted, promotedUntil, promotionTier)', () {
      final jsonPromoted = {
        'id': 'tour-promo-1',
        'agency': 'Turan Travel',
        'destination': 'Анталия',
        'title': 'VIP Тур в Риксос',
        'nights': '7 ночей',
        'dates': '10-17 июня',
        'meal': 'Всё включено',
        'priceFrom': 350000,
        'description': 'Супер отдых',
        'included': ['Перелет'],
        'isPromoted': true,
        'promotedUntil': '2026-11-14T12:00:00Z',
        'promotionTier': 'top',
      };

      final tour = Tour.fromJson(jsonPromoted);
      expect(tour.isPromoted, isTrue);
      expect(tour.promotionTier, 'top');
      expect(tour.promotedUntil, isNotNull);

      final map = tour.toJson();
      expect(map['isPromoted'], isTrue);
      expect(map['promotionTier'], 'top');
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

    test('ReferralCampaign and ReferralStats deserialization', () {
      final campJson = {
        'id': 'ref-1',
        'userId': 'usr-blogger',
        'code': 'TRAVEL_PRO',
        'campaignName': 'Instagram Stories',
        'commissionRate': 3.0,
        'fixedReward': 0,
        'clicksCount': 120,
        'bookingsCount': 5,
        'totalEarned': 36750,
        'balance': 36750,
        'referralUrl': 'https://sapar.kz/?ref=TRAVEL_PRO',
        'isActive': true,
        'createdAt': '2026-11-01T10:00:00Z',
      };

      final camp = ReferralCampaign.fromJson(campJson);
      expect(camp.code, 'TRAVEL_PRO');
      expect(camp.clicksCount, 120);
      expect(camp.bookingsCount, 5);
      expect(camp.totalEarned, 36750);
      expect(camp.balance, 36750);

      final statsJson = {
        'totalClicks': 150,
        'totalBookings': 6,
        'conversionRate': 4.0,
        'totalEarned': 44100,
        'balance': 44100,
        'campaigns': [campJson],
        'recentBookings': [
          {
            'id': 'BK-1',
            'bookingId': 'BK-1',
            'tourTitle': 'Турция, Анталья',
            'customerName': 'Ерлан',
            'tourPrice': 245000,
            'reward': 7350,
            'status': 'paid',
            'createdAt': '2026-11-02T12:00:00Z',
          }
        ],
      };

      final stats = ReferralStats.fromJson(statsJson);
      expect(stats.totalClicks, 150);
      expect(stats.totalBookings, 6);
      expect(stats.conversionRate, 4.0);
      expect(stats.campaigns.length, 1);
      expect(stats.recentBookings.length, 1);
      expect(stats.recentBookings.first.reward, 7350);

      final checkJson = {
        'valid': true,
        'code': 'TRAVEL_PRO',
        'campaignName': 'Instagram Stories',
        'bloggerName': 'Алихан',
        'discountPercent': 3.0,
        'message': 'Скидка 3%',
      };
      final checkRes = ReferralCheckResult.fromJson(checkJson);
      expect(checkRes.valid, isTrue);
      expect(checkRes.bloggerName, 'Алихан');
      expect(checkRes.discountPercent, 3.0);

      // Booking with referral
      const req = BookingRequest(
        tourId: 'antalya',
        customerName: 'Айбек',
        customerPhone: '+7 701 000 00 00',
        customerEmail: 'aibek@mail.kz',
        guestsCount: 1,
        paymentMethod: 'Kaspi Pay',
        referralCode: 'TRAVEL_PRO',
      );
      final reqJson = req.toJson();
      expect(reqJson['referralCode'], 'TRAVEL_PRO');

      final resJson = {
        'id': 'BK-2',
        'tourId': 'antalya',
        'agencyId': 'agn-1',
        'customerName': 'Айбек',
        'customerPhone': '+7 701 000 00 00',
        'customerEmail': 'aibek@mail.kz',
        'guestsCount': 1,
        'paymentMethod': 'Kaspi Pay',
        'tourPrice': 200000,
        'serviceFee': 9800,
        'totalPrice': 209800,
        'status': 'paid',
        'referralCode': 'TRAVEL_PRO',
        'referralReward': 6000,
        'createdAt': '2026-11-03T10:00:00Z',
      };
      final bResult = BookingResult.fromJson(resJson);
      expect(bResult.referralCode, 'TRAVEL_PRO');
      expect(bResult.referralReward, 6000);
    });

    test('FinancialSummary and FinancialRecordItem deserialization', () {
      final json = {
        'period': 'all',
        'totalIncome': 1249800,
        'totalExpense': 628197,
        'netProfit': 621603,
        'marginPercentage': 49.7,
        'incomeBreakdown': [
          {
            'category': 'tour_payments',
            'label': 'Оплаты туров клиентами',
            'amount': 490000,
            'percentage': 39.2,
          },
          {
            'category': 'advertising',
            'label': 'Реклама и спонсорские баннеры',
            'amount': 750000,
            'percentage': 60.0,
          }
        ],
        'expenseBreakdown': [
          {
            'category': 'agency_payouts',
            'label': 'Выплаты турагентствам (нетто)',
            'amount': 455700,
            'percentage': 72.5,
          }
        ],
        'chartPoints': [
          {
            'date': '07.11',
            'income': 1249800,
            'expense': 628197,
            'net': 621603,
          }
        ],
        'recentTransactions': [
          {
            'id': 'rec-1',
            'type': 'income',
            'category': 'advertising',
            'amount': 450000,
            'title': 'Реклама Rixos',
            'description': 'Баннер на главной',
            'referenceId': 'AD-1',
            'createdAt': '2026-11-07T12:00:00Z',
          }
        ],
      };

      final summary = FinancialSummary.fromJson(json);
      expect(summary.totalIncome, 1249800);
      expect(summary.totalExpense, 628197);
      expect(summary.netProfit, 621603);
      expect(summary.marginPercentage, 49.7);
      expect(summary.incomeBreakdown.length, 2);
      expect(summary.expenseBreakdown.length, 1);
      expect(summary.chartPoints.first.date, '07.11');
      expect(summary.recentTransactions.first.isIncome, isTrue);
      expect(summary.recentTransactions.first.amount, 450000);
    });

    test('CRM Models: CallQueueItem, CallLogItem, CallStats deserialization', () {
      final queueJson = {
        'id': 'BK-101',
        'target_type': 'customer',
        'target_name': 'Динара Серикова',
        'target_phone': '+7 701 555 77 88',
        'tour_title': 'Тур в Дубай 5★',
        'booking_id': 'BK-101',
        'booking_status': 'paid',
        'total_price': 380000,
        'priority': 'callback',
        'last_call_at': '2026-11-07T14:00:00Z',
        'last_call_status': 'callback_needed',
        'last_call_notes': 'Перезвонить вечером',
        'reason': 'Запланирован перезвон',
      };
      final queueItem = CallQueueItem.fromJson(queueJson);
      expect(queueItem.targetName, 'Динара Серикова');
      expect(queueItem.priority, 'callback');
      expect(queueItem.totalPrice, 380000);

      final logJson = {
        'id': 'CALL-99',
        'direction': 'outbound',
        'target_type': 'customer',
        'target_name': 'Динара Серикова',
        'target_phone': '+7 701 555 77 88',
        'booking_id': 'BK-101',
        'manager_name': 'Алихан Менеджер',
        'tour_title': 'Тур в Дубай 5★',
        'status': 'successful',
        'duration_seconds': 145,
        'notes': 'Тур подтвержден',
        'telephony_provider': 'mango',
        'recording_url': 'https://storage.sapar.travel/rec.mp3',
        'created_at': '2026-11-07T14:30:00Z',
      };
      final logItem = CallLogItem.fromJson(logJson);
      expect(logItem.id, 'CALL-99');
      expect(logItem.status, 'successful');
      expect(logItem.formattedDuration, '2 мин 25 сек');
      expect(logItem.telephonyProvider, 'mango');

      final statsJson = {
        'total_calls': 15,
        'calls_today': 8,
        'successful_calls': 12,
        'answer_rate_pct': 80.0,
        'avg_duration_seconds': 110,
        'pending_callbacks_count': 3,
        'status_breakdown': {'successful': 12, 'callback_needed': 3},
      };
      final stats = CallStats.fromJson(statsJson);
      expect(stats.totalCalls, 15);
      expect(stats.answerRatePct, 80.0);
      expect(stats.statusBreakdown['successful'], 12);
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
