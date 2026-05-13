import 'package:csv/csv.dart';
import 'package:piggybank/models/record.dart';
import 'logger.dart';

class CSVExporter {

  static final _logger = Logger.withClass(CSVExporter);

  /// Creates a CSV string from a list of records.
  ///
  /// Transfers are excluded from the export. [walletNames] maps wallet IDs
  /// to their display names so the CSV contains wallet names instead of IDs.
  static createCSVFromRecordList(List<Record?> records, {Map<int, String>? walletNames}) {
    try {
      // Exclude transfers
      final nonTransferRecords = records.where((r) => r != null && !r.isTransfer).toList();
      _logger.debug('Creating CSV from ${nonTransferRecords.length} records (${records.length - nonTransferRecords.length} transfers excluded)...');

      var recordsMap = List.generate(
        nonTransferRecords.length,
        (index) => nonTransferRecords[index]!.toCsvMap(walletNames: walletNames),
      );
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
        csvLines.insert(0, ['title', 'value', 'datetime', 'category_name', 'category_type', 'description', 'tags', 'wallet']);
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
