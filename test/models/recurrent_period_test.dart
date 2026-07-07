import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/recurrent-period.dart';

void main() {
  group('RecurrentPeriod enum stability', () {
    // The enum index is persisted as a raw INTEGER in the database
    // (recurrent_period column), so existing values must never change index
    // and new values must always be appended at the end.
    test('existing values keep their historical index', () {
      expect(RecurrentPeriod.EveryDay.index, 0);
      expect(RecurrentPeriod.EveryWeek.index, 1);
      expect(RecurrentPeriod.EveryMonth.index, 2);
      expect(RecurrentPeriod.EveryTwoWeeks.index, 3);
      expect(RecurrentPeriod.EveryThreeMonths.index, 4);
      expect(RecurrentPeriod.EveryFourMonths.index, 5);
      expect(RecurrentPeriod.EveryYear.index, 6);
      expect(RecurrentPeriod.EveryFourWeeks.index, 7);
    });

    test('Custom is appended at the end of the enum', () {
      expect(RecurrentPeriod.Custom.index, 8);
      expect(RecurrentPeriod.values.last, RecurrentPeriod.Custom);
    });
  });

  group('CustomIntervalUnit enum stability', () {
    test('units keep their historical index', () {
      expect(CustomIntervalUnit.day.index, 0);
      expect(CustomIntervalUnit.week.index, 1);
      expect(CustomIntervalUnit.month.index, 2);
      expect(CustomIntervalUnit.year.index, 3);
    });
  });

  group('recurrentPeriodString', () {
    test('returns a non-generic label for every fixed period', () {
      for (final period in RecurrentPeriod.values) {
        if (period == RecurrentPeriod.Custom) continue;
        expect(recurrentPeriodString(period), isNotEmpty);
      }
    });

    test('returns the generic "Custom" label for RecurrentPeriod.Custom', () {
      expect(recurrentPeriodString(RecurrentPeriod.Custom), "Custom");
    });
  });

  group('customIntervalUnitString', () {
    test('returns a distinct label for each unit', () {
      final labels = CustomIntervalUnit.values
          .map((u) => customIntervalUnitString(u))
          .toSet();
      expect(labels.length, CustomIntervalUnit.values.length);
    });
  });

  group('customIntervalString', () {
    test('falls back to "Custom" when value is null', () {
      expect(customIntervalString(null, CustomIntervalUnit.month), "Custom");
    });

    test('falls back to "Custom" when unit is null', () {
      expect(customIntervalString(6, null), "Custom");
    });

    test('falls back to "Custom" when both are null', () {
      expect(customIntervalString(null, null), "Custom");
    });

    test('builds a readable label for a fully specified interval', () {
      final label = customIntervalString(6, CustomIntervalUnit.month);
      expect(label, contains("6"));
      expect(
          label, contains(customIntervalUnitString(CustomIntervalUnit.month)));
    });

    test('supports every unit', () {
      expect(customIntervalString(2, CustomIntervalUnit.day), contains("2"));
      expect(customIntervalString(3, CustomIntervalUnit.week), contains("3"));
      expect(customIntervalString(6, CustomIntervalUnit.month), contains("6"));
      expect(customIntervalString(1, CustomIntervalUnit.year), contains("1"));
    });
  });

  group('recurrentPeriodDisplayString', () {
    test('delegates to recurrentPeriodString for fixed periods', () {
      expect(recurrentPeriodDisplayString(RecurrentPeriod.EveryMonth),
          recurrentPeriodString(RecurrentPeriod.EveryMonth));
    });

    test('expands RecurrentPeriod.Custom into the concrete interval', () {
      final result = recurrentPeriodDisplayString(RecurrentPeriod.Custom,
          customIntervalValue: 6, customIntervalUnit: CustomIntervalUnit.month);
      expect(result, customIntervalString(6, CustomIntervalUnit.month));
      expect(result, isNot("Custom"));
    });

    test('falls back to generic "Custom" when interval fields are missing', () {
      final result = recurrentPeriodDisplayString(RecurrentPeriod.Custom);
      expect(result, "Custom");
    });
  });
}
