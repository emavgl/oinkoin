import 'package:flutter/material.dart';
import 'package:piggybank/comms/communication-detail-page.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/communication-service.dart';

/// Settings subpage listing all in-app communications, newest first.
class AnnouncementsPage extends StatelessWidget {
  final CommunicationService communicationService;

  AnnouncementsPage({super.key, CommunicationService? communicationService})
      : communicationService = communicationService ?? CommunicationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Announcements'.i18n),
      ),
      body: FutureBuilder<List<Communication>>(
        future: communicationService.getCommunications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return Center(child: Text('No announcements'.i18n));
          }
          final comms = snapshot.data!;
          return ListView.separated(
            itemCount: comms.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final comm = comms[index];
              return ListTile(
                leading: const Icon(Icons.campaign),
                title: Text(comm.titleKey.i18n),
                subtitle: Text(_formatDate(context, comm.date)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommunicationDetailPage(
                      communication: comm,
                      communicationService: communicationService,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    return MaterialLocalizations.of(context)
            .formatCompactDate(date)
            .toString();
  }
}
