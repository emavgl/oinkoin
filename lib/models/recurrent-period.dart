import 'package:i18n_extension/default.i18n.dart';

enum RecurrentPeriod {
  EveryDay,
  EveryWeek,
  EveryMonth,
  EveryTwoWeeks,
  EveryThreeMonths,
  EveryFourMonths,
  EveryYear,
}

String recurrentPeriodString(RecurrentPeriod? r) {
  if (r == RecurrentPeriod.EveryDay) return "Every day".i18n;
  if (r == RecurrentPeriod.EveryWeek) return "Every week".i18n;
  if (r == RecurrentPeriod.EveryMonth) return "Every month".i18n;
  if (r == RecurrentPeriod.EveryTwoWeeks) return "Every two weeks".i18n;
  if (r == RecurrentPeriod.EveryThreeMonths) return "Every three months".i18n;
  if (r == RecurrentPeriod.EveryFourMonths) return "Every four months".i18n;
  if (r == RecurrentPeriod.EveryYear) return "Every year".i18n;
  new Exception("Unexpected value");
  return "";
}
