import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turfirm/models/user.dart';
import 'package:turfirm/services/api_service.dart';
import 'package:turfirm/screens/profile_screen.dart';
import 'package:turfirm/screens/notification_settings_screen.dart';
import 'package:turfirm/screens/payment_methods_screen.dart';
import 'package:turfirm/screens/support_care_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Test profile screen menu buttons navigate properly when authenticated', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    ApiService.userNotifier.value = const AppUser(
      id: '1',
      email: 'test@sapar.kz',
      fullName: 'Тестовый Пользователь',
      role: 'client',
      phone: '+7 777 000 0000',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Push notifications tile
    expect(find.text('Push-уведомления'), findsOneWidget);
    await tester.ensureVisible(find.text('Push-уведомления'));
    await tester.tap(find.text('Push-уведомления'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);

    // Pop back
    Navigator.of(tester.element(find.byType(NotificationSettingsScreen))).pop();
    await tester.pumpAndSettle();

    // 2. Payment methods tile
    expect(find.text('Способы оплаты'), findsOneWidget);
    await tester.ensureVisible(find.text('Способы оплаты'));
    await tester.tap(find.text('Способы оплаты'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PaymentMethodsScreen), findsOneWidget);

    // Pop back
    Navigator.of(tester.element(find.byType(PaymentMethodsScreen))).pop();
    await tester.pumpAndSettle();

    // 3. Support 24/7 tile
    expect(find.text('Служба заботы 24/7'), findsOneWidget);
    await tester.ensureVisible(find.text('Служба заботы 24/7'));
    await tester.tap(find.text('Служба заботы 24/7'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SupportCareScreen), findsOneWidget);

    // Pop back
    Navigator.of(tester.element(find.byType(SupportCareScreen))).pop();
    await tester.pumpAndSettle();

    // 4. Legal information tile
    expect(find.text('Правовая информация & Оферта'), findsOneWidget);
    await tester.ensureVisible(find.text('Правовая информация & Оферта'));
    await tester.tap(find.text('Правовая информация & Оферта'));
    await tester.pumpAndSettle();

    expect(find.text('Правовая информация'), findsOneWidget);
    expect(find.text('Публичная оферта'), findsOneWidget);
    expect(find.text('Возврат & Аннуляция'), findsOneWidget);
    expect(find.text('Конфиденциальность'), findsOneWidget);

    // Switch tabs
    await tester.tap(find.text('Возврат & Аннуляция'));
    await tester.pumpAndSettle();
    expect(find.text('Политика возврата и гарантии туристов'), findsOneWidget);

    await tester.tap(find.text('Конфиденциальность'));
    await tester.pumpAndSettle();
    expect(find.text('Защита персональных данных'), findsOneWidget);
  });
}
