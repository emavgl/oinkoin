import 'dart:io';

import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:url_launcher/url_launcher.dart';

class ContributorsPage extends StatelessWidget {
  static const _codeContributors = [
    _Contributor('Niaz Sagor', 'NiazSagor', null),
    _Contributor('Raul Sorrentino', 'raulsorrentino', null),
    _Contributor('Theodoros Gkoltsios', 'TeoOG', 'Greek (el)'),
    _Contributor('emvi-dt', 'emvi-dt', null),
    _Contributor('Sgt-Spaghetti', 'Sgt-Spaghetti', 'English GB (en-GB)'),
    _Contributor('DSiekmeier', 'DSiekmeier', 'German (de)'),
    _Contributor('Luis Peterle', 'luispeterle', 'Portuguese Brazil (pt-BR)'),
    _Contributor('mrestivill', 'mrestivill', 'Catalan (ca)'),
    _Contributor('Prasanna Venkadesh', 'PrasannaVenkadesh', 'Tamil (ta-IN)'),
    _Contributor('Samvel', 'Samvel27', 'Armenian (hy)'),
    _Contributor('monta-gh', 'monta-gh', 'Japanese (ja)'),
    _Contributor('qvalentin', 'qvalentin', null),
    _Contributor('Yurt Page', 'yurtpage', null),
  ];

  static const _translatorsOnly = [
    _Contributor('demoshreder', 'demoshreder', 'Tamil (ta-IN)'),
  ];

  Future<void> _openGitHub(BuildContext context, String username) async {
    final url = 'https://github.com/$username';
    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Contributors'.i18n)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Text(
              'Oinkoin is built by volunteers from around the world. Thank you!'
                  .i18n,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          _SectionHeader('Maintainer'.i18n),
          _ContributorTile(
            name: 'Emanuele Viglianisi',
            username: 'emavgl',
            role: 'Creator & maintainer'.i18n,
            onTap: () => _openGitHub(context, 'emavgl'),
          ),
          const SizedBox(height: 8),
          _SectionHeader('Code Contributors'.i18n),
          for (final c in _codeContributors)
            _ContributorTile(
              name: c.name,
              username: c.username,
              role: c.language != null
                  ? '${'Code & translation'.i18n} · ${c.language}'
                  : 'Code contributor'.i18n,
              onTap: () => _openGitHub(context, c.username),
            ),
          const SizedBox(height: 8),
          _SectionHeader('Translators'.i18n),
          for (final c in _translatorsOnly)
            _ContributorTile(
              name: c.name,
              username: c.username,
              role: c.language ?? '',
              onTap: () => _openGitHub(context, c.username),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              'Additional translations contributed via Crowdin.'.i18n,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Contributor {
  final String name;
  final String username;
  final String? language;
  const _Contributor(this.name, this.username, this.language);
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ContributorTile extends StatelessWidget {
  final String name;
  final String username;
  final String role;
  final VoidCallback onTap;

  const _ContributorTile({
    required this.name,
    required this.username,
    required this.role,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '@$username · $role',
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      trailing: Icon(Icons.open_in_new,
          size: 16, color: colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
