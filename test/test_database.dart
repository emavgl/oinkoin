import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

Future main() async {
  // A helper category for use in tests
  final testCategoryExpense = Category(
    "Rent",
    iconCodePoint: 1,
    categoryType: CategoryType.expense,
    color: Colors.blue,
  );

  final testCategoryIncome = Category(
    "Salary",
    iconCodePoint: 2,
    categoryType: CategoryType.income,
    color: Colors.green,
  );

  final testCategoryExpense2 = Category(
    "Groceries",
    iconCodePoint: 3,
    categoryType: CategoryType.expense,
    color: Colors.orange,
  );

  // Setup sqflite_common_ffi for flutter test
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory
    databaseFactory = databaseFactoryFfi;

    tz.initializeTimeZones();
    ServiceConfig.localTimezone = "Europe/Vienna";
  });

  setUp(() async {
    // Reset the database before each test to ensure a clean state
    DatabaseInterface db = ServiceConfig.database;
    await db.deleteDatabase();
  });

  group('Category CRUD', () {
    test('Insert and retrieve category', () async {
      DatabaseInterface db = ServiceConfig.database;
      var testCategory = Category("Rent",
          iconCodePoint: 1, categoryType: CategoryType.expense);
      var categoryId = await db.addCategory(testCategory);
      expect(categoryId, 1);
    });

    test('getAllCategories should return all categories', () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      await db.addCategory(testCategoryIncome);
      var allCategories = await db.getAllCategories();
      expect(allCategories.length, 2);
    });

    test('getCategoriesByType should return categories of a specific type',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      await db.addCategory(testCategoryIncome);
      var expenseCategories =
          await db.getCategoriesByType(CategoryType.expense);
      var incomeCategories = await db.getCategoriesByType(CategoryType.income);
      expect(expenseCategories.length, 1);
      expect(incomeCategories.length, 1);
    });

    test('getCategory should retrieve a specific category', () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      var retrievedCategory = await db.getCategory(
          testCategoryExpense.name!, testCategoryExpense.categoryType!);
      expect(retrievedCategory?.name, testCategoryExpense.name);
      expect(retrievedCategory?.categoryType, testCategoryExpense.categoryType);
    });

    test('updateCategory should modify an existing category', () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);

      var updatedCategory = Category(
        "New Rent",
        iconCodePoint: 10,
        categoryType: CategoryType.expense,
        color: Colors.red.shade300,
      );
      await db.updateCategory(testCategoryExpense.name,
          testCategoryExpense.categoryType, updatedCategory);
      var retrievedCategory =
          await db.getCategory("New Rent", CategoryType.expense);
      expect(retrievedCategory?.name, "New Rent");
      expect(retrievedCategory?.color, Colors.red.shade300);
    });

    test('deleteCategory should remove a category from the database', () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      await db.deleteCategory(
          testCategoryExpense.name, testCategoryExpense.categoryType);
      var retrievedCategory = await db.getCategory(
          testCategoryExpense.name!, testCategoryExpense.categoryType!);
      expect(retrievedCategory, isNull);
    });

    test('archiveCategory should toggle the archived status', () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      // Initially not archived
      var retrievedCategory = await db.getCategory(
          testCategoryExpense.name!, testCategoryExpense.categoryType!);
      expect(retrievedCategory?.isArchived, false);

      // Archive the category
      await db.archiveCategory(
          testCategoryExpense.name!, testCategoryExpense.categoryType!, true);
      retrievedCategory = await db.getCategory(
          testCategoryExpense.name!, testCategoryExpense.categoryType!);
      expect(retrievedCategory?.isArchived, true);

      // Unarchive the category
      await db.archiveCategory(
          testCategoryExpense.name!, testCategoryExpense.categoryType!, false);
      retrievedCategory = await db.getCategory(
          testCategoryExpense.name!, testCategoryExpense.categoryType!);
      expect(retrievedCategory?.isArchived, false);
    });

    test('resetCategoryOrderIndexes should update the order of categories',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      var cat1 = Category("Cat1", sortOrder: 0);
      var cat2 = Category("Cat2", sortOrder: 1);
      await db.addCategory(cat1);
      await db.addCategory(cat2);

      // Swap the order
      var newOrderedList = [
        Category("Cat2", sortOrder: 0),
        Category("Cat1", sortOrder: 1),
      ];

      await db.resetCategoryOrderIndexes(newOrderedList);
      var allCategories = await db.getAllCategories();

      // We expect the first category to be Cat2 and the second to be Cat1
      expect(allCategories[0]?.name, "Cat1");
      expect(allCategories[0]?.sortOrder, 1);
      expect(allCategories[1]?.name, "Cat2");
      expect(allCategories[1]?.sortOrder, 0);
    });
  });

  group('Record CRUD', () {
    test('addRecord should insert a record and return its id', () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      var record = Record(
        100.0,
        "Test Record",
        testCategoryExpense,
        DateTime.now().toUtc(),
        tags: ['test-tag-1', 'test-tag-2'].toSet(),
      );
      var recordId = await db.addRecord(record);
      expect(recordId, isNotNull);

      // Verify tags are stored
      var retrievedRecord = await db.getRecordById(recordId);
      expect(retrievedRecord?.tags, containsAll(['test-tag-1', 'test-tag-2']));
    });

    test('getRecordById should retrieve a record by its id', () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      var record = Record(
        100.0,
        "Test Record",
        testCategoryExpense,
        DateTime.now().toUtc(),
        tags: ['initial-tag'].toSet(),
      );
      var recordId = await db.addRecord(record);
      var retrievedRecord = await db.getRecordById(recordId);
      expect(retrievedRecord?.id, recordId);
      expect(retrievedRecord?.title, "Test Record");
      expect(retrievedRecord?.tags, containsAll(['initial-tag']));
    });

    test('addRecordsInBatch should insert multiple records at once', () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      var record1 = Record(
          10.0, "Coffee", testCategoryExpense, DateTime.now().toUtc(),
          tags: ['morning'].toSet());
      var record2 = Record(
          20.0, "Tea", testCategoryExpense, DateTime.now().toUtc(),
          tags: ['evening', 'drink'].toSet());
      await db.addRecordsInBatch([record1, record2]);
      var allRecords = await db.getAllRecords();
      expect(allRecords.length, 2);
      expect(allRecords[0]?.tags, containsAll(['morning']));
      expect(allRecords[1]?.tags, containsAll(['evening', 'drink']));
    });

    test('updateRecordById should modify an existing record', () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      var record = Record(
          100.0, "Test Record", testCategoryExpense, DateTime.now().toUtc(),
          tags: ['old-tag'].toSet());
      var recordId = await db.addRecord(record);

      var newRecord = Record(
        200.0,
        "Updated Record",
        testCategoryExpense,
        DateTime.now().toUtc(),
        tags: ['new-tag-1', 'new-tag-2'].toSet(),
      );
      await db.updateRecordById(recordId, newRecord);
      var retrievedRecord = await db.getRecordById(recordId);
      expect(retrievedRecord?.value, 200.0);
      expect(retrievedRecord?.title, "Updated Record");
      expect(retrievedRecord?.tags, containsAll(['new-tag-1', 'new-tag-2']));
    });

    test('deleteRecordById should remove a record from the database', () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      var record = Record(
          100.0, "Test Record", testCategoryExpense, DateTime.now().toUtc());
      var recordId = await db.addRecord(record);
      await db.deleteRecordById(recordId);
      var retrievedRecord = await db.getRecordById(recordId);
      expect(retrievedRecord, isNull);
    });

    test('getAllRecordsInInterval should return records within a date range',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      var record1 = Record(
          10.0, "Record 1", testCategoryExpense, DateTime.utc(2023, 1, 1),
          tags: ['tag1'].toSet());
      var record2 = Record(
          20.0, "Record 2", testCategoryExpense, DateTime.utc(2023, 1, 15),
          tags: ['tag2', 'tag3'].toSet());
      var record3 = Record(
          30.0, "Record 3", testCategoryExpense, DateTime.utc(2023, 2, 1),
          tags: ['tag4'].toSet());
      await db.addRecordsInBatch([record1, record2, record3]);

      var from = DateTime.utc(2023, 1, 10);
      var to = DateTime.utc(2023, 1, 20);
      var recordsInInterval = await db.getAllRecordsInInterval(from, to);
      expect(recordsInInterval.length, 1);
      expect(recordsInInterval[0]?.title, "Record 2");
      expect(recordsInInterval[0]?.tags, containsAll(['tag2', 'tag3']));
    });

    test('getDateTimeFirstRecord should return the earliest record date',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      var record1 = Record(
          10.0, "Record 1", testCategoryExpense, DateTime.utc(2024, 1, 1));
      var record2 = Record(
          20.0, "Record 2", testCategoryExpense, DateTime.utc(2023, 1, 15));
      await db.addRecordsInBatch([record1, record2]);

      var firstDate = await db.getDateTimeFirstRecord();
      expect(firstDate, DateTime.utc(2023, 1, 15));
    });

    test('getMatchingRecord should find a record with the same properties',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      var record = Record(100.0, "Test Record", testCategoryExpense,
          DateTime.utc(2023, 10, 26, 12, 0, 0),
          tags: ['match-tag'].toSet());
      await db.addRecord(record);

      var matchingRecord = await db.getMatchingRecord(record);
      expect(matchingRecord?.title, record.title);
      expect(matchingRecord?.value, record.value);
      expect(matchingRecord?.tags, containsAll(['match-tag']));
    });

    test(
        'deleteFutureRecordsByPatternId should remove records with a specific pattern ID after a certain date',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      var recordPatternId = "pattern-1";
      var record1 = Record(
          10.0, "Recurrent 1", testCategoryExpense, DateTime.utc(2023, 1, 1),
          recurrencePatternId: recordPatternId);
      var record2 = Record(
          10.0, "Recurrent 2", testCategoryExpense, DateTime.utc(2023, 2, 1),
          recurrencePatternId: recordPatternId);
      var record3 = Record(
          10.0, "Recurrent 3", testCategoryExpense, DateTime.utc(2023, 3, 1),
          recurrencePatternId: recordPatternId);
      await db.addRecordsInBatch([record1, record2, record3]);

      await db.deleteFutureRecordsByPatternId(
          recordPatternId, DateTime.utc(2023, 1, 15));
      var allRecords = await db.getAllRecords();
      expect(allRecords.length, 1);
      expect(allRecords[0]?.title, "Recurrent 1");
    });

    test(
        'suggestedRecordTitles should return titles for a specific category and search term',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      await db.addRecord(Record(
          10.0, "Lunch at Cafe", testCategoryExpense, DateTime.now().toUtc()));
      await db.addRecord(Record(12.0, "Dinner at a different cafe",
          testCategoryExpense, DateTime.now().toUtc()));
      await db.addRecord(
          Record(5.0, "Coffee", testCategoryExpense2, DateTime.now().toUtc()));

      var suggestions =
          await db.suggestedRecordTitles("cafe", testCategoryExpense.name!);
      expect(suggestions.length, 2);
      expect(suggestions, contains("Lunch at Cafe"));
      expect(suggestions, contains("Dinner at a different cafe"));
    });

    test('records should match based on their localTime', () async {
      // Let's say that the user is using this app for tracking expenses.
      // The user goes on vacation in US. In US he takes a caffe
      // at 2023-01-01 19:00:00.000-0500 which is already
      // DateTime.utc(2023, 1, 2, 0, 0) in Vienna.
      // When coming back to Vienna the next days.
      // He wants to see all the expenses in US that he has done 2023-01-01.
      // Than that expense should be included.
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);

      final utcDateTime = DateTime.utc(2023, 1, 2, 0, 0);

      await db.addRecord(Record(
          10.0, "Record 1", testCategoryExpense, utcDateTime,
          timeZoneName: "America/New_York"));

      await db.addRecord(
          Record(10.0, "Record 2", testCategoryExpense, utcDateTime));

      final from = DateTime(2023, 1, 1, 0, 0);
      final to = DateTime(2023, 1, 1, 23, 59);

      var records = await db.getAllRecordsInInterval(from, to);
      expect(records.length, 1);
      expect(records[0]!.title, contains("Record 1"));
    });

    test(
        'getAggregatedRecordsByTagInInterval should return aggregated values by tag',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      await db.addCategory(testCategoryIncome);

      // Create records with different tags and dates
      var record1 = Record(
          10.0, "Groceries", testCategoryExpense, DateTime.utc(2023, 1, 1),
          tags: ['food', 'shopping'].toSet());
      var record2 = Record(
          20.0, "Dinner", testCategoryExpense, DateTime.utc(2023, 1, 15),
          tags: ['food', 'restaurant'].toSet());
      var record3 = Record(
          15.0, "Gas", testCategoryExpense, DateTime.utc(2023, 1, 20),
          tags: ['transport', 'car'].toSet());
      var record4 = Record(
          50.0, "Salary", testCategoryIncome, DateTime.utc(2023, 1, 10),
          tags: ['income', 'work'].toSet());
      var record5 = Record(
          30.0, "Lunch", testCategoryExpense, DateTime.utc(2023, 2, 1),
          tags: ['food'].toSet());

      await db.addRecordsInBatch([record1, record2, record3, record4, record5]);

      // Test for January records
      var from = DateTime.utc(2023, 1, 1);
      var to = DateTime.utc(2023, 1, 31);
      var aggregatedTags =
          await db.getAggregatedRecordsByTagInInterval(from, to);

      expect(aggregatedTags.length,
          5); // food, shopping, restaurant, transport, car, income, work

      // Verify specific tag aggregations
      expect(
          aggregatedTags
              .firstWhere((element) => element['key'] == 'food')['value'],
          30.0); // 10 (record1) + 20 (record2)
      expect(
          aggregatedTags
              .firstWhere((element) => element['key'] == 'shopping')['value'],
          10.0);
      expect(
          aggregatedTags
              .firstWhere((element) => element['key'] == 'restaurant')['value'],
          20.0);
      expect(
          aggregatedTags
              .firstWhere((element) => element['key'] == 'transport')['value'],
          15.0);
      expect(
          aggregatedTags
              .firstWhere((element) => element['key'] == 'car')['value'],
          15.0);
      expect(
          aggregatedTags
              .firstWhere((element) => element['key'] == 'income')['value'],
          50.0);
      expect(
          aggregatedTags
              .firstWhere((element) => element['key'] == 'work')['value'],
          50.0);

      // Test for February records
      from = DateTime.utc(2023, 2, 1);
      to = DateTime.utc(2023, 2, 28);
      aggregatedTags = await db.getAggregatedRecordsByTagInInterval(from, to);

      expect(aggregatedTags.length, 1);
      expect(
          aggregatedTags
              .firstWhere((element) => element['key'] == 'food')['value'],
          30.0);
    });
  });

  group('Recurrent Records Patterns CRUD', () {
    // Correctly creating a RecurrentRecordPattern object using the main constructor
    final testRecurrentPattern = RecurrentRecordPattern(
      500.0, // value
      "Monthly Rent", // title
      testCategoryExpense, // category
      DateTime.utc(2023, 1, 1), // utcDateTime
      RecurrentPeriod.EveryMonth, // recurrentPeriod
      id: "pattern-1", // optional id
      tags: ['home', 'rent'].toSet(),
    );

    test('addRecurrentRecordPattern should insert a pattern', () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      await db.addRecurrentRecordPattern(testRecurrentPattern);
      var retrievedPattern =
          await db.getRecurrentRecordPattern(testRecurrentPattern.id);
      expect(retrievedPattern, isNotNull);
      expect(retrievedPattern?.title, "Monthly Rent");
      expect(retrievedPattern?.tags, containsAll(['home', 'rent']));
    });

    test('getRecurrentRecordPattern should retrieve a specific pattern by id',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      await db.addRecurrentRecordPattern(testRecurrentPattern);
      var retrievedPattern =
          await db.getRecurrentRecordPattern(testRecurrentPattern.id);
      expect(retrievedPattern?.id, testRecurrentPattern.id);
      expect(retrievedPattern?.tags, containsAll(['home', 'rent']));
    });

    test('getRecurrentRecordPatterns should return all patterns', () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      await db.addCategory(testCategoryIncome);

      final secondRecurrentPattern = RecurrentRecordPattern(
        1000.0,
        "Weekly Salary",
        testCategoryIncome,
        DateTime.utc(2023, 1, 1),
        RecurrentPeriod.EveryWeek,
        id: "pattern-2",
        tags: ['work', 'income'].toSet(),
      );

      await db.addRecurrentRecordPattern(testRecurrentPattern);
      await db.addRecurrentRecordPattern(secondRecurrentPattern);

      var allPatterns = await db.getRecurrentRecordPatterns();
      expect(allPatterns.length, 2);
      expect(allPatterns[0]?.tags, containsAll(['home', 'rent']));
      expect(allPatterns[1]?.tags, containsAll(['work', 'income']));
    });

    test('updateRecordPatternById should modify an existing pattern', () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      await db.addRecurrentRecordPattern(testRecurrentPattern);

      var updatedPattern = RecurrentRecordPattern(
        600.0,
        "New Monthly Rent",
        testCategoryExpense,
        DateTime.utc(2023, 2, 1),
        RecurrentPeriod.EveryMonth,
        id: testRecurrentPattern.id,
        tags: ['new-home', 'new-rent', 'updated'].toSet(),
      );

      await db.updateRecordPatternById(testRecurrentPattern.id, updatedPattern);
      var retrievedPattern =
          await db.getRecurrentRecordPattern(testRecurrentPattern.id);
      expect(retrievedPattern?.title, "New Monthly Rent");
      expect(retrievedPattern?.value, 600.0);
      expect(retrievedPattern?.tags,
          containsAll(['new-home', 'new-rent', 'updated']));
    });

    test('deleteRecurrentRecordPatternById should remove a pattern', () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);
      await db.addRecurrentRecordPattern(testRecurrentPattern);
      await db.deleteRecurrentRecordPatternById(testRecurrentPattern.id);
      var retrievedPattern =
          await db.getRecurrentRecordPattern(testRecurrentPattern.id);
      expect(retrievedPattern, isNull);
    });
  });

  group('Tag related operations', () {
    test(
        'getRecentlyUsedTags should return distinct tags from the 10 most recent records',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);

      // Add more than 10 records to ensure LIMIT works, with varied tags and dates
      for (int i = 0; i < 15; i++) {
        await db.addRecord(
          Record(
            10.0 + i,
            "Record $i",
            testCategoryExpense,
            DateTime.now()
                .toUtc()
                .subtract(Duration(days: i)), // Newer records have smaller 'i'
            tags: ['tag${i % 5}', 'common-tag'].toSet(), // Some tags repeat
          ),
        );
      }

      // Add a very old record with a unique tag that should not be returned
      await db.addRecord(
        Record(
          999.0,
          "Old Record",
          testCategoryExpense,
          DateTime.utc(2000, 1, 1),
          tags: ['very-old-tag'].toSet(),
        ),
      );

      final recentlyUsedTags = await db.getRecentlyUsedTags();

      // Expect tags from the 10 most recent records
      // The most recent 10 records will have tags from tag0 to tag4 and common-tag.
      // Since we have 15 records and tags are 'tag${i % 5}', the tags will be
      // tag0, tag1, tag2, tag3, tag4, and 'common-tag'.
      expect(recentlyUsedTags.length, 6); // 5 unique tags + 'common-tag'
      expect(recentlyUsedTags,
          containsAll({'tag0', 'tag1', 'tag2', 'tag3', 'tag4', 'common-tag'}));
      expect(recentlyUsedTags, isNot(contains('very-old-tag')));
    });

    test(
        'records generated from recurrent patterns should include pattern tags',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);

      // Create a recurrent pattern with tags
      final pattern = RecurrentRecordPattern(
        100.0,
        "Monthly Subscription",
        testCategoryExpense,
        DateTime.utc(2023, 1, 1),
        RecurrentPeriod.EveryMonth,
        tags: {'subscription', 'recurring', 'digital'}.toSet(),
      );

      await db.addRecurrentRecordPattern(pattern);

      // Simulate generating records from the pattern (what happens in updateRecurrentRecords)
      final records = [
        Record(
          pattern.value,
          pattern.title,
          pattern.category,
          DateTime.utc(2023, 1, 1),
          recurrencePatternId: pattern.id,
          tags: pattern.tags,
        ),
        Record(
          pattern.value,
          pattern.title,
          pattern.category,
          DateTime.utc(2023, 2, 1),
          recurrencePatternId: pattern.id,
          tags: pattern.tags,
        ),
        Record(
          pattern.value,
          pattern.title,
          pattern.category,
          DateTime.utc(2023, 3, 1),
          recurrencePatternId: pattern.id,
          tags: pattern.tags,
        ),
      ];

      // Add records in batch as the recurrent service does
      await db.addRecordsInBatch(records);

      // Retrieve records and verify tags are present
      final allRecords = await db.getAllRecords();
      expect(allRecords.length, 3);

      for (var record in allRecords) {
        expect(record?.tags, isNotEmpty,
            reason: 'Record should have tags from pattern');
        expect(
            record?.tags, containsAll(['subscription', 'recurring', 'digital']),
            reason:
                'Record should contain all tags from the recurrent pattern');
      }
    });
  });
}
