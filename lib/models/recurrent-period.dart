enum RecurrentPeriod { EveryDay, EveryWeek, EveryMonth, EveryTwoWeeks }

String recurrentPeriodString(RecurrentPeriod? r) {
  if (r == RecurrentPeriod.EveryDay) return "Every day";
  if (r == RecurrentPeriod.EveryWeek) return "Every week";
  if (r == RecurrentPeriod.EveryMonth) return "Every month";
  if (r == RecurrentPeriod.EveryTwoWeeks) return "Every two weeks";
  new Exception("Unexpected value");
  return "";
}
