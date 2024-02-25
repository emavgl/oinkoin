import 'package:piggybank/models/model.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';

class Record extends Model {
  /// Represents the Record object.
  /// A Record has:
  /// - value: monetary value associated to the movement (can be positive, or negative)
  /// - title: a headline for the record
  /// - category: a Category object assigned to the movement, describing the type of movement (income, expense)
  /// - dateTime: a date representing when the movement was performed

  int? id;
  double? value;
  String? title;
  String? description;
  Category? category;
  DateTime? dateTime;
  String? recurrencePatternId;
  int aggregatedValues =
      1; // internal variables - used to identified an aggregated records (statistics)

  Record(this.value, this.title, this.category, this.dateTime,
      {this.id, this.description, this.recurrencePatternId});

  Record.fromRecurrencePattern(
      RecurrentRecordPattern recordPattern, DateTime dateTime) {
    this.value = recordPattern.value;
    this.title = recordPattern.title;
    this.category = recordPattern.category;
    this.dateTime = dateTime;
    this.recurrencePatternId = recordPattern.id;
    this.description = recordPattern.description;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'title': title,
      'value': value,
      'datetime': dateTime!.millisecondsSinceEpoch,
      'category_name': category!.name,
      'category_type': category!.categoryType!.index,
      'description': description
    };
    if (this.id != null) {
      map['id'] = this.id;
    }
    if (this.recurrencePatternId != null) {
      map['recurrence_id'] = this.recurrencePatternId;
    }
    return map;
  }

  static Record fromMap(Map<String, dynamic> map) {
    return Record(map['value'], map['title'], map['category'],
        new DateTime.fromMillisecondsSinceEpoch(map['datetime']),
        id: map['id'],
        description: map['description'],
        recurrencePatternId: map['recurrence_id']);
  }

  get date {
    return dateTime!.year.toString() +
        dateTime!.month.toString() +
        dateTime!.day.toString();
  }
}
