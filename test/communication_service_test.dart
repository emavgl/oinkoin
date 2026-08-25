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
      expect(comms, hasLength(2));
      expect(comms.first.id, '2026-08-pro-in-app-purchase');
      expect(comms.first.showsDialog, isTrue);
    });

    test('sorts communications newest first', () {
      final comms = CommunicationService.parseManifest(sampleManifest);
      expect(comms.first.date.isAfter(comms.last.date), isTrue);
      expect(comms.last.id, '2025-12-old-news');
    });

    test('dialog flag defaults to false when missing', () {
      final comms = CommunicationService.parseManifest(sampleManifest);
      expect(comms.last.showsDialog, isFalse);
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
  });
}
