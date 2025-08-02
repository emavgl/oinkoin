import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/model.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:timezone/timezone.dart' as tz;

import '../helpers/datetime-utility-functions.dart';

class Record extends Model {
  int? id;
  double? value;
  String? title;
  String? description;
  Category? category;

  DateTime utcDateTime;
  String? timeZoneName;

  String? recurrencePatternId;
  int aggregatedValues =
      1; // internal variables - used to identified an aggregated records (statistics)

  Record(
    this.value,
    this.title,
    this.category,
    this.utcDateTime, {
    this.id,
    this.description,
    this.recurrencePatternId,
    this.timeZoneName,
  }) {
    if (timeZoneName == null) {
      timeZoneName = ServiceConfig.localTimezone;
    }
  }

  Record.fromRecurrencePattern(
    RecurrentRecordPattern recordPattern,
    DateTime dateTime,
  )   : value = recordPattern.value,
        title = recordPattern.title,
        category = recordPattern.category,
        utcDateTime = dateTime,
        recurrencePatternId = recordPattern.id,
        description = recordPattern.description,
        timeZoneName = recordPattern.timeZoneName;

  /// Deserialize from database
  static Record fromMap(Map<String, dynamic> map) {
    final int? utcMillis = map['datetime'];
    final utcDateTime =
        DateTime.fromMillisecondsSinceEpoch(utcMillis!, isUtc: true);

    String? timezone = map['timezone'];
    if (timezone == null) {
      timezone = ServiceConfig.localTimezone;
    }

    return Record(
      map['value'],
      map['title'],
      map['category'],
      utcDateTime,
      timeZoneName: timezone,
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
      'datetime': utcDateTime
          .millisecondsSinceEpoch, // this will be same as the original
      'timezone': timeZoneName,
      'category_name': category?.name,
      'category_type': category?.categoryType?.index,
      'description': description,
      'recurrence_id': recurrencePatternId,
    };
  }

  tz.TZDateTime get localDateTime {
    return createTzDateTime(utcDateTime, timeZoneName!);
  }

  tz.TZDateTime get dateTime {
    return createTzDateTime(utcDateTime, timeZoneName!);
  }

  /// YYYYMMDD string for grouping/sorting
  String get date {
    return localDateTime.year.toString().padLeft(4, '0') +
        localDateTime.month.toString().padLeft(2, '0') +
        localDateTime.day.toString().padLeft(2, '0');
  }
}
