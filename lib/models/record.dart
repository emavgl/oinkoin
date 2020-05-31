import 'package:flutter/cupertino.dart';
import 'package:piggybank/models/model.dart';
import 'package:piggybank/models/category.dart';

class Record extends Model {

  /// Represents the Record object.
  /// A Record has:
  /// - value: monetary value associated to the movement (can be positive, or negative)
  /// - description: a short description of the movement
  /// - category: a Category object assigned to the movement, describing the type of movement (income, expense)
  /// - dateTime: a date representing when the movement was performed

  int id;
  double value;
  String description;
  Category category;
  DateTime dateTime;

  Record(this.value, this.description, this.category, this.dateTime, {this.id});

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'description': description,
      'value': value,
      'datetime': dateTime.millisecondsSinceEpoch,
      'category_id': category.id
    };

    if (this.id != null) { map['id'] = this.id; }
    return map;
  }

  static Record fromMap(Map<String, dynamic> map) {
    return Record(
      map['value'],
      map['description'],
      map['category'],
      new DateTime.fromMillisecondsSinceEpoch(map['datetime']),
      id: map['id'],
    );
  }

  get date {
    return dateTime.year.toString() + dateTime.month.toString() + dateTime.day.toString();
  }

}