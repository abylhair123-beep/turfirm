// Базовый smoke-тест: приложение запускается и показывает онбординг.

import 'package:flutter_test/flutter_test.dart';

import 'package:turfirm/main.dart';

void main() {
  testWidgets('Приложение открывается на экране онбординга', (tester) async {
    await tester.pumpWidget(const SaparApp());
    await tester.pump();

    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.textContaining('SAPAR'), findsOneWidget);
  });

  testWidgets('Кнопка "Продолжить" ведёт на главный экран', (tester) async {
    await tester.pumpWidget(const SaparApp());
    await tester.pump();

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(find.text('Популярные туры'), findsOneWidget);
  });
}
