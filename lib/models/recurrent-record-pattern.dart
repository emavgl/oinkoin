import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import '../helpers/datetime-utility-functions.dart';
import 'recurrent-period.dart';

class RecurrentRecordPattern {
  String? id;
  double? value;
  String? title;
  String? description;
  Category? category;
  DateTime? _dateTime; // Local time (UTC + offset)
  int? timezoneOffset;
  RecurrentPeriod? recurrentPeriod;
  DateTime? lastUpdate; // Last update in local time (UTC + offset)

  RecurrentRecordPattern(
      this.value,
      this.title,
      this.category,
      this._dateTime,
      this.recurrentPeriod, {
        this.id,
        this.description,
        this.lastUpdate,
        this.timezoneOffset
      });

  RecurrentRecordPattern.fromRecord(
      Record record,
      this.recurrentPeriod, {
        this.id,
      }) {
    value = record.value;
    title = record.title;
    category = record.category;
    _dateTime = record.dateTime;
    description = record.description;
    timezoneOffset = record.timezoneOffset;
  }

  /// Serialize to database
  Map<String, dynamic> toMap() {
    if (timezoneOffset == null) {
      timezoneOffset = _dateTime!.timeZoneOffset.inMinutes;
    }
    final map = {
      'title': title,
      'value': value,
      'datetime': _dateTime?.millisecondsSinceEpoch,
      'timezone_offset': timezoneOffset,
      'date_iso_str': toIso8601(_dateTime!),
      'category_name': category?.name,
      'category_type': category?.categoryType?.index,
      'description': description,
      'recurrent_period': recurrentPeriod?.index,
      'last_update': lastUpdate?.millisecondsSinceEpoch,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  /// Deserialize from database
  static RecurrentRecordPattern fromMap(Map<String, dynamic> map) {
    final int? utcMillis = map['datetime'];
    final int? offsetMinutes = map['timezone_offset'];
    DateTime? localDateTime;

    if (utcMillis != null) {
      final utc = DateTime.fromMillisecondsSinceEpoch(utcMillis, isUtc: true);
      localDateTime = offsetMinutes != null
          ? utc.add(Duration(minutes: offsetMinutes))
          : utc.toLocal(); // fallback
    }

    DateTime? lastUpdateLocal;
    final int? lastUpdateUtc = map['last_update'];
    final int? lastUpdateOffset = map['timezone_offset'];

    DateTime currentTimeZoneLocalTime = DateTime(
        localDateTime!.year,
        localDateTime.month,
        localDateTime.day,
        localDateTime.hour,
        localDateTime.minute
    );

    if (lastUpdateUtc != null) {
      final utc = DateTime.fromMillisecondsSinceEpoch(lastUpdateUtc, isUtc: true);
      lastUpdateLocal = lastUpdateOffset != null
          ? utc.add(Duration(minutes: lastUpdateOffset))
          : utc.toLocal(); // fallback
      lastUpdateLocal = DateTime(
          lastUpdateLocal.year,
          lastUpdateLocal.month,
          lastUpdateLocal.day,
          lastUpdateLocal.hour,
          lastUpdateLocal.minute
      );
    }

    return RecurrentRecordPattern(
      map['value'],
      map['title'],
      map['category'],
      currentTimeZoneLocalTime,
      timezoneOffset: offsetMinutes,
      RecurrentPeriod.values[map['recurrent_period']],
      id: map['id'],
      description: map['description'],
      lastUpdate: lastUpdateLocal,
    );
  }

  // setter for datetime, change datetime and timezoneOffset
  set dateTime(DateTime? value) {
    _dateTime = value;
    timezoneOffset = _dateTime!.timeZoneOffset.inMinutes;
  }

  DateTime? get dateTime => _dateTime;

}
