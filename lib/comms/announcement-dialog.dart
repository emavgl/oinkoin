import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/communication-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Package ids per Android product flavor (see `android/app/build.gradle`).
const _flavorPackageIds = <String, String>{
  'free': 'com.github.emavgl.piggybank',
  'alpha': 'com.github.emavgl.piggybank.alpha.pro',
  'dev': 'com.github.emavgl.piggybank.dev.pro',
  'pro': 'com.github.emavgl.piggybankpro',
};

/// Tags describing the running build, used to target announcement dialogs via
/// a communication's `dialogAudience`. Always contains `debug` or `release`,
/// plus the product flavor (`free` / `alpha` / `dev` / `pro`) when it can be
/// identified from the package id. F-Droid shares the `pro` package id and is
/// therefore reported as `pro`.
Set<String> resolveBuildAudience() {
  final tags = <String>{kDebugMode ? 'debug' : 'release'};
  final packageName = ServiceConfig.packageName;
  for (final entry in _flavorPackageIds.entries) {
    if (entry.value == packageName) {
      tags.add(entry.key);
      break;
    }
  }
  return tags;
}

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
///
/// Pass [service] to inject a pre-built service (mainly for tests); by default
/// it is created from the shared [SharedPreferences] instance.
Future<void> maybeShowAnnouncementDialog(
  BuildContext context, {
  CommunicationService? service,
}) async {
  final resolvedService =
      service ?? CommunicationService(await SharedPreferences.getInstance());
  final communications = await resolvedService.getCommunications();
  final buildAudience = resolveBuildAudience();
  if (!context.mounted) return;
  for (final comm in communications) {
    if (!resolvedService.shouldShowDialog(comm, buildAudience: buildAudience)) {
      continue;
    }
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AnnouncementDialog(
        communication: comm,
        communicationService: resolvedService,
      ),
    );
    await resolvedService.markDialogShown(comm);
    break;
  }
}
