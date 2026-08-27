import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/comms/announcements-page.dart';
import 'package:piggybank/comms/communication-detail-page.dart';
import 'package:piggybank/services/communication-service.dart';

class _FakeCommunicationService implements CommunicationService {
  @override
  Future<List<Communication>> getCommunications() async => [
        Communication(
          id: 'comm-1',
          date: DateTime.parse('2026-08-23'),
          titleKey: 'First announcement',
          showsDialog: true,
        ),
      ];

  @override
  Future<String> loadBody(String communicationId) async {
    return '# Hello\n\nThis is **markdown** body.';
  }

  @override
  bool shouldShowDialog(
    Communication communication, {
    Set<String> buildAudience = const {},
  }) =>
      false;

  @override
  Future<void> markDialogShown(Communication communication) async {}
}

void main() {
  testWidgets('AnnouncementsPage lists communications newest first',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AnnouncementsPage(
        communicationService: _FakeCommunicationService(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('First announcement'), findsOneWidget);
  });

  testWidgets('tapping an entry opens the markdown viewer', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AnnouncementsPage(
        communicationService: _FakeCommunicationService(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('First announcement'));
    await tester.pumpAndSettle();

    expect(find.byType(CommunicationDetailPage), findsOneWidget);
    expect(find.text('Hello', findRichText: true), findsWidgets);
    expect(find.text('First announcement'), findsOneWidget); // app bar title
  });

  testWidgets('viewer renders the localized body content', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CommunicationDetailPage(
        communication: Communication(
          id: 'comm-1',
          date: DateTime.parse('2026-08-23'),
          titleKey: 'First announcement',
          showsDialog: true,
        ),
        communicationService: _FakeCommunicationService(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Hello', findRichText: true), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
