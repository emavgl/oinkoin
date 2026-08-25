import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/communication-service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders the localized markdown body of a [communication].
class CommunicationDetailPage extends StatelessWidget {
  final Communication communication;
  final CommunicationService? _injectedService;

  static final CommunicationService _defaultService = CommunicationService();

  CommunicationDetailPage({
    super.key,
    required this.communication,
    CommunicationService? communicationService,
  }) : _injectedService = communicationService;

  CommunicationService get communicationService =>
      _injectedService ?? _defaultService;

  Future<String> _loadBody() async {
    return communicationService.loadBody(communication.id);
  }

  void _openLink(String url) {
    launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(communication.titleKey.i18n),
      ),
      body: FutureBuilder<String>(
        future: _loadBody(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Could not load this announcement'.i18n));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: MarkdownBody(
              data: snapshot.data!,
              onTapLink: (text, href, title) {
                if (href != null) _openLink(href);
              },
            ),
          );
        },
      ),
    );
  }
}
