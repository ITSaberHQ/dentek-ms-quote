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
}
