import 'package:piggybank/i18n.dart';

enum RecurrentPeriod {
  EveryDay,
  EveryWeek,
  EveryMonth,
  EveryTwoWeeks,
  EveryThreeMonths,
  EveryFourMonths,
  EveryYear,
  EveryFourWeeks,
  // Appended at the end: the enum index is persisted in the database, so
  // existing values must keep their index and new ones must be added last.
  Custom,
}

/// Unit for a [RecurrentPeriod.Custom] interval (e.g. "every 6 months").
/// Persisted as an index in the database: append-only, like [RecurrentPeriod].
enum CustomIntervalUnit {
  day,
  week,
  month,
  year,
}

String recurrentPeriodString(RecurrentPeriod? r) {
  if (r == RecurrentPeriod.EveryDay) return "Every day".i18n;
  if (r == RecurrentPeriod.EveryWeek) return "Every week".i18n;
  if (r == RecurrentPeriod.EveryMonth) return "Every month".i18n;
  if (r == RecurrentPeriod.EveryTwoWeeks) return "Every two weeks".i18n;
  if (r == RecurrentPeriod.EveryFourWeeks) return "Every four weeks".i18n;
  if (r == RecurrentPeriod.EveryThreeMonths) return "Every three months".i18n;
  if (r == RecurrentPeriod.EveryFourMonths) return "Every four months".i18n;
  if (r == RecurrentPeriod.EveryYear) return "Every year".i18n;
  if (r == RecurrentPeriod.Custom) return "Custom".i18n;
  new Exception("Unexpected value");
  return "";
}

String customIntervalUnitString(CustomIntervalUnit unit) {
  switch (unit) {
    case CustomIntervalUnit.day:
      return "Days".i18n;
    case CustomIntervalUnit.week:
      return "Weeks".i18n;
    case CustomIntervalUnit.month:
      return "Months".i18n;
    case CustomIntervalUnit.year:
      return "Years".i18n;
  }
}

/// Label for a fully-specified custom interval, e.g. "Every 6 Months".
/// Falls back to the generic "Custom" label when the interval is incomplete.
String customIntervalString(int? value, CustomIntervalUnit? unit) {
  if (value == null || unit == null) return "Custom".i18n;
  return "Every %d %s".i18n.fill([value, customIntervalUnitString(unit)]);
}

/// Display label for a recurrent pattern's period, expanding
/// [RecurrentPeriod.Custom] into its concrete interval instead of the
/// generic "Custom" label.
String recurrentPeriodDisplayString(RecurrentPeriod? period,
    {int? customIntervalValue, CustomIntervalUnit? customIntervalUnit}) {
  if (period == RecurrentPeriod.Custom) {
    return customIntervalString(customIntervalValue, customIntervalUnit);
  }
  return recurrentPeriodString(period);
}
