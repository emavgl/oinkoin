import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/comms/announcement-dialog.dart';
import 'package:piggybank/services/communication-service.dart';

Communication _comm() => Communication(
      id: 'test-comm',
      date: DateTime.parse('2026-08-23'),
      titleKey: 'Test title',
      showsDialog: true,
    );

class _FakeService implements CommunicationService {
  _FakeService({
    this.communications = const [],
    this.showDialog = true,
  });

  final List<Communication> communications;
  final bool showDialog;
  final List<String> markedShown = [];

  @override
  Future<String> loadBody(String communicationId) async {
    return 'This is the body text.';
  }

  @override
  Future<List<Communication>> getCommunications() async => communications;

  @override
  bool shouldShowDialog(
    Communication communication, {
    Set<String> buildAudience = const {},
  }) =>
      showDialog;

  @override
  Future<void> markDialogShown(Communication communication) async {
    markedShown.add(communication.id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnnouncementDialog', () {
    testWidgets('renders markdown body and closes on Got it',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => AnnouncementDialog(
                      communication: _comm(),
                      communicationService: _FakeService(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('This is the body text.'), findsOneWidget);
      expect(find.byKey(const ValueKey('announcement-dialog-ok')),
          findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('announcement-dialog-ok')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('announcement-dialog-ok')),
          findsNothing);
    });
  });

  group('maybeShowAnnouncementDialog', () {
    testWidgets('shows the pending announcement and marks it shown',
        (tester) async {
      final service = _FakeService(communications: [_comm()]);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                maybeShowAnnouncementDialog(context, service: service);
              });
              return const Scaffold();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This is the body text.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('announcement-dialog-ok')));
      await tester.pumpAndSettle();

      expect(service.markedShown, ['test-comm']);
    });

    testWidgets('does nothing when no announcement is pending',
        (tester) async {
      final service = _FakeService(
        communications: [_comm()],
        showDialog: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                maybeShowAnnouncementDialog(context, service: service);
              });
              return const Scaffold();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('announcement-dialog-ok')),
          findsNothing);
      expect(service.markedShown, isEmpty);
    });
  });
}
