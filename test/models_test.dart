import 'package:flutter_test/flutter_test.dart';
import 'package:turfirm/models/booking.dart';
import 'package:turfirm/models/review.dart';
import 'package:turfirm/models/tour.dart';
import 'package:turfirm/models/user.dart';

void main() {
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

    test('Tour parsing and mock data integrity', () {
      expect(mockTours.isNotEmpty, isTrue);
      final first = mockTours.first;
      expect(first.title.isNotEmpty, isTrue);
      expect(first.priceFrom, greaterThan(0));
      expect(first.included.isNotEmpty, isTrue);
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
}
