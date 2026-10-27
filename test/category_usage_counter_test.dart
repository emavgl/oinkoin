import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

final food = Category(
  'Counter food',
  color: Colors.green,
  categoryType: CategoryType.expense,
);

final travel = Category(
  'Counter travel',
  color: Colors.blue,
  categoryType: CategoryType.expense,
);

/// Category usage counters feed the "most used" sorting of the categories
/// page, and the trigger that maintains them used to increment them on every
/// record update, so editing a record inflated its category.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'UTC';
  });

  setUp(() async {
    await TestDatabaseHelper.setupTestDatabase();
  });

  Future<int> recordCountOf(String name) async {
    final categories = await ServiceConfig.database.getAllCategories();
    return categories
        .firstWhere((category) => category!.name == name)!
        .recordCount!;
  }

  Future<int> addRecordIn(Category category) {
    return ServiceConfig.database.addRecord(
      Record(-10.0, 'Record', category, DateTime.utc(2026, 1, 1, 12)),
    );
  }

  setUp(() async {
    await ServiceConfig.database.addCategory(food);
    await ServiceConfig.database.addCategory(travel);
  });

  test('adding records increments the category usage counter', () async {
    await addRecordIn(food);
    await addRecordIn(food);

    expect(await recordCountOf('Counter food'), 2);
    expect(await recordCountOf('Counter travel'), 0);
  });

  test('editing a record does not inflate its category usage counter',
      () async {
    final id = await addRecordIn(food);
    expect(await recordCountOf('Counter food'), 1);

    // Rename the record and change its amount a few times, as a user editing
    // the same record would.
    final record = (await ServiceConfig.database.getRecordById(id))!;
    for (var i = 0; i < 3; i++) {
      record.title = 'Edited $i';
      record.value = -(10.0 + i);
      await ServiceConfig.database.updateRecordById(id, record);
    }

    expect(
      await recordCountOf('Counter food'),
      1,
      reason: 'editing one record must not turn it into several',
    );
    expect(await recordCountOf('Counter travel'), 0);
  });

  test('moving a record to another category moves its usage count', () async {
    final id = await addRecordIn(food);
    expect(await recordCountOf('Counter food'), 1);

    final record = (await ServiceConfig.database.getRecordById(id))!;
    record.category = travel;
    await ServiceConfig.database.updateRecordById(id, record);

    expect(await recordCountOf('Counter food'), 0);
    expect(await recordCountOf('Counter travel'), 1);
  });

  test('deleting a record decrements the category usage counter', () async {
    final id = await addRecordIn(food);
    expect(await recordCountOf('Counter food'), 1);

    await ServiceConfig.database.deleteRecordById(id);

    expect(await recordCountOf('Counter food'), 0);
  });

  test('the counter is correct even when the stored column is stale', () async {
    await addRecordIn(food);
    await addRecordIn(food);

    // Simulate a database written by an older version (or restored from an old
    // backup), where the stored counter drifted away from the real value.
    final raw = await (ServiceConfig.database as SqliteDatabase).database;
    await raw!.update('categories', {'record_count': 99},
        where: 'name = ?', whereArgs: ['Counter food']);

    expect(await recordCountOf('Counter food'), 2);
  });

  test('the usage trigger does not count an edit as a new record', () async {
    final id = await addRecordIn(food);
    final raw = (await (ServiceConfig.database as SqliteDatabase).database)!;

    Future<int> storedCountOf(String name) async {
      final rows = await raw.query('categories',
          where: 'name = ?', whereArgs: [name], limit: 1);
      return (rows.first['record_count'] as int?) ?? 0;
    }

    expect(await storedCountOf('Counter food'), 1);

    final record = (await ServiceConfig.database.getRecordById(id))!;
    record.value = -20.0;
    record.title = 'Edited';
    await ServiceConfig.database.updateRecordById(id, record);
    expect(
      await storedCountOf('Counter food'),
      1,
      reason: 'the stored counter must stay at one record after an edit',
    );

    // Changing the category still moves the count from one to the other.
    record.category = travel;
    await ServiceConfig.database.updateRecordById(id, record);
    expect(await storedCountOf('Counter food'), 0);
    expect(await storedCountOf('Counter travel'), 1);
  });
}
