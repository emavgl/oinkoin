import 'dart:convert';

import 'package:piggybank/models/budget-type.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/model.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/services/service-config.dart';

class Budget extends Model {
  int? id;
  String name;
  double targetAmount;
  BudgetType budgetType;
  DateTime startDate;
  DateTime? endDate;
  RecurrentPeriod? recurrentPeriod;
  int? customIntervalValue;
  CustomIntervalUnit? customIntervalUnit;
  List<String> categoryNames;
  List<String> tags;
  List<int> walletIds;
  bool categoryTagOrLogic;
  bool tagOrLogic;
  bool isArchived;
  int? profileId;
  String timeZoneName;

  Budget({
    this.id,
    required this.name,
    required this.targetAmount,
    required this.budgetType,
    required this.startDate,
    this.endDate,
    this.recurrentPeriod,
    this.customIntervalValue,
    this.customIntervalUnit,
    List<String>? categoryNames,
    List<String>? tags,
    List<int>? walletIds,
    this.categoryTagOrLogic = true,
    this.tagOrLogic = false,
    this.isArchived = false,
    this.profileId,
    String? timeZoneName,
  })  : categoryNames = categoryNames ?? [],
        tags = tags ?? [],
        walletIds = walletIds ?? [],
        timeZoneName = timeZoneName ?? ServiceConfig.localTimezone;

  bool get isRecurring => recurrentPeriod != null;

  CategoryType get recordCategoryType => budgetType == BudgetType.expense
      ? CategoryType.expense
      : CategoryType.income;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'target_amount': targetAmount,
      'budget_type': budgetType.index,
      'start_date': startDate.toUtc().millisecondsSinceEpoch,
      'end_date': endDate?.toUtc().millisecondsSinceEpoch,
      'recurrent_period': recurrentPeriod?.index,
      'custom_interval_value': customIntervalValue,
      'custom_interval_unit': customIntervalUnit?.index,
      'category_names': jsonEncode(categoryNames),
      'tags': jsonEncode(tags),
      'wallet_ids': jsonEncode(walletIds),
      'category_tag_or_logic': categoryTagOrLogic ? 1 : 0,
      'tag_or_logic': tagOrLogic ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'profile_id': profileId,
      'timezone': timeZoneName,
    };
  }

  static Budget fromMap(Map<String, dynamic> map) {
    List<String> decodeStringList(Object? value) {
      if (value == null) return [];
      if (value is String) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) return decoded.whereType<String>().toList();
        } catch (_) {
          // Fall back to the legacy comma-separated representation.
          return value
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();
        }
      }
      if (value is List) return value.whereType<String>().toList();
      return [];
    }

    List<int> decodeIntList(Object? value) {
      if (value == null) return [];
      Object? decoded = value;
      if (value is String) {
        try {
          decoded = jsonDecode(value);
        } catch (_) {
          decoded = null;
        }
      }
      if (decoded is List) {
        return decoded.whereType<num>().map((item) => item.toInt()).toList();
      }
      return [];
    }

    final startMillis = map['start_date'] as int;
    final endMillis = map['end_date'] as int?;
    final recurrentIndex = map['recurrent_period'] as int?;
    final customUnitIndex = map['custom_interval_unit'] as int?;

    return Budget(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      targetAmount: (map['target_amount'] as num?)?.toDouble() ?? 0,
      budgetType: BudgetType.values[map['budget_type'] as int? ?? 0],
      startDate: DateTime.fromMillisecondsSinceEpoch(startMillis, isUtc: true)
          .toLocal(),
      endDate: endMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endMillis, isUtc: true)
              .toLocal(),
      recurrentPeriod: recurrentIndex == null
          ? null
          : RecurrentPeriod.values[recurrentIndex],
      customIntervalValue: map['custom_interval_value'] as int?,
      customIntervalUnit: customUnitIndex == null
          ? null
          : CustomIntervalUnit.values[customUnitIndex],
      categoryNames: decodeStringList(map['category_names']),
      tags: decodeStringList(map['tags']),
      walletIds: decodeIntList(map['wallet_ids']),
      categoryTagOrLogic: (map['category_tag_or_logic'] as int? ?? 1) == 1,
      tagOrLogic: (map['tag_or_logic'] as int? ?? 0) == 1,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      profileId: map['profile_id'] as int?,
      timeZoneName: map['timezone'] as String?,
    );
  }

  /// Returns the active cycle for [referenceDate]. Dates are local calendar
  /// dates because budgets describe user-facing calendar periods.
  BudgetCycle currentCycle([DateTime? referenceDate]) {
    final reference = referenceDate ?? DateTime.now();
    if (!isRecurring) {
      final cycleEnd = endDate ?? startDate;
      return BudgetCycle(startDate, cycleEnd);
    }

    var cycleStart = DateTime(startDate.year, startDate.month, startDate.day);
    final target = DateTime(reference.year, reference.month, reference.day);
    var safety = 0;
    while (true) {
      final next = _nextDate(cycleStart);
      if (next.isAfter(target) || safety++ > 10000) {
        return BudgetCycle(cycleStart, next.subtract(const Duration(days: 1)));
      }
      cycleStart = next;
    }
  }

  DateTime _nextDate(DateTime date) {
    switch (recurrentPeriod) {
      case RecurrentPeriod.EveryDay:
        return DateTime(date.year, date.month, date.day + 1);
      case RecurrentPeriod.EveryWeek:
        return DateTime(date.year, date.month, date.day + 7);
      case RecurrentPeriod.EveryTwoWeeks:
        return DateTime(date.year, date.month, date.day + 14);
      case RecurrentPeriod.EveryFourWeeks:
        return DateTime(date.year, date.month, date.day + 28);
      case RecurrentPeriod.EveryMonth:
        return _addMonths(date, 1, preferredDay: startDate.day);
      case RecurrentPeriod.EveryThreeMonths:
        return _addMonths(date, 3, preferredDay: startDate.day);
      case RecurrentPeriod.EveryFourMonths:
        return _addMonths(date, 4, preferredDay: startDate.day);
      case RecurrentPeriod.EveryYear:
        return _addMonths(date, 12, preferredDay: startDate.day);
      case RecurrentPeriod.Custom:
        final value = customIntervalValue ?? 1;
        switch (customIntervalUnit) {
          case CustomIntervalUnit.day:
            return DateTime(date.year, date.month, date.day + value);
          case CustomIntervalUnit.week:
            return DateTime(date.year, date.month, date.day + value * 7);
          case CustomIntervalUnit.month:
            return _addMonths(date, value, preferredDay: startDate.day);
          case CustomIntervalUnit.year:
            return _addMonths(date, value * 12, preferredDay: startDate.day);
          case null:
            return _addMonths(date, 1, preferredDay: startDate.day);
        }
      case null:
        return date;
    }
  }

  DateTime _addMonths(DateTime date, int months, {int? preferredDay}) {
    final monthIndex = date.month - 1 + months;
    final year = date.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final day = (preferredDay ?? date.day).clamp(1, DateTime(year, month + 1, 0).day);
    return DateTime(year, month, day);
  }
}

class BudgetCycle {
  final DateTime start;
  final DateTime end;

  const BudgetCycle(this.start, this.end);
}
