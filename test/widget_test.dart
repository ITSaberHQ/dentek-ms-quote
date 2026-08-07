import 'package:flutter_test/flutter_test.dart';

import 'package:dentek_ms_quote/main.dart';

void main() {
  testWidgets('Dentek quote app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DentekQuoteApp());

    expect(find.text('Dentek Quote Builder'), findsOneWidget);
    expect(find.text('Sales View'), findsOneWidget);
    expect(find.text('Client View'), findsOneWidget);
  });
}
