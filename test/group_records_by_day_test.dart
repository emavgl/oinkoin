import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:timezone/data/latest_all.dart' as tz;

final _category = Category(
  'Food',
  color: Colors.green,
  categoryType: CategoryType.expense,
);

Record makeRecord({
  required double value,
  required DateTime utcDateTime,
  int? id,
  String timeZone = 'UTC',
}) {
  return Record(
    value,
    'Test',
    _category,
    utcDateTime,
    id: id,
    timeZoneName: timeZone,
  );
}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('groupRecordsByDay – day grouping', () {
    test('records on different days produce separate groups', () {
      final records = [
        makeRecord(value: 1, utcDateTime: DateTime.utc(2026, 5, 1, 10, 0)),
        makeRecord(value: 2, utcDateTime: DateTime.utc(2026, 5, 2, 10, 0)),
        makeRecord(value: 3, utcDateTime: DateTime.utc(2026, 5, 3, 10, 0)),
      ];

      final result = groupRecordsByDay(records);

      expect(result.length, 3);
    });

    test('records on the same day are in one group', () {
      final records = [
        makeRecord(value: 1, utcDateTime: DateTime.utc(2026, 5, 1, 8, 0)),
        makeRecord(value: 2, utcDateTime: DateTime.utc(2026, 5, 1, 14, 0)),
        makeRecord(value: 3, utcDateTime: DateTime.utc(2026, 5, 1, 20, 0)),
      ];

      final result = groupRecordsByDay(records);

      expect(result.length, 1);
      expect(result.first.records!.length, 3);
    });

    test('days are ordered most-recent first', () {
      final records = [
        makeRecord(value: 1, utcDateTime: DateTime.utc(2026, 5, 1, 10, 0)),
        makeRecord(value: 3, utcDateTime: DateTime.utc(2026, 5, 3, 10, 0)),
        makeRecord(value: 2, utcDateTime: DateTime.utc(2026, 5, 2, 10, 0)),
      ];

      final result = groupRecordsByDay(records);

      expect(result[0].dateTime!.day, 3);
      expect(result[1].dateTime!.day, 2);
      expect(result[2].dateTime!.day, 1);
    });

    test('null records are ignored', () {
      final records = [
        makeRecord(value: 1, utcDateTime: DateTime.utc(2026, 5, 1, 10, 0)),
        null,
        makeRecord(value: 2, utcDateTime: DateTime.utc(2026, 5, 2, 10, 0)),
      ];

      final result = groupRecordsByDay(records);

      expect(result.length, 2);
    });
  });

  group('groupRecordsByDay – within-day ordering', () {
    test('records within a day are ordered by time descending', () {
      final records = [
        makeRecord(value: 1, utcDateTime: DateTime.utc(2026, 5, 1, 8, 0)),
        makeRecord(value: 2, utcDateTime: DateTime.utc(2026, 5, 1, 20, 0)),
        makeRecord(value: 3, utcDateTime: DateTime.utc(2026, 5, 1, 12, 0)),
      ];

      final dayRecords = groupRecordsByDay(records).first.records!;

      expect(dayRecords[0]!.value, 2); // 20:00 first
      expect(dayRecords[1]!.value, 3); // 12:00 second
      expect(dayRecords[2]!.value, 1); // 08:00 last
    });

    test('records with identical datetimes preserve insertion order (id desc)',
        () {
      final sameTime = DateTime.utc(2026, 5, 1, 10, 0);
      final records = [
        makeRecord(value: 10, utcDateTime: sameTime, id: 1),
        makeRecord(value: 20, utcDateTime: sameTime, id: 2),
        makeRecord(value: 30, utcDateTime: sameTime, id: 3),
      ];

      final dayRecords = groupRecordsByDay(records).first.records!;

      // Higher id (more recently inserted) appears first
      expect(dayRecords[0]!.id, 3);
      expect(dayRecords[1]!.id, 2);
      expect(dayRecords[2]!.id, 1);
    });

    test('time ordering takes priority over insertion order', () {
      final records = [
        makeRecord(
            value: 1, utcDateTime: DateTime.utc(2026, 5, 1, 20, 0), id: 1),
        makeRecord(
            value: 2, utcDateTime: DateTime.utc(2026, 5, 1, 8, 0), id: 2),
      ];

      final dayRecords = groupRecordsByDay(records).first.records!;

      // id=1 was inserted first but has a later time — it should appear first
      expect(dayRecords[0]!.id, 1);
      expect(dayRecords[1]!.id, 2);
    });

    test('mixed times and same times are ordered correctly', () {
      final t10 = DateTime.utc(2026, 5, 1, 10, 0);
      final t20 = DateTime.utc(2026, 5, 1, 20, 0);
      final records = [
        makeRecord(value: 1, utcDateTime: t10, id: 1),
        makeRecord(value: 2, utcDateTime: t20, id: 2),
        makeRecord(value: 3, utcDateTime: t10, id: 3),
        makeRecord(value: 4, utcDateTime: t20, id: 4),
      ];

      final dayRecords = groupRecordsByDay(records).first.records!;

      // t20 records first (id 4 then 2), t10 records after (id 3 then 1)
      expect(dayRecords[0]!.id, 4);
      expect(dayRecords[1]!.id, 2);
      expect(dayRecords[2]!.id, 3);
      expect(dayRecords[3]!.id, 1);
    });
  });
}
