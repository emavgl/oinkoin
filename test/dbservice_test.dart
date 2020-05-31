import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/helpers/records-generator.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/sqlite-database.dart';
import 'dart:ui';


main() {
  group('database service test', () {

    test('fetch one category', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await SqliteDatabase.instance.deleteTables();
      Category category = new Category("testName", color: Colors.red as Color, iconCodePoint: FontAwesomeIcons.film.codePoint);
      await SqliteDatabase.instance.addCategoryIfNotExists(category);
      Category retrievedCategory = await SqliteDatabase.instance.getCategoryById(1);
      expect(retrievedCategory.name, "testName");
      expect(retrievedCategory.id, 1);
      expect(retrievedCategory.color.red, Colors.red.red);
      expect(retrievedCategory.color.blue, Colors.red.blue);
      expect(retrievedCategory.color.green, Colors.red.green);
      expect(retrievedCategory.iconCodePoint, FontAwesomeIcons.film.codePoint);
    });

    test('fetch multiple categories', () async {
      await SqliteDatabase.instance.deleteTables();
      TestWidgetsFlutterBinding.ensureInitialized();
      Category category1 = new Category("testName1");
      Category category2 = new Category("testName2");
      await SqliteDatabase.instance.addCategoryIfNotExists(category1);
      await SqliteDatabase.instance.addCategoryIfNotExists(category2);
      List<Category> retrievedCategories = await SqliteDatabase.instance.getAllCategories();
      expect(retrievedCategories.length, 2);
    });

    test('fetch one movement', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      Record movement = RecordsGenerator.getRandomRecord(DateTime.now());
      await SqliteDatabase.instance.addRecord(movement);
      Record retrievedMovement = await SqliteDatabase.instance.getRecordById(1);
      expect(retrievedMovement.value, movement.value);
      expect(retrievedMovement.dateTime.millisecondsSinceEpoch, movement.dateTime.millisecondsSinceEpoch);
      expect(retrievedMovement.id, 1);
    });

    test('fetch multiple movements', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      Record movement = RecordsGenerator.getRandomRecord(DateTime.now());
      Record movement2 = RecordsGenerator.getRandomRecord(DateTime.now().add(Duration(seconds: 5)));
      await SqliteDatabase.instance.addRecord(movement);
      await SqliteDatabase.instance.addRecord(movement2);
      List<Record> retrievedMovements = await SqliteDatabase.instance.getAllRecords();
      expect(retrievedMovements.length, 2);
    });


    test('fetch multiple with Interval', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      Record movement = RecordsGenerator.getRandomRecord(DateTime.parse("2020-04-10 13:00:00"));
      Record movement2 = RecordsGenerator.getRandomRecord(DateTime.parse("2020-04-12 13:00:00"));
      Record movement3 = RecordsGenerator.getRandomRecord(DateTime.parse("2020-05-10 13:00:00"));
      int movementId1 = await SqliteDatabase.instance.addRecord(movement);
      int movementId2 = await SqliteDatabase.instance.addRecord(movement2);
      int movementId3 = await SqliteDatabase.instance.addRecord(movement3);
      DateTime from = DateTime.parse("2020-04-01 00:00:00");
      DateTime to = DateTime.parse("2020-04-30 00:00:00");
      List<Record> retrievedMovements = await SqliteDatabase.instance.getAllRecordsInInterval(from, to);
      expect(retrievedMovements.length, 2);
      expect(retrievedMovements[0].id != movementId3, true);
      expect(retrievedMovements[1].id != movementId3, true);
    });

    tearDown(() async {
      await SqliteDatabase.instance.deleteTables();
    });

  });
}
