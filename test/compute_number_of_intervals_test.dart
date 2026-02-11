import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

void main() {
  group('computeNumberOfIntervals', () {
    test('DAY aggregation: counts all days in range', () {
      final from = DateTime(2026, 2, 1);
      final to = DateTime(2026, 2, 7);
      // Assuming today is Feb 7 or later
      expect(computeNumberOfIntervals(from, to, AggregationMethod.DAY), 7);
    });

    test('WEEK aggregation: user example Feb 7', () {
      final now = DateTime(2026, 2, 7);
      final from = DateTime(2026, 2, 1);
      final to = DateTime(2026, 2, 28);
      // "Today is 7 February. I should count just the first week (1-7), and not the week in the futures."
      expect(computeNumberOfIntervals(from, to, AggregationMethod.WEEK, now: now), 1);
    });

    test('WEEK aggregation: user example Feb 8', () {
      final now = DateTime(2026, 2, 8);
      final from = DateTime(2026, 2, 1);
      final to = DateTime(2026, 2, 28);
      // "Today is 8. I should count both the first week 1-7 and 8-14, cause 8 is in the second week."
      expect(computeNumberOfIntervals(from, to, AggregationMethod.WEEK, now: now), 2);
    });

    test('Combined test: expenses in week 2, 0 in week 1', () {
      final now = DateTime(2026, 2, 8);
      final from = DateTime(2026, 2, 1);
      final to = DateTime(2026, 2, 28);
      // Even if week 1 has 0 expenses, denominator should be 2.
      expect(computeNumberOfIntervals(from, to, AggregationMethod.WEEK, now: now), 2);
    });

    test('Today is in the future relative to "to" date', () {
      final now = DateTime(2026, 3, 1); // Future
      final from = DateTime(2026, 2, 1);
      final to = DateTime(2026, 2, 28);
      // Feb 2026 has exactly 28 days -> 4 weekly intervals (1-7, 8-14, 15-21, 22-28).
      expect(computeNumberOfIntervals(from, to, AggregationMethod.WEEK, now: now), 4);
    });

    test('MONTH aggregation: crossing years', () {
      final now = DateTime(2026, 2, 10);
      final from = DateTime(2025, 12, 15);
      final to = DateTime(2026, 12, 31);
      // intervals: Dec 2025 (1), Jan 2026 (2), Feb 2026 (3)
      expect(computeNumberOfIntervals(from, to, AggregationMethod.MONTH, now: now), 3);
    });

    test('YEAR aggregation: multiple years', () {
      final now = DateTime(2026, 5, 5);
      final from = DateTime(2024, 1, 1);
      final to = DateTime(2030, 1, 1);
      // intervals: 2024, 2025, 2026
      expect(computeNumberOfIntervals(from, to, AggregationMethod.YEAR, now: now), 3);
    });

    test('DAY aggregation: single day range', () {
      final now = DateTime(2026, 2, 7, 12);
      final from = DateTime(2026, 2, 7);
      final to = DateTime(2026, 2, 7);
      expect(computeNumberOfIntervals(from, to, AggregationMethod.DAY, now: now), 1);
    });

    test('DAY aggregation: future range should return 0', () {
      final now = DateTime(2026, 2, 1);
      final from = DateTime(2026, 2, 7);
      final to = DateTime(2026, 2, 10);
      expect(computeNumberOfIntervals(from, to, AggregationMethod.DAY, now: now), 0);
    });
  });

  group('computeNumberOfIntervals with fixed logic (concept test)', () {
    // I will slightly modify computeNumberOfIntervals to accept 'now' for testing if needed,
    // but for now let's just test with a date far in the past so 'now' doesn't cap it.

    test('WEEK aggregation: counts weeks correctly (1-7, 8-14, etc.)', () {
      final from = DateTime(2025, 1, 1);
      final to = DateTime(2025, 1, 31);
      // Jan has 5 intervals: 1-7, 8-14, 15-21, 22-28, 29-31
      expect(computeNumberOfIntervals(from, to, AggregationMethod.WEEK), 5);
    });

    test('MONTH aggregation: counts months correctly', () {
      final from = DateTime(2025, 1, 1);
      final to = DateTime(2025, 3, 31);
      expect(computeNumberOfIntervals(from, to, AggregationMethod.MONTH), 3);
    });

    test('YEAR aggregation: counts years correctly', () {
      final from = DateTime(2024, 1, 1);
      final to = DateTime(2025, 12, 31);
      expect(computeNumberOfIntervals(from, to, AggregationMethod.YEAR), 2);
    });
  });
}
