import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dentek_ms_quote/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

    expect(find.text('Bundle total'), findsOneWidget);

    await tester.tap(find.text('Bundle total'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Client View'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bundle total'), findsOneWidget);
  });

  testWidgets('Sales view asks for the PIN again after switching away', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DentekQuoteApp());

    await tester.tap(find.text('Sales View'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1972');
    await tester.tap(find.text('Unlock sales view'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Client View'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sales View'));
    await tester.pumpAndSettle();

    expect(find.text('Sales view locked'), findsOneWidget);
  });

  testWidgets(
    'Sales view groups bundle and a la carte items in collapsible sections',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const DentekQuoteApp());

      await tester.tap(find.text('Sales View'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1972');
      await tester.tap(find.text('Unlock sales view'));
      await tester.pumpAndSettle();

      expect(find.byType(ExpansionTile), findsWidgets);
      expect(find.text('Remote Support Bundle'), findsWidgets);
      expect(find.text('Onboarding'), findsWidgets);

      await tester.ensureVisible(find.text('Remote Support Bundle'));
      await tester.tap(find.text('Remote Support Bundle'));
      await tester.pumpAndSettle();

      expect(find.text('Remote Support Server/Cloud'), findsWidgets);
    },
  );

  testWidgets('Client view includes a collapsible terms of service section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DentekQuoteApp());

    await tester.tap(find.text('Client View'));
    await tester.pumpAndSettle();

    expect(find.text('Terms of Service'), findsOneWidget);

    await tester.ensureVisible(find.text('Terms of Service'));
    await tester.tap(find.text('Terms of Service'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('master-services-agreement.html'),
      findsOneWidget,
    );
  });

  testWidgets('Editing a service price persists after restarting the app', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const DentekQuoteApp());

    await tester.tap(find.text('Sales View'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1972');
    await tester.tap(find.text('Unlock sales view'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remote Support Bundle'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('price_button_Remote Support Server/Cloud')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '129.99',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getDouble('service_price_Remote Support Server/Cloud'),
      129.99,
    );

    await tester.pumpWidget(const DentekQuoteApp());
    await tester.pumpAndSettle();

    final reloadedPrefs = await SharedPreferences.getInstance();
    expect(
      reloadedPrefs.getDouble('service_price_Remote Support Server/Cloud'),
      129.99,
    );
  });

  testWidgets('Start Fresh keeps the current service price defaults', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const DentekQuoteApp());

    await tester.tap(find.text('Sales View'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1972');
    await tester.tap(find.text('Unlock sales view'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remote Support Bundle'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('price_button_Remote Support Server/Cloud')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '129.99',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sales_actions_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Fresh').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Price: \$129.99'), findsOneWidget);
  });

  testWidgets('Sales view can save and load a local quote draft', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DentekQuoteApp());

    await tester.tap(find.text('Sales View'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1972');
    await tester.tap(find.text('Unlock sales view'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'North Clinic');

    await tester.tap(find.byKey(const ValueKey('sales_actions_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Draft').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'North Clinic Draft');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Drafts are saved only on this device/browser (1/20)',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(1), 'South Clinic');

    await tester.tap(find.byKey(const ValueKey('sales_actions_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved Drafts (1)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Client View'));
    await tester.pumpAndSettle();
    expect(find.text('Prepared for North Clinic'), findsOneWidget);
  });

  testWidgets('Saved draft can be duplicated', (WidgetTester tester) async {
    await tester.pumpWidget(const DentekQuoteApp());

    await tester.tap(find.text('Sales View'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1972');
    await tester.tap(find.text('Unlock sales view'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'West Clinic');

    await tester.tap(find.byKey(const ValueKey('sales_actions_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Draft').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'West Clinic Draft');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sales_actions_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved Drafts (1)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'West Clinic Draft 2');
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Drafts are saved only on this device/browser (2/20)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Support timeblock is optional and hidden from the client quote '
      'until it is switched on', (WidgetTester tester) async {
    _useWideView(tester);
    await tester.pumpWidget(const DentekQuoteApp());

    await tester.tap(find.text('Client View'));
    await tester.pumpAndSettle();
    expect(find.text('Support Timeblock'), findsNothing);

    await _unlockSalesView(tester);
    expect(find.text('Optional - not included on this quote'), findsOneWidget);

    await _openTimeblockSection(tester);
    await _configureTimeblock(
      tester,
      hours: '10',
      rate: '125',
      note: 'Unused hours roll over for 12 months.',
    );

    await tester.tap(find.text('Client View'));
    await tester.pumpAndSettle();

    expect(find.text('Support Timeblock'), findsOneWidget);
    expect(find.text('10 hours x \$125.00/hr'), findsOneWidget);
    expect(find.text('Unused hours roll over for 12 months.'), findsOneWidget);
  });

  testWidgets('Support timeblock bills as monthly recurring and is taxed', (
    WidgetTester tester,
  ) async {
    _useWideView(tester);
    await tester.pumpWidget(const DentekQuoteApp());

    await _unlockSalesView(tester);
    await _openTimeblockSection(tester);
    await _configureTimeblock(tester, hours: '10', rate: '125', note: '');

    await tester.tap(find.text('Client View'));
    await tester.pumpAndSettle();

    // Every other default service is priced at 0, so the timeblock is the
    // entire monthly subtotal. The one-time bucket stays empty, so nothing is
    // due today, while the recurring tax rides along with the monthly bill.
    _expectMoneyRow('Monthly Recurring Subtotal', '\$1,250.00');
    _expectMoneyRow('Sales Tax on Monthly (8.25%)', '\$103.13');
    _expectMoneyRow('One-Time Subtotal', '\$0.00');
    _expectMoneyRow('Sales Tax on One-Time (8.25%)', '\$0.00');
    _expectMoneyRow('Due Today', '\$0.00');
    _expectMoneyRow('Estimated First Invoice', '\$1,353.13');
  });

  testWidgets('Timeblock note can be kept off the client quote', (
    WidgetTester tester,
  ) async {
    _useWideView(tester);
    await tester.pumpWidget(const DentekQuoteApp());

    await _unlockSalesView(tester);
    await _openTimeblockSection(tester);
    await _configureTimeblock(
      tester,
      hours: '4',
      rate: '150',
      note: 'Internal only: discounted rate approved by ops.',
    );

    await tester.tap(
      find.byKey(const ValueKey('timeblock_show_note_checkbox')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Client View'));
    await tester.pumpAndSettle();

    expect(find.text('Support Timeblock'), findsOneWidget);
    expect(find.text('4 hours x \$150.00/hr'), findsOneWidget);
    expect(
      find.text('Internal only: discounted rate approved by ops.'),
      findsNothing,
    );
  });

  testWidgets('Hourly rate can be kept off the client quote', (
    WidgetTester tester,
  ) async {
    _useWideView(tester);
    await tester.pumpWidget(const DentekQuoteApp());

    await _unlockSalesView(tester);
    await _openTimeblockSection(tester);
    await _configureTimeblock(
      tester,
      hours: '10',
      rate: '125',
      note: 'Unused hours roll over for 12 months.',
    );

    await tester.tap(
      find.byKey(const ValueKey('timeblock_show_rate_checkbox')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Client View'));
    await tester.pumpAndSettle();

    // The hours stay as the selling point, the rate does not print, and the
    // monthly total is unchanged.
    expect(find.text('10 hours'), findsOneWidget);
    expect(find.text('10 hours x \$125.00/hr'), findsNothing);
    expect(find.text('Unused hours roll over for 12 months.'), findsOneWidget);
    _expectMoneyRow('Monthly Recurring Subtotal', '\$1,250.00');
  });

  testWidgets('Rate visibility survives a draft round trip', (
    WidgetTester tester,
  ) async {
    _useWideView(tester);
    await tester.pumpWidget(const DentekQuoteApp());

    await _unlockSalesView(tester);
    await _openTimeblockSection(tester);
    await _configureTimeblock(tester, hours: '8', rate: '100', note: '');
    await tester.tap(
      find.byKey(const ValueKey('timeblock_show_rate_checkbox')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sales_actions_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Draft').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Hidden Rate Draft');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Turn the rate back on, then reload the draft.
    await tester.tap(
      find.byKey(const ValueKey('timeblock_show_rate_checkbox')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sales_actions_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved Drafts (1)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Client View'));
    await tester.pumpAndSettle();

    expect(find.text('8 hours'), findsOneWidget);
    expect(find.text('8 hours x \$100.00/hr'), findsNothing);
  });

  testWidgets('Timeblock hours, rate and note survive a draft round trip', (
    WidgetTester tester,
  ) async {
    _useWideView(tester);
    await tester.pumpWidget(const DentekQuoteApp());

    await _unlockSalesView(tester);
    await _openTimeblockSection(tester);
    await _configureTimeblock(
      tester,
      hours: '6',
      rate: '110',
      note: 'Block reviewed quarterly.',
    );

    await tester.tap(find.byKey(const ValueKey('sales_actions_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Draft').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Timeblock Draft');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Change everything, then reload the draft and confirm it is restored.
    await tester.enterText(
      find.byKey(const ValueKey('timeblock_hours_field')),
      '99',
    );
    await tester.enterText(
      find.byKey(const ValueKey('timeblock_note_field')),
      'scratch',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sales_actions_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved Drafts (1)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Client View'));
    await tester.pumpAndSettle();

    expect(find.text('6 hours x \$110.00/hr'), findsOneWidget);
    expect(find.text('Block reviewed quarterly.'), findsOneWidget);
  });

  testWidgets('Sales tax applies to the recurring and one-time buckets', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'service_price_Remote Support Workstation': 100.0,
      'service_price_Anti-Virus': 50.0,
      'service_price_Onboarding': 600.0,
    });
    _useWideView(tester);
    await tester.pumpWidget(const DentekQuoteApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Client View'));
    await tester.pumpAndSettle();

    // Each bucket is taxed at the same rate, but only the one-time tax is
    // collected today; the recurring tax recurs with the monthly bill.
    _expectMoneyRow('Monthly Recurring Subtotal', '\$150.00');
    _expectMoneyRow('Sales Tax on Monthly (8.25%)', '\$12.38');
    _expectMoneyRow('One-Time Subtotal', '\$600.00');
    _expectMoneyRow('Sales Tax on One-Time (8.25%)', '\$49.50');
    _expectMoneyRow('Due Today', '\$649.50');
    _expectMoneyRow('Estimated First Invoice', '\$811.88');
  });
}

Future<void> _unlockSalesView(WidgetTester tester) async {
  await tester.tap(find.text('Sales View'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '1972');
  await tester.tap(find.text('Unlock sales view'));
  await tester.pumpAndSettle();
}

Future<void> _openTimeblockSection(WidgetTester tester) async {
  final section = find.byKey(const ValueKey('timeblock_section'));
  await tester.ensureVisible(section);
  await tester.tap(section);
  await tester.pumpAndSettle();
}

/// Switches the timeblock on and fills in hours, rate and note.
Future<void> _configureTimeblock(
  WidgetTester tester, {
  required String hours,
  required String rate,
  required String note,
}) async {
  await tester.tap(find.byKey(const ValueKey('timeblock_include_switch')));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const ValueKey('timeblock_hours_field')),
    hours,
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('timeblock_rate_button')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    rate,
  );
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const ValueKey('timeblock_note_field')),
    note,
  );
  await tester.pumpAndSettle();
}

/// Asserts that a client-view summary row pairs [label] with [value].
void _expectMoneyRow(String label, String value) {
  final row = find
      .ancestor(of: find.text(label), matching: find.byType(Row))
      .first;
  expect(find.descendant(of: row, matching: find.text(value)), findsOneWidget);
}

void _useWideView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
