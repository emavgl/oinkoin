import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';

import 'recurrent-period.dart';

class RecurrentRecordPattern {
  // This class is used to create records based on this pattern.
  // It includes all the fields from Record + recurrent_period
  // that defines the time period of the recurrent event.
  // It does not inherit from Record because, although it share a lot of fields
  // the context is different and their logic is separated.

  String? id;
  double? value;
  String? title;
  String? description;
  Category? category;
  DateTime? dateTime;
  RecurrentPeriod? recurrentPeriod;
  DateTime? lastUpdate;

  RecurrentRecordPattern(this.value, this.title, this.category, this.dateTime,
      this.recurrentPeriod,
      {this.id, this.description, this.lastUpdate});

  RecurrentRecordPattern.fromRecord(Record record, this.recurrentPeriod,
      {this.id}) {
    this.value = record.value;
    this.title = record.title;
    this.category = record.category;
    this.dateTime = record.dateTime;
    this.description = record.description;
    this.id = id;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'title': title,
      'value': value,
      'datetime': dateTime!.millisecondsSinceEpoch,
      'category_name': category!.name,
      'category_type': category!.categoryType!.index,
      'description': description,
      'recurrent_period': recurrentPeriod!.index,
    };
    if (this.id != null) {
      map['id'] = this.id;
    }
    if (this.lastUpdate != null) {
      map['last_update'] = this.lastUpdate!.millisecondsSinceEpoch;
    } else {
      map['last_update'] = null;
    }
    return map;
  }

  static RecurrentRecordPattern fromMap(Map<String, dynamic> map) {
    return RecurrentRecordPattern(
        map['value'],
        map['title'],
        map['category'],
        new DateTime.fromMillisecondsSinceEpoch(map['datetime']),
        RecurrentPeriod.values[map['recurrent_period']],
        id: map['id'],
        description: map['description'],
        lastUpdate: map['last_update'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['last_update'])
            : null);
  }
}
