enum RecurrentPeriod {
  EveryDay,
  EveryWeek,
  EveryMonth
}

String recurrentPeriodString(RecurrentPeriod r) {
  if (r == RecurrentPeriod.EveryDay) return "Every day";
  if (r == RecurrentPeriod.EveryWeek) return "Every week";
  if (r == RecurrentPeriod.EveryMonth) return "Every month";
  new Exception("Unexpected value");
}