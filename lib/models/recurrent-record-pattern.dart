import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:timezone/timezone.dart' as tz;

import '../helpers/datetime-utility-functions.dart';
import 'recurrent-period.dart';

class RecurrentRecordPattern {
  String? id;
  double? value;
  String? title;
  String? description;
  Category? category;
  DateTime utcDateTime;
  DateTime? utcEndDate;
  String? timeZoneName;
  RecurrentPeriod? recurrentPeriod;
  DateTime? utcLastUpdate;
  Set<String> tags = {};

  RecurrentRecordPattern(this.value, this.title, this.category,
      this.utcDateTime, this.recurrentPeriod,
      {this.id,
      this.description,
      this.utcEndDate,
      this.utcLastUpdate,
      this.timeZoneName,
      Set<String>? tags}) {
    if (timeZoneName == null) {
      timeZoneName = ServiceConfig.localTimezone;
    }
    if (tags != null) {
      this.tags = tags;
    }
  }

  RecurrentRecordPattern.fromRecord(
    Record record,
    this.recurrentPeriod, {
    this.id,
    this.utcEndDate,
  })  : value = record.value,
        title = record.title,
        category = record.category,
        utcDateTime = record.utcDateTime,
        description = record.description,
        timeZoneName = record.timeZoneName,
        tags = record.tags;

  /// Serialize to database
  Map<String, dynamic> toMap() {
    final map = {
      'title': title,
      'value': value,
      'datetime': utcDateTime.millisecondsSinceEpoch,
      'timezone': timeZoneName,
      'category_name': category?.name,
      'category_type': category?.categoryType?.index,
      'description': description,
      'recurrent_period': recurrentPeriod?.index,
      'last_update': utcLastUpdate?.millisecondsSinceEpoch,
      'tags': tags.where((t) => t.trim().isNotEmpty).join(','),
      'end_date': utcEndDate?.millisecondsSinceEpoch,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  /// Deserialize from database
  static RecurrentRecordPattern fromMap(Map<String, dynamic> map) {
    final int? utcMillis = map['datetime'];
    final utcDateTime =
        DateTime.fromMillisecondsSinceEpoch(utcMillis!, isUtc: true);

    String? timezone = map['timezone'];
    if (timezone == null) {
      timezone = ServiceConfig.localTimezone;
    }

    DateTime? utcLastUpdate;
    final int? lastUpdateMillis = map['last_update'];
    if (lastUpdateMillis != null) {
      utcLastUpdate =
          DateTime.fromMillisecondsSinceEpoch(lastUpdateMillis, isUtc: true);
    }

    DateTime? utcEndDate;
    final int? endDateMillis = map['end_date'];
    if (endDateMillis != null) {
      utcEndDate =
          DateTime.fromMillisecondsSinceEpoch(endDateMillis, isUtc: true);
    }

    Set<String> tags = map['tags'] != null
      ? (map['tags'] as String)
        .split(',')
        .where((t) => t.trim().isNotEmpty)
        .toSet()
      : {};

    return RecurrentRecordPattern(
      map['value'],
      map['title'],
      map['category'],
      utcDateTime,
      RecurrentPeriod.values[map['recurrent_period']],
      id: map['id'],
      description: map['description'],
      utcEndDate: utcEndDate,
      utcLastUpdate: utcLastUpdate,
      timeZoneName: timezone,
      tags: tags,
    );
  }

  tz.TZDateTime get localDateTime {
    return createTzDateTime(utcDateTime, timeZoneName!);
  }

  tz.TZDateTime? get localEndDate {
    if (utcEndDate == null) return null;
    return createTzDateTime(utcEndDate!, timeZoneName!);
  }
}
