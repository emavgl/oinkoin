import 'package:intl/intl.dart';

class DateTimeSeriesRecord {
  DateTime? time;
  double value;

  DateTimeSeriesRecord(this.time, this.value);
}

class StringSeriesRecord {
  DateTime? timestamp;
  String? key;
  double value;
  DateFormat formatter;

  StringSeriesRecord(this.timestamp, this.value, this.formatter) {
    this.key = this.formatter.format(this.timestamp!);
  }

  StringSeriesRecordFromDateTimeSeriesRecord(
      DateTimeSeriesRecord dsr, DateFormat formatter) {
    this.timestamp = dsr.time;
    this.formatter = formatter;
    this.key = this.formatter.format(this.timestamp!);
    this.value = dsr.value;
  }
}

enum AggregationMethod { DAY, MONTH, YEAR, CUSTOM }
