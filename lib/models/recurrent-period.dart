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
  if (r == RecurrentPeriod.EveryDay) return "Every day";
  if (r == RecurrentPeriod.EveryWeek) return "Every week";
  if (r == RecurrentPeriod.EveryMonth) return "Every month";
  if (r == RecurrentPeriod.EveryTwoWeeks) return "Every two weeks";
  if (r == RecurrentPeriod.EveryThreeMonths) return "Every three months";
  if (r == RecurrentPeriod.EveryFourMonths) return "Every four months";
  if (r == RecurrentPeriod.EveryYear) return "Every year";
  new Exception("Unexpected value");
  return "";
}
