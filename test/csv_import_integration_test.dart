import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/csv_import_mapping.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/csv_import_service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

/// Integration tests for CSV import — verifies that parsed CSV data is
/// correctly inserted into the database with duplicate handling via
/// [CsvImportService.importRecords].
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'Europe/Vienna';
  });

  setUp(() async {
    await TestDatabaseHelper.setupTestDatabase();
  });

  // ---------------------------------------------------------------------------
  // Helper — build records from simple CSV string and a mapping, then import
  // ---------------------------------------------------------------------------
  Future<CsvImportResult> importCsvString(
    String csvContent,
    CsvImportMapping mapping,
  ) async {
    final parsed = CsvImportService.parseCsv(csvContent);
    return CsvImportService.importRecords(parsed.rows, mapping, database: ServiceConfig.database);
  }

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  test('import creates new categories', () async {
    const csv = 'title,amount,date,category\n'
        'Groceries,-45.50,2024-01-15,Food\n'
        'Salary,3000,2024-01-20,Income\n'
        'Transport,-12.00,2024-02-01,Travel';

    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount',
      datetimeColumn: 'date',
      categoryColumn: 'category',
    );

    await importCsvString(csv, mapping);

    final categories = await ServiceConfig.database.getAllCategories();
    final names = categories.map((c) => c?.name).toSet();
    expect(names, contains('Food'));
    expect(names, contains('Income'));
    expect(names, contains('Travel'));
  });

  test('import skips duplicate categories', () async {
    // Pre-create a category with a unique name not present in default setup
    final existing = Category('UniqueTestCat', categoryType: CategoryType.expense);
    await ServiceConfig.database.addCategory(existing);

    const csv = 'title,amount,date,category\n'
        'Test,-50,2024-01-15,UniqueTestCat';

    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount',
      datetimeColumn: 'date',
      categoryColumn: 'category',
    );

    // Should not throw — duplicates are silently skipped
    await importCsvString(csv, mapping);

    final categories = await ServiceConfig.database.getAllCategories();
    final matchingCats = categories.where((c) => c?.name == 'UniqueTestCat');
    expect(matchingCats.length, 1);
  });

  test('import inserts records with correct values', () async {
    const csv = 'title,amount,date,category\n'
        'Groceries,-45.50,2024-01-15,Food\n'
        'Salary,3000,2024-01-20,Income';

    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount',
      datetimeColumn: 'date',
      categoryColumn: 'category',
    );

    await importCsvString(csv, mapping);

    final records = await ServiceConfig.database.getAllRecords();
    expect(records.length, 2);

    final titles = records.map((r) => r?.title).toSet();
    expect(titles, contains('Groceries'));
    expect(titles, contains('Salary'));

    final values = records.map((r) => r?.value).toSet();
    expect(values, contains(-45.50));
    expect(values, contains(3000.0));
  });

  test('import skips duplicate records', () async {
    const csv = 'title,amount,date,category\n'
        'Groceries,-45.50,2024-01-15,Food';

    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount',
      datetimeColumn: 'date',
      categoryColumn: 'category',
    );

    // First import
    await importCsvString(csv, mapping);

    final recordsAfterFirst = await ServiceConfig.database.getAllRecords();
    final count1 = recordsAfterFirst.length;
    expect(count1, 1);

    // Second import of same data — should be skipped as duplicate
    await importCsvString(csv, mapping);

    final recordsAfterSecond = await ServiceConfig.database.getAllRecords();
    expect(recordsAfterSecond.length, count1); // no new records
  });

  test('import assigns records to the default wallet', () async {
    const csv = 'title,amount,date\nTest,50,2024-06-01';
    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount',
      datetimeColumn: 'date',
    );

    await importCsvString(csv, mapping);

    final defaultWallet = await ServiceConfig.database.getDefaultWallet();
    expect(defaultWallet, isNotNull);

    final records = await ServiceConfig.database.getAllRecords();
    expect(records.length, 1);
    expect(records.first!.walletId, defaultWallet!.id);
  });

  test('import handles tags column', () async {
    const csv = 'title,amount,date,category,tags\n'
        'Groceries,-45.50,2024-01-15,Food,food;weekly';

    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount',
      datetimeColumn: 'date',
      categoryColumn: 'category',
      tagsColumn: 'tags',
    );

    await importCsvString(csv, mapping);

    final allTags = await ServiceConfig.database.getAllTags();
    expect(allTags, contains('food'));
    expect(allTags, contains('weekly'));
  });

  test('import handles comma-separated tags', () async {
    const csv = 'title,amount,date,tags\n'
        'Test,10,2024-05-01,tag1;tag2;tag3';

    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount',
      datetimeColumn: 'date',
      tagsColumn: 'tags',
    );

    await importCsvString(csv, mapping);

    final allTags = await ServiceConfig.database.getAllTags();
    expect(allTags, contains('tag1'));
    expect(allTags, contains('tag2'));
    expect(allTags, contains('tag3'));
  });

  test('import handles description column', () async {
    const csv = 'title,amount,date,description\n'
        'Test,50,2024-06-01,Some note here';

    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount',
      datetimeColumn: 'date',
      descriptionColumn: 'description',
    );

    await importCsvString(csv, mapping);

    final records = await ServiceConfig.database.getAllRecords();
    expect(records.length, 1);
    expect(records.first!.description, 'Some note here');
  });

  test('import with empty CSV does nothing', () async {
    const csv = 'title,amount,date';
    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount',
      datetimeColumn: 'date',
    );

    await importCsvString(csv, mapping);

    final records = await ServiceConfig.database.getAllRecords();
    // Should still have 0 records (default test DB has none)
    expect(records.length, 0);
  });

  test('import with missing amount column skips rows', () async {
    const csv = 'title,date,category\n'
        'Test,2024-01-15,Food\n'
        'Another,2024-02-01,Travel';

    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount', // this column doesn't exist!
      datetimeColumn: 'date',
      categoryColumn: 'category',
    );

    await importCsvString(csv, mapping);

    // amount column not in CSV → null values → rows skipped
    final records = await ServiceConfig.database.getAllRecords();
    expect(records.length, 0);
  });

  test('import with mixed valid and invalid rows', () async {
    const csv = 'title,amount,date,category\n'
        'Valid,42,2024-01-15,Food\n'
        'Invalid,not-a-number,2024-01-16,Travel\n'
        'Also Valid,-10,2024-01-17,Food';

    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount',
      datetimeColumn: 'date',
      categoryColumn: 'category',
    );

    await importCsvString(csv, mapping);

    final records = await ServiceConfig.database.getAllRecords();
    // 2 valid rows, 1 skipped
    expect(records.length, 2);
    final titles = records.map((r) => r?.title).toSet();
    expect(titles, contains('Valid'));
    expect(titles, contains('Also Valid'));
    expect(titles, isNot(contains('Invalid')));
  });

  test('import with semicolon delimited CSV', () async {
    const csv = 'title;amount;date;category\n'
        'Groceries;-45,50;2024-01-15;Food';

    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount',
      datetimeColumn: 'date',
      categoryColumn: 'category',
    );

    await importCsvString(csv, mapping);

    final records = await ServiceConfig.database.getAllRecords();
    expect(records.length, 1);
    expect(records.first!.title, 'Groceries');
    expect(records.first!.value, -45.50);
  });

  test('import uses Uncategorized when category column is not mapped', () async {
    const csv = 'title,amount,date\nTest,42,2024-01-15';

    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount',
      datetimeColumn: 'date',
    );

    await importCsvString(csv, mapping);

    final records = await ServiceConfig.database.getAllRecords();
    expect(records.length, 1);
    expect(records.first!.category!.name, 'Uncategorized');
  });

  test('full flow: parse → autoMap → import → verify', () async {
    const csv = 'Title,Amount,Date,Category,Note,Tags\n'
        'Lunch,-15.50,2024-03-10,Food,Restaurant meal,lunch;food\n'
        'Freelance,2000,2024-03-15,Income,Project payment,work\n'
        'Bus pass,-35,2024-03-01,Transport,Monthly,transport';

    final parsed = CsvImportService.parseCsv(csv);
    final mapping = CsvImportService.autoMap(parsed.headers);

    expect(mapping.titleColumn, 'Title');
    expect(mapping.valueColumn, 'Amount');
    expect(mapping.datetimeColumn, 'Date');
    expect(mapping.categoryColumn, 'Category');
    expect(mapping.descriptionColumn, 'Note');
    expect(mapping.tagsColumn, 'Tags');

    final preview = CsvImportService.buildPreview(parsed.rows, mapping);
    expect(preview.totalParsableRows, 3);
    expect(preview.uniqueCategories, containsAll(['Food', 'Income', 'Transport']));
    expect(preview.uniqueTags, containsAll(['lunch', 'food', 'work', 'transport']));

    await CsvImportService.importRecords(parsed.rows, mapping, database: ServiceConfig.database);

    final records = await ServiceConfig.database.getAllRecords();
    expect(records.length, 3);

    final allCategories = await ServiceConfig.database.getAllCategories();
    final catNames = allCategories.map((c) => c!.name).toSet();
    expect(catNames, containsAll(['Food', 'Income', 'Transport']));

    final allTags = await ServiceConfig.database.getAllTags();
    expect(allTags, containsAll(['lunch', 'food', 'work', 'transport']));
  });

  test('import with wallet column creates wallets and assigns records', () async {
    const csv = 'title,amount,date,wallet\n'
        'Coffee,-5,2024-06-01,Cash\n'
        'Rent,-800,2024-06-01,Bank\n'
        'Groceries,-50,2024-06-02,Cash';

    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount',
      datetimeColumn: 'date',
      walletColumn: 'wallet',
    );

    await importCsvString(csv, mapping);

    final wallets = await ServiceConfig.database.getAllWallets();
    final walletNames = wallets.map((w) => w.name).toSet();
    expect(walletNames, contains('Cash'));
    expect(walletNames, contains('Bank'));

    // Records should be assigned to the correct wallets
    final records = await ServiceConfig.database.getAllRecords();
    expect(records.length, 3);

    final cashWallet = wallets.firstWhere((w) => w.name == 'Cash');
    final bankWallet = wallets.firstWhere((w) => w.name == 'Bank');

    final cashRecords = records.where((r) => r!.walletId == cashWallet.id);
    expect(cashRecords.length, 2); // Coffee + Groceries

    final bankRecords = records.where((r) => r!.walletId == bankWallet.id);
    expect(bankRecords.length, 1); // Rent
  });

  test('import without wallet column assigns records to default wallet', () async {
    const csv = 'title,amount,date\nTest,42,2024-06-01';

    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount',
      datetimeColumn: 'date',
    );

    await importCsvString(csv, mapping);

    final defaultWallet = await ServiceConfig.database.getDefaultWallet();
    final records = await ServiceConfig.database.getAllRecords();
    expect(records.length, 1);
    expect(records.first!.walletId, defaultWallet!.id);
  });

  test('import reuses existing wallet by name', () async {
    // Pre-create a wallet
    final wallet = Wallet('MyBank', initialAmount: 100);
    await ServiceConfig.database.addWallet(wallet);

    const csv = 'title,amount,date,wallet\nDeposit,50,2024-06-01,MyBank';

    final mapping = CsvImportMapping(
      titleColumn: 'title',
      valueColumn: 'amount',
      datetimeColumn: 'date',
      walletColumn: 'wallet',
    );

    await importCsvString(csv, mapping);

    // Should still have only one "MyBank" wallet
    final wallets = await ServiceConfig.database.getAllWallets();
    final myBankWallets = wallets.where((w) => w.name == 'MyBank');
    expect(myBankWallets.length, 1);
  });
}
