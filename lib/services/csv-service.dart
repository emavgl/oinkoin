import 'package:csv/csv.dart';
import 'package:piggybank/models/record.dart';
import 'logger.dart';

class CSVExporter {
  static final _logger = Logger.withClass(CSVExporter);

  static createCSVFromRecordList(List<Record?> records) {
    try {
      _logger.debug('Creating CSV from ${records.length} records...');
      var recordsMap =
          List.generate(records.length, (index) => records[index]!.toCsvMap());
      List<List<dynamic>> csvLines = [];
      if (recordsMap.isNotEmpty) {
        recordsMap.forEach((element) {
          csvLines.add(element.values.toList());
        });
        var recordsHeader = recordsMap[0].keys.toList();
        csvLines.insert(0, recordsHeader);
      } else {
        // Provide a default header if no records are present
        _logger.warning('No records to export, using default header');
        csvLines.insert(0, [
          'title',
          'value',
          'datetime',
          'category_name',
          'category_type',
          'description',
          'tags'
        ]);
      }
      var csv = ListToCsvConverter().convert(csvLines);
      _logger.info('CSV created: ${csvLines.length} lines (including header)');
      return csv;
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to create CSV');
      rethrow;
    }
  }
}
