import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/record.dart';

class CSVExporter {

  static createCSVFromRecordList(List<Record> records) {
    var recordsMap = List.generate(records.length, (index) => records[index].toMap());
    var csvLines = [];
    recordsMap.forEach((element) {
      element["date"] = getDateStr(new DateTime.fromMillisecondsSinceEpoch(element["datetime"]));
      element["category_type"] = element["category_type"] == 1 ? "Income" : "Expense";
      element.remove("id");
      element.remove("datetime");
      csvLines.add(element.values.join(","));
    });
    var recordsHeader = recordsMap[0].keys.join(",");
    csvLines.insert(0, recordsHeader);
    return csvLines.join("/n");
  }


}