import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/records/edit-record-page.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

final _testCategory = Category(
  'Groceries',
  color: Colors.green,
  categoryType: CategoryType.expense,
);

Widget _buildTestApp(Widget child) {
  return I18n(
    child: MaterialApp(home: child),
  );
}

Finder _fieldByIdentifier(String identifier) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.identifier == identifier);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'Europe/Vienna';
    await initializeDateFormatting('en_US', null);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
    ServiceConfig.isPremium = true;
    await TestDatabaseHelper.setupTestDatabase();
  });

  tearDown(() {
    ServiceConfig.isPremium = false;
  });

  Future<void> pumpEditRecordPage(WidgetTester tester) async {
    // Use a tall surface so every card (including the repeat row) is laid
    // out without needing to scroll the form, which makes tap() reliable.
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_buildTestApp(
      EditRecordPage(passedCategory: _testCategory),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openRepeatDropdown(WidgetTester tester) async {
    await tester.tap(find.descendant(
        of: _fieldByIdentifier('repeat-field'),
        matching: find.byType(DropdownButton<int>)));
    await tester.pumpAndSettle();
  }

  Future<void> selectCustomFromDropdown(WidgetTester tester) async {
    await openRepeatDropdown(tester);
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();
  }

  // Helper: flush the text listener's 2s debounce Timer and any pending
  // async DB callbacks so no Timer is left pending after the test.
  Future<void> flushTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 11));
  }

  group('Custom recurrence interval UI', () {
    testWidgets('repeat dropdown offers a "Custom" option',
        (WidgetTester tester) async {
      await pumpEditRecordPage(tester);

      await openRepeatDropdown(tester);

      expect(find.text('Custom'), findsOneWidget);

      // Close the menu without selecting anything.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await flushTimers(tester);
    });

    testWidgets(
        'selecting Custom opens a dialog with sensible defaults, not an inline row',
        (WidgetTester tester) async {
      await pumpEditRecordPage(tester);

      // Before selecting "Custom", the dialog's inputs must not be present.
      expect(_fieldByIdentifier('custom-interval-value-field'), findsNothing);
      expect(_fieldByIdentifier('custom-interval-unit-field'), findsNothing);

      await selectCustomFromDropdown(tester);

      // A dialog is now open with the interval inputs inside it.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_fieldByIdentifier('custom-interval-value-field'), findsOneWidget);
      expect(_fieldByIdentifier('custom-interval-unit-field'), findsOneWidget);

      // Default value is 1 and default unit is Months (the common case).
      final valueField = tester.widget<TextFormField>(find.descendant(
          of: _fieldByIdentifier('custom-interval-value-field'),
          matching: find.byType(TextFormField)));
      expect(valueField.controller!.text, '1');

      expect(
          find.descendant(
              of: _fieldByIdentifier('custom-interval-unit-field'),
              matching: find
                  .text(customIntervalUnitString(CustomIntervalUnit.month))),
          findsOneWidget);

      // The repeat dropdown itself is not committed to Custom yet.
      final state =
          tester.state<EditRecordPageState>(find.byType(EditRecordPage));
      expect(state.recurrentPeriod, isNull);

      await flushTimers(tester);
    });

    testWidgets(
        'entering an interval value, changing the unit and tapping Save commits the selection',
        (WidgetTester tester) async {
      await pumpEditRecordPage(tester);
      await selectCustomFromDropdown(tester);

      await tester.enterText(
          find.descendant(
              of: _fieldByIdentifier('custom-interval-value-field'),
              matching: find.byType(TextFormField)),
          '6');
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
          of: _fieldByIdentifier('custom-interval-unit-field'),
          matching: find.byType(DropdownButtonFormField<CustomIntervalUnit>)));
      await tester.pumpAndSettle();
      await tester.tap(
          find.text(customIntervalUnitString(CustomIntervalUnit.year)).last);
      await tester.pumpAndSettle();

      await tester.tap(_fieldByIdentifier('custom-interval-dialog-save'));
      await tester.pumpAndSettle();

      // The dialog is gone and the state reflects the confirmed interval.
      expect(find.byType(AlertDialog), findsNothing);
      final state =
          tester.state<EditRecordPageState>(find.byType(EditRecordPage));
      expect(state.recurrentPeriod, RecurrentPeriod.Custom);

      // The collapsed dropdown now shows the resolved label.
      expect(find.text('Every 6 Years'), findsOneWidget);

      await flushTimers(tester);
    });

    testWidgets(
        'dismissing the dialog by tapping outside leaves the repeat selection unchanged',
        (WidgetTester tester) async {
      await pumpEditRecordPage(tester);

      // Baseline: nothing selected.
      var state =
          tester.state<EditRecordPageState>(find.byType(EditRecordPage));
      expect(state.recurrentPeriod, isNull);

      await selectCustomFromDropdown(tester);
      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap on the modal barrier, outside the dialog's content area.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      state = tester.state<EditRecordPageState>(find.byType(EditRecordPage));
      // recurrentPeriod must remain unchanged (still unset) — the dropdown
      // is not left pointing at Custom with no value/unit configured.
      expect(state.recurrentPeriod, isNull);
      expect(find.text('Not repeat'), findsOneWidget);

      await flushTimers(tester);
    });

    testWidgets(
        'tapping Cancel in the dialog leaves the repeat selection unchanged',
        (WidgetTester tester) async {
      await pumpEditRecordPage(tester);
      await selectCustomFromDropdown(tester);

      await tester.tap(_fieldByIdentifier('custom-interval-dialog-cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final state =
          tester.state<EditRecordPageState>(find.byType(EditRecordPage));
      expect(state.recurrentPeriod, isNull);
      expect(find.text('Not repeat'), findsOneWidget);

      await flushTimers(tester);
    });

    testWidgets(
        'reopening Custom after a confirmed selection pre-fills the dialog for editing',
        (WidgetTester tester) async {
      await pumpEditRecordPage(tester);
      await selectCustomFromDropdown(tester);
      await tester.enterText(
          find.descendant(
              of: _fieldByIdentifier('custom-interval-value-field'),
              matching: find.byType(TextFormField)),
          '6');
      await tester.pumpAndSettle();
      await tester.tap(_fieldByIdentifier('custom-interval-dialog-save'));
      await tester.pumpAndSettle();

      expect(find.text('Every 6 Months'), findsOneWidget);

      // Reopen the dropdown and tap "Custom" again to edit the value.
      await selectCustomFromDropdown(tester);

      final valueField = tester.widget<TextFormField>(find.descendant(
          of: _fieldByIdentifier('custom-interval-value-field'),
          matching: find.byType(TextFormField)));
      expect(valueField.controller!.text, '6');

      // Cancel this time: the previously-confirmed value must survive.
      await tester.tap(_fieldByIdentifier('custom-interval-dialog-cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Every 6 Months'), findsOneWidget);

      await flushTimers(tester);
    });

    testWidgets('an empty interval value is rejected without closing the dialog',
        (WidgetTester tester) async {
      await pumpEditRecordPage(tester);
      await selectCustomFromDropdown(tester);

      await tester.enterText(
          find.descendant(
              of: _fieldByIdentifier('custom-interval-value-field'),
              matching: find.byType(TextFormField)),
          '');
      await tester.pumpAndSettle();

      await tester.tap(_fieldByIdentifier('custom-interval-dialog-save'));
      await tester.pumpAndSettle();

      // The dialog stays open and the state is still not committed.
      expect(find.byType(AlertDialog), findsOneWidget);
      final state =
          tester.state<EditRecordPageState>(find.byType(EditRecordPage));
      expect(state.recurrentPeriod, isNull);

      await flushTimers(tester);
    });

    testWidgets('clearing an already-confirmed Custom selection hides its label',
        (WidgetTester tester) async {
      await pumpEditRecordPage(tester);
      await selectCustomFromDropdown(tester);
      await tester.tap(_fieldByIdentifier('custom-interval-dialog-save'));
      await tester.pumpAndSettle();

      expect(find.text('Every 1 Months'), findsOneWidget);

      // Tap the "clear repeat" close icon.
      await tester.tap(find.descendant(
          of: _fieldByIdentifier('repeat-field'),
          matching: find.byIcon(Icons.close)));
      await tester.pumpAndSettle();

      expect(find.text('Not repeat'), findsOneWidget);
      final state =
          tester.state<EditRecordPageState>(find.byType(EditRecordPage));
      expect(state.recurrentPeriod, isNull);

      await flushTimers(tester);
    });
  });
}
