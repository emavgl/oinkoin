import 'package:csv/csv.dart';
import 'package:piggybank/models/record.dart';

class CSVExporter {
  static createCSVFromRecordList(List<Record?> records) {
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
      csvLines.insert(0, ['title', 'value', 'datetime', 'category_name', 'category_type', 'description', 'tags']);
    }
    return ListToCsvConverter().convert(csvLines);
  }
}
