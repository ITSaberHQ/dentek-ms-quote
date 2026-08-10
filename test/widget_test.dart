import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dentek_ms_quote/main.dart';

void main() {
  testWidgets('Dentek quote app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DentekQuoteApp());

    expect(find.text('Dentek Quote Builder'), findsOneWidget);
    expect(find.text('Sales View'), findsOneWidget);
    expect(find.text('Client View'), findsOneWidget);
  });

  testWidgets('Sales view requires the pin before access', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DentekQuoteApp());

    await tester.tap(find.text('Sales View'));
    await tester.pumpAndSettle();

    expect(find.text('Sales view locked'), findsOneWidget);
  });

  testWidgets('Bundle section can be switched to a bundle total view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DentekQuoteApp());

    await tester.tap(find.text('Sales View'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1972');
    await tester.tap(find.text('Unlock sales view'));
    await tester.pumpAndSettle();

    expect(find.text('Bundle section view'), findsOneWidget);

    await tester.tap(find.text('Show bundle total'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Client View'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bundle total'), findsOneWidget);
  });
}
