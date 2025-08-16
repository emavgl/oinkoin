
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/csv-service.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:csv/csv.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:piggybank/services/service-config.dart';

void main() {
  group('CSVExporter', () {

    setUpAll(() {
      tz.initializeTimeZones();
      ServiceConfig.localTimezone = "Europe/Vienna";
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('createCSVFromRecordList should return a valid CSV string', () {
      final category1 = Category('Food', categoryType: CategoryType.expense);
      final category2 = Category('Salary', categoryType: CategoryType.income);

      final records = [
        Record(10.0, 'Test Record 1', category1, DateTime(2023, 1, 1), id: 1, description: 'Description 1'),
        Record(20.0, 'Test Record 2', category2, DateTime(2023, 1, 2), id: 2, description: 'Description 2'),
      ];
      final csv = CSVExporter.createCSVFromRecordList(records);
      expect(csv, isA<String>());

      final converter = CsvToListConverter();
      final List<List<dynamic>> parsedCsv = converter.convert(csv);

      expect(parsedCsv.length, 3); // Header + 2 records
      expect(parsedCsv[0][0], 'title');
      expect(parsedCsv[1][0], 'Test Record 1');
      expect(parsedCsv[2][0], 'Test Record 2');
    });

    test('createCSVFromRecordList should handle special characters in title and description', () {
      final category = Category('Utilities', categoryType: CategoryType.expense);
      final records = [
        Record(
          10.0,
          'Test, Record with comma',
          category,
          DateTime(2023, 1, 1),
          id: 1,
          description: 'Description with\nnewline and "quotes"',
        ),
      ];
      final csv = CSVExporter.createCSVFromRecordList(records);
      
      final converter = CsvToListConverter();
      final List<List<dynamic>> parsedCsv = converter.convert(csv);

      expect(parsedCsv[1][0], 'Test, Record with comma');
      expect(parsedCsv[1][5], 'Description with\nnewline and "quotes"');
    });

    test('createCSVFromRecordList should handle tags correctly (no commas in tags)', () {
      final category = Category('Shopping', categoryType: CategoryType.expense);
      final records = [
        Record(
          10.0,
          'Record with tags',
          category,
          DateTime(2023, 1, 1),
          id: 1,
          description: 'Description',
          tags: ['tag1', 'tag2', 'tag3'],
        ),
      ];
      final csv = CSVExporter.createCSVFromRecordList(records);
      
      final converter = CsvToListConverter();
      final List<List<dynamic>> parsedCsv = converter.convert(csv);

      expect(parsedCsv[1][6], 'tag1:tag2:tag3');
    });

    test('createCSVFromRecordList should handle empty record list', () {
      final records = <Record>[];
      final csv = CSVExporter.createCSVFromRecordList(records);

      final converter = CsvToListConverter();
      final List<List<dynamic>> parsedCsv = converter.convert(csv);

      expect(parsedCsv.length, 1);
      expect(parsedCsv[0][0], 'title');
      expect(parsedCsv[0][1], 'value');
    });
  });
}
