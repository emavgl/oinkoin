import 'package:piggybank/models/model.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';

import '../helpers/datetime-utility-functions.dart';

class Record extends Model {
  int? id;
  double? value;
  String? title;
  String? description;
  Category? category;
  DateTime? _dateTime;             // Local time (UTC + offset) -> translated to current time-zone
  int? timezoneOffset;
  String? recurrencePatternId;
  int aggregatedValues =
      1; // internal variables - used to identified an aggregated records (statistics)

  Record(
      this.value,
      this.title,
      this.category,
      this._dateTime, {
        this.id,
        this.description,
        this.recurrencePatternId,
        int? timezoneOffset,
      });

  Record.fromRecurrencePattern(
      RecurrentRecordPattern recordPattern,
      DateTime dateTime,
      ) {
    value = recordPattern.value;
    title = recordPattern.title;
    category = recordPattern.category;
    this._dateTime = dateTime;
    recurrencePatternId = recordPattern.id;
    description = recordPattern.description;
    timezoneOffset = recordPattern.timezoneOffset;
  }

  /// Deserialize from database
  static Record fromMap(Map<String, dynamic> map) {
    DateTime? localDateTime;

    final int? utcMillis = map['datetime'];
    final int? offsetMinutes = map['timezone_offset'];

    if (utcMillis != null) {
      final utc = DateTime.fromMillisecondsSinceEpoch(utcMillis, isUtc: true);
      localDateTime = offsetMinutes != null
          ? utc.add(Duration(minutes: offsetMinutes))
          : utc.toLocal(); // fallback if no offset
    }

    // localDateTime is in the time of the actual insertion timezone
    // we would like to map 1:1 and fake it that the record happened
    // at the exact same time, but in the current timezone
    // For example, insertion at 10:00 UTC, but I am at UTC+2
    // record will appear at 10:00 UTC+2
    DateTime currentTimeZoneLocalTime = DateTime(
        localDateTime!.year,
        localDateTime.month,
        localDateTime.day,
        localDateTime.hour,
        localDateTime.minute
    );

    return Record(
      map['value'],
      map['title'],
      map['category'],
      currentTimeZoneLocalTime,
      timezoneOffset: offsetMinutes,
      id: map['id'],
      description: map['description'],
      recurrencePatternId: map['recurrence_id'],
    );
  }

  /// Serialize to database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'value': value,
      'datetime': _dateTime?.millisecondsSinceEpoch, // this will be same as the original
      'date_iso_str': toIso8601(_dateTime!), // this will be same as the original
      'timezone_offset': timezoneOffset, // to keep the original timezone at insertion time
      'category_name': category?.name,
      'category_type': category?.categoryType?.index,
      'description': description,
      'recurrence_id': recurrencePatternId,
    };
  }

  // setter for datetime, change datetime and timezoneOffset
  set dateTime(DateTime? value) {
    _dateTime = value;
    timezoneOffset = _dateTime!.timeZoneOffset.inMinutes;
  }

  DateTime? get dateTime => _dateTime;

  /// YYYYMMDD string for grouping/sorting
  String get date {
    final d = _dateTime;
    if (d == null) return '';
    return d.year.toString().padLeft(4, '0') +
        d.month.toString().padLeft(2, '0') +
        d.day.toString().padLeft(2, '0');
  }
}

