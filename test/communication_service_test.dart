import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/communication-service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String sampleManifest = '''
{
  "communications": [
    {
      "id": "2026-08-pro-in-app-purchase",
      "date": "2026-08-23",
      "titleKey": "Pro features are now available in the Android Oinkoin free app",
      "dialog": true
    },
    {
      "id": "2025-12-old-news",
      "date": "2025-12-30",
      "titleKey": "Old news"
    },
    {
      "id": "2026-09-targeted",
      "date": "2026-09-01",
      "titleKey": "Targeted",
      "dialog": true,
      "dialogAudience": ["free", "alpha", "debug"]
    }
  ]
}
''';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CommunicationService.parseManifest', () {
    test('parses communications from manifest JSON', () {
      final comms = CommunicationService.parseManifest(sampleManifest);
      expect(comms, hasLength(3));
      final proComm = comms.firstWhere(
        (c) => c.id == '2026-08-pro-in-app-purchase',
      );
      expect(proComm.showsDialog, isTrue);
      expect(proComm.dialogAudience, isEmpty);
    });

    test('sorts communications newest first', () {
      final comms = CommunicationService.parseManifest(sampleManifest);
      expect(comms.first.date.isAfter(comms.last.date), isTrue);
      expect(comms.first.id, '2026-09-targeted');
      expect(comms.last.id, '2025-12-old-news');
    });

    test('parses dialogAudience when present', () {
      final comms = CommunicationService.parseManifest(sampleManifest);
      final targeted = comms.firstWhere((c) => c.id == '2026-09-targeted');
      expect(targeted.dialogAudience, ['free', 'alpha', 'debug']);
    });

    test('dialog flag defaults to false when missing', () {
      final comms = CommunicationService.parseManifest(sampleManifest);
      expect(comms.last.showsDialog, isFalse);
    });

    test('parses dialogMaxVersion when present, null otherwise', () {
      const capped = '''
{
  "communications": [
    {"id": "a", "date": "2026-09-04", "titleKey": "A", "dialog": true, "dialogMaxVersion": "1.13.0"},
    {"id": "b", "date": "2026-09-03", "titleKey": "B", "dialog": true}
  ]
}
''';
      final comms = CommunicationService.parseManifest(capped);
      expect(
        comms.firstWhere((c) => c.id == 'a').dialogMaxVersion,
        '1.13.0',
      );
      expect(comms.firstWhere((c) => c.id == 'b').dialogMaxVersion, isNull);
    });

    test('handles an empty communications list', () {
      final comms =
          CommunicationService.parseManifest('{"communications": []}');
      expect(comms, isEmpty);
    });
  });

  group('CommunicationService dialog flags', () {
    late SharedPreferences prefs;
    late CommunicationService service;
    late Communication comm;

    setUp(() async {
      prefs = await SharedPreferences.getInstance();
      service = CommunicationService(prefs);
      comm = Communication(
        id: 'test-comm',
        date: DateTime.parse('2026-08-23'),
        titleKey: 'Title',
        showsDialog: true,
      );
    });

    test('shouldShowDialog is true before first dismissal', () {
      expect(service.shouldShowDialog(comm), isTrue);
    });

    test('shouldShowDialog is false after markDialogShown', () async {
      await service.markDialogShown(comm);
      expect(service.shouldShowDialog(comm), isFalse);
    });

    test('show-once state persists across restarts', () async {
      await service.markDialogShown(comm);
      final freshPrefs = await SharedPreferences.getInstance();
      final freshService = CommunicationService(freshPrefs);
      expect(freshService.shouldShowDialog(comm), isFalse);
    });

    test('never shows a communication without the dialog flag', () async {
      final silent = Communication(
        id: 'silent-comm',
        date: DateTime.parse('2026-08-23'),
        titleKey: 'Title',
        showsDialog: false,
      );
      expect(service.shouldShowDialog(silent), isFalse);
    });

    group('dialogAudience targeting', () {
      final targeted = Communication(
        id: 'targeted-comm',
        date: DateTime.parse('2026-09-01'),
        titleKey: 'Title',
        showsDialog: true,
        dialogAudience: const ['free', 'alpha', 'debug'],
      );

      test('shown when the build matches one of the audience tags', () {
        expect(
          service.shouldShowDialog(
            targeted,
            buildAudience: {'release', 'free'},
          ),
          isTrue,
        );
        expect(
          service.shouldShowDialog(targeted, buildAudience: {'debug', 'dev'}),
          isTrue,
        );
      });

      test('hidden when the build matches none of the audience tags', () {
        expect(
          service.shouldShowDialog(
            targeted,
            buildAudience: {'release', 'pro'},
          ),
          isFalse,
        );
      });

      test('hidden when no build audience is provided', () {
        expect(service.shouldShowDialog(targeted), isFalse);
      });

      test('an empty audience targets every build', () {
        expect(
          service.shouldShowDialog(comm, buildAudience: {'release', 'pro'}),
          isTrue,
        );
      });
    });

    group('dialogMaxVersion targeting', () {
      Communication capped() => Communication(
            id: 'capped-comm',
            date: DateTime.parse('2026-09-04'),
            titleKey: 'Title',
            showsDialog: true,
            dialogMaxVersion: '1.13.0',
          );

      test('shown on the capped version and older', () {
        expect(
          service.shouldShowDialog(capped(), currentVersion: '1.13.0'),
          isTrue,
        );
        expect(
          service.shouldShowDialog(capped(), currentVersion: '1.12.4'),
          isTrue,
        );
      });

      test('hidden on newer versions', () {
        expect(
          service.shouldShowDialog(capped(), currentVersion: '1.14.0'),
          isFalse,
        );
        expect(
          service.shouldShowDialog(capped(), currentVersion: '1.13.1'),
          isFalse,
        );
      });

      test('a missing current version never suppresses the dialog', () {
        expect(service.shouldShowDialog(capped()), isTrue);
      });

      test('an uncapped dialog ignores the version', () {
        expect(
          service.shouldShowDialog(comm, currentVersion: '9.99.9'),
          isTrue,
        );
      });
    });

    group('compareVersions', () {
      test('orders dotted versions numerically', () {
        expect(
          CommunicationService.compareVersions('1.12.4', '1.13.0'),
          lessThan(0),
        );
        expect(
          CommunicationService.compareVersions('1.13.0', '1.13.0'),
          equals(0),
        );
        expect(
          CommunicationService.compareVersions('1.14.0', '1.13.0'),
          greaterThan(0),
        );
        expect(
          CommunicationService.compareVersions('1.13', '1.13.0'),
          equals(0),
        );
        expect(
          CommunicationService.compareVersions('2.0', '1.99.99'),
          greaterThan(0),
        );
      });
    });
  });
}
