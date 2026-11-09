import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turfirm/models/user.dart';
import 'package:turfirm/screens/agency_desktop_portal_screen.dart';
import 'package:turfirm/services/api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Agency desktop portal loads and switches tabs properly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    ApiService.userNotifier.value = const AppUser(
      id: 'agency-1',
      email: 'turan@sapar.kz',
      fullName: 'Turan Travel B2B',
      role: 'agency',
      phone: '+7 701 555 1234',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AgencyDesktopPortalScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Brand Sidebar exists
    expect(find.text('SAPAR'), findsWidgets);
    expect(find.text('B2B PORTAL'), findsOneWidget);

    // Verify Nav items
    expect(find.text('Обзор и Аналитика'), findsOneWidget);
    expect(find.text('Реестр туров'), findsOneWidget);
    expect(find.text('Заявки и Туристы'), findsOneWidget);
    expect(find.text('Финансы и Выплаты'), findsOneWidget);
    expect(find.text('Реквизиты компании'), findsOneWidget);

    // Switch to "Реестр туров"
    await tester.tap(find.text('Реестр туров'));
    await tester.pumpAndSettle();
    expect(find.text('Создать тур'), findsOneWidget);

    // Switch to "Заявки и Туристы"
    await tester.tap(find.text('Заявки и Туристы'));
    await tester.pumpAndSettle();
    expect(find.text('Экспорт в Excel (XLSX)'), findsOneWidget);

    // Switch to "Финансы и Выплаты"
    await tester.tap(find.text('Финансы и Выплаты'));
    await tester.pumpAndSettle();
    expect(find.text('Запросить вывод на IBAN'), findsOneWidget);

    // Switch to "Реквизиты компании"
    await tester.tap(find.text('Реквизиты компании'));
    await tester.pumpAndSettle();
    expect(find.text('Юридические и банковские реквизиты компании'), findsOneWidget);
    expect(find.text('Сохранить реквизиты'), findsOneWidget);
  });
}
