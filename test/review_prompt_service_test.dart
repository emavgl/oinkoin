import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/review-prompt-service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReviewPromptService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    group('shouldShow', () {
      test('returns false when permanently shown', () async {
        final prefs = await SharedPreferences.getInstance();
        final service = ReviewPromptService(prefs);
        await service.markPermanentlyShown();

        // No matter the record count, never show again
        expect(service.shouldShow(0), false);
        expect(service.shouldShow(100), false);
        expect(service.shouldShow(1000), false);
      });

      test('returns false when recordCount is below default threshold',
          () async {
        final prefs = await SharedPreferences.getInstance();
        final service = ReviewPromptService(prefs);

        expect(service.shouldShow(0), false);
        expect(service.shouldShow(49), false);
      });

      test('returns true when recordCount reaches the default threshold',
          () async {
        final prefs = await SharedPreferences.getInstance();
        final service = ReviewPromptService(prefs);

        expect(service.shouldShow(50), true);
        expect(service.shouldShow(100), true);
      });

      test('returns false when recordCount is below a bumped threshold',
          () async {
        final prefs = await SharedPreferences.getInstance();
        final service = ReviewPromptService(prefs);

        // Simulate a dismissal at 55 records: next threshold = 55 + 10 = 65
        await service.markDismissed(55);

        expect(service.shouldShow(55), false);
        expect(service.shouldShow(64), false);
        expect(service.shouldShow(65), true);
      });

      test('threshold stacks across multiple dismissals', () async {
        final prefs = await SharedPreferences.getInstance();
        final service = ReviewPromptService(prefs);

        // 1st dismissal at 50 records → threshold = 60
        await service.markDismissed(50);
        expect(service.nextThreshold, 60);
        expect(service.shouldShow(59), false);
        expect(service.shouldShow(60), true);

        // 2nd dismissal at 80 records → threshold = 90
        await service.markDismissed(80);
        expect(service.nextThreshold, 90);
        expect(service.shouldShow(89), false);
        expect(service.shouldShow(90), true);

        // 3rd dismissal at 120 records → threshold = 130
        await service.markDismissed(120);
        expect(service.nextThreshold, 130);
        expect(service.shouldShow(129), false);
        expect(service.shouldShow(130), true);
      });
    });

    group('isPermanentlyShown', () {
      test('returns false by default', () async {
        final prefs = await SharedPreferences.getInstance();
        final service = ReviewPromptService(prefs);

        expect(service.isPermanentlyShown, false);
      });

      test('returns true after markPermanentlyShown', () async {
        final prefs = await SharedPreferences.getInstance();
        final service = ReviewPromptService(prefs);

        await service.markPermanentlyShown();
        expect(service.isPermanentlyShown, true);
      });
    });

    group('nextThreshold', () {
      test('returns defaultThreshold (50) when no value is stored', () async {
        final prefs = await SharedPreferences.getInstance();
        final service = ReviewPromptService(prefs);

        expect(service.nextThreshold, ReviewPromptService.defaultThreshold);
        expect(service.nextThreshold, 50);
      });

      test('returns the stored threshold after a dismissal', () async {
        final prefs = await SharedPreferences.getInstance();
        final service = ReviewPromptService(prefs);

        await service.markDismissed(72);
        expect(service.nextThreshold, 82); // 72 + 10
      });
    });

    group('persistence', () {
      test('state survives across service instances', () async {
        final prefs = await SharedPreferences.getInstance();
        final service1 = ReviewPromptService(prefs);

        await service1.markDismissed(60);
        await service1.markPermanentlyShown();

        // A new instance reading the same prefs should see the saved state
        final service2 = ReviewPromptService(prefs);
        expect(service2.isPermanentlyShown, true);
        expect(service2.nextThreshold, 70);
        expect(service2.shouldShow(100), false); // permanently shown trumps all
      });
    });
  });
}
