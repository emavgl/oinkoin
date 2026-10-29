import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/records/edit-record-page.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

void main() {
  late Wallet source;
  late Wallet destination;
  late Category category;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'UTC';
    await initializeDateFormatting('en_US', null);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'amountInputKeyboardType': 0});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
    await TestDatabaseHelper.setupTestDatabase();
    await ProfileService.instance.initialize();
    source = Wallet('Source', currency: 'USD');
    destination = Wallet('Destination', currency: 'USD');
    source.id = await ServiceConfig.database.addWallet(source);
    destination.id = await ServiceConfig.database.addWallet(destination);
    category = Category('Groceries', categoryType: CategoryType.expense);
    await ServiceConfig.database.addCategory(category);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> open(
    WidgetTester tester, {
    Record? record,
    bool isTransferFlow = true,
  }) async {
    await tester.pumpWidget(
      I18n(
        child: MaterialApp(
          home: EditRecordPage(
            passedRecord: record,
            isTransferFlow: isTransferFlow,
            initialWallet: source,
            initialDestinationWallet: destination,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Finder semantics(String identifier) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.identifier == identifier,
  );

  Finder clearCategoryButton() => semantics('clear-category-button');

  Finder categoryText(String text) => find.descendant(
    of: semantics('category-field'),
    matching: find.text(text),
  );

  Future<Record?> addTransfer(
    WidgetTester tester, {
    Category? withCategory,
  }) async {
    late Record? record;
    await tester.runAsync(() async {
      final id = await ServiceConfig.database.addRecord(
        Record(
          -100,
          'Transfer',
          withCategory,
          DateTime.utc(2026),
          walletId: source.id,
          transferWalletId: destination.id,
        ),
      );
      record = await ServiceConfig.database.getRecordById(id);
    });
    return record;
  }

  Future<Record?> reloadedRecord(WidgetTester tester, int id) async {
    late Record? record;
    await tester.runAsync(() async {
      record = await ServiceConfig.database.getRecordById(id);
    });
    return record;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
  }

  testWidgets('a transfer category can be cleared and saved', (tester) async {
    final record = await addTransfer(tester, withCategory: category);
    await open(tester, record: record);

    expect(categoryText('Groceries'), findsOneWidget);
    expect(clearCategoryButton(), findsOneWidget);

    await tester.tap(clearCategoryButton());
    await settle(tester);

    expect(categoryText('Groceries'), findsNothing);
    expect(categoryText('Select the category'), findsOneWidget);
    expect(clearCategoryButton(), findsNothing);

    await save(tester);

    final saved = await reloadedRecord(tester, record!.id!);
    expect(saved, isNotNull);
    expect(saved!.category, isNull);
    expect(saved.isTransfer, isTrue);
  });

  testWidgets('a transfer without a category shows no clear button', (
    tester,
  ) async {
    final record = await addTransfer(tester);
    await open(tester, record: record);

    expect(categoryText('Select the category'), findsOneWidget);
    expect(clearCategoryButton(), findsNothing);
  });

  testWidgets('expense and income records keep their category', (tester) async {
    final record = Record(
      10,
      'Lunch',
      category,
      DateTime.utc(2026),
      walletId: source.id,
    );
    await open(tester, record: record, isTransferFlow: false);

    expect(categoryText('Groceries'), findsOneWidget);
    expect(clearCategoryButton(), findsNothing);
  });
}
