import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/communication-service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Startup announcement dialog for a [Communication]. Dismissing it
/// (any button, back gesture, or tapping outside) permanently silences it.
class AnnouncementDialog extends StatelessWidget {
  final Communication communication;
  final CommunicationService communicationService;

  const AnnouncementDialog({
    super.key,
    required this.communication,
    required this.communicationService,
  });

  Future<String> _loadBody() async {
    return communicationService.loadBody(communication.id);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<String>(
            future: _loadBody(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                    height: 32,
                    width: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Text('Could not load this announcement'.i18n);
              }
              return MarkdownBody(
                data: snapshot.data!,
                onTapLink: (text, href, title) {
                  if (href != null) {
                    launchUrl(
                      Uri.parse(href),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('announcement-dialog-ok'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Got it'.i18n),
        ),
      ],
    );
  }
}

/// Checks pending communications and shows the announcement dialog for the
/// first one that has not been dismissed yet. Marks it as shown on close.
Future<void> maybeShowAnnouncementDialog(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final service = CommunicationService(prefs);
  final communications = await service.getCommunications();
  if (!context.mounted) return;
  for (final comm in communications) {
    if (!service.shouldShowDialog(comm)) continue;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AnnouncementDialog(
        communication: comm,
        communicationService: service,
      ),
    );
    await service.markDialogShown(comm);
    break;
  }
}
