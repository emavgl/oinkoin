import 'package:csv/csv.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/record.dart';

class CSVExporter {
  static createCSVFromRecordList(List<Record?> records) {
    var recordsMap =
        List.generate(records.length, (index) => records[index]!.toMap());
    List<List<dynamic>> csvLines = [];
    recordsMap.forEach((element) {
      element["date"] = getDateStr(
          new DateTime.fromMillisecondsSinceEpoch(element["datetime"]));
      element["category_type"] =
          element["category_type"] == 1 ? "Income" : "Expense";
      element.remove("id");
      element.remove("datetime");
      element.remove("recurrence_id");
      csvLines.add(element.values.toList());
    });
    var recordsHeader = recordsMap[0].keys.toList();
    csvLines.insert(0, recordsHeader);
    return ListToCsvConverter().convert(csvLines);
  }
}
