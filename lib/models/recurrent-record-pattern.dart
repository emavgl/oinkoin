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
  String? timeZoneName;
  RecurrentPeriod? recurrentPeriod;
  DateTime? utcLastUpdate;

  RecurrentRecordPattern(this.value, this.title, this.category,
      this.utcDateTime, this.recurrentPeriod,
      {this.id, this.description, this.utcLastUpdate, this.timeZoneName}) {
    if (timeZoneName == null) {
      timeZoneName = ServiceConfig.localTimezone;
    }
  }

  RecurrentRecordPattern.fromRecord(
    Record record,
    this.recurrentPeriod, {
    this.id,
  })  : value = record.value,
        title = record.title,
        category = record.category,
        utcDateTime = record.utcDateTime,
        description = record.description,
        timeZoneName = record.timeZoneName;

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

    return RecurrentRecordPattern(
      map['value'],
      map['title'],
      map['category'],
      utcDateTime,
      timeZoneName: timezone,
      RecurrentPeriod.values[map['recurrent_period']],
      id: map['id'],
      description: map['description'],
      utcLastUpdate: utcLastUpdate,
    );
  }

  tz.TZDateTime get localDateTime {
    return createTzDateTime(utcDateTime, timeZoneName!);
  }
}
