import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:piggybank/services/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single in-app communication (announcement).
class Communication {
  /// Asset name (without extension) under `assets/docs/announcements/`,
  /// also used as the stable identifier for show-once dialog flags.
  final String id;

  /// ISO-8601 date (YYYY-MM-DD), used for sorting.
  final DateTime date;

  /// The English string used as the i18n key for the title.
  final String titleKey;

  /// Whether this communication should trigger the startup announcement
  /// dialog (it is always visible on the announcements page).
  final bool showsDialog;

  /// Build audiences the startup dialog is restricted to (e.g. `['free',
  /// 'alpha', 'debug']`). Empty means "every build". Matching is an
  /// intersection against the tags returned by [resolveBuildAudience]; the
  /// entry on the announcements page is never affected.
  final List<String> dialogAudience;

  /// Last app version (e.g. `"1.13.0"`) whose users still see the startup
  /// dialog. Newer versions skip it (the entry stays on the announcements
  /// page). Null means "no version cap".
  final String? dialogMaxVersion;

  const Communication({
    required this.id,
    required this.date,
    required this.titleKey,
    required this.showsDialog,
    this.dialogAudience = const [],
    this.dialogMaxVersion,
  });
}

/// Loads in-app communications stored as markdown assets.
///
/// Layout (announcements are English-only by decision):
/// ```
/// assets/docs/announcements/
///   manifest.json
///   <id>.md
/// ```
class CommunicationService {
  static const String _manifestAsset =
      'assets/docs/announcements/manifest.json';
  static const String _commsAssetPrefix = 'assets/docs/announcements/';

  static const String shownDialogKeyPrefix = 'comms_dialog_shown_';

  static final Logger _logger = Logger.withClass(CommunicationService);

  final SharedPreferences? _prefs;

  CommunicationService([this._prefs]);

  /// Parses [manifestJson] into communications sorted newest-first.
  @visibleForTesting
  static List<Communication> parseManifest(String manifestJson) {
    final decoded = json.decode(manifestJson) as Map<String, dynamic>;
    final items = decoded['communications'] as List<dynamic>? ?? [];
    final comms = items.map((item) {
      final map = item as Map<String, dynamic>;
      return Communication(
        id: map['id'] as String,
        date: DateTime.parse(map['date'] as String),
        titleKey: map['titleKey'] as String,
        showsDialog: (map['dialog'] as bool?) ?? false,
        dialogAudience:
            (map['dialogAudience'] as List<dynamic>?)?.cast<String>() ??
                const [],
        dialogMaxVersion: map['dialogMaxVersion'] as String?,
      );
    }).toList();
    comms.sort((a, b) => b.date.compareTo(a.date));
    return comms;
  }

  /// Compares dotted version names (`"1.13.0"`, `"1.13"`). Returns a negative
  /// number when [a] is older, zero when equal, positive when newer.
  /// Non-numeric segments are ignored so a malformed version can never
  /// suppress an announcement by accident.
  @visibleForTesting
  static int compareVersions(String a, String b) {
    int part(String version, int index) {
      final segments = version.split('.');
      if (index >= segments.length) return 0;
      return int.tryParse(segments[index].replaceAll(RegExp(r'[^0-9]'), '')) ??
          0;
    }

    final length = [a.split('.').length, b.split('.').length]
        .reduce((x, y) => x > y ? x : y);
    for (var i = 0; i < length; i++) {
      final diff = part(a, i) - part(b, i);
      if (diff != 0) return diff;
    }
    return 0;
  }

  /// All communications, newest first. Returns an empty list if the
  /// manifest is missing or malformed (announcements are non-critical).
  Future<List<Communication>> getCommunications() async {
    try {
      final raw = await rootBundle.loadString(_manifestAsset);
      return parseManifest(raw);
    } catch (e) {
      _logger.error('Failed to load communications manifest: $e');
      return [];
    }
  }

  /// Loads the markdown body of [communicationId]. Throws if the asset is
  /// missing.
  Future<String> loadBody(String communicationId) async {
    return rootBundle.loadString('$_commsAssetPrefix$communicationId.md');
  }

  /// Whether the startup dialog for [communication] still needs to be shown.
  ///
  /// [buildAudience] is the set of tags describing the running build (see
  /// [resolveBuildAudience]); when the communication restricts its audience,
  /// the dialog is shown only if the two sets intersect.
  /// [currentVersion] is the running app version (e.g. from
  /// [ServiceConfig.version]); when the communication declares
  /// [Communication.dialogMaxVersion], the dialog is skipped on newer
  /// versions. A missing version never suppresses the dialog.
  bool shouldShowDialog(
    Communication communication, {
    Set<String> buildAudience = const {},
    String? currentVersion,
  }) {
    if (!communication.showsDialog || _prefs == null) return false;
    if (communication.dialogAudience.isNotEmpty &&
        !communication.dialogAudience.any(buildAudience.contains)) {
      return false;
    }
    final maxVersion = communication.dialogMaxVersion;
    if (maxVersion != null &&
        maxVersion.isNotEmpty &&
        currentVersion != null &&
        currentVersion.isNotEmpty &&
        compareVersions(currentVersion, maxVersion) > 0) {
      return false;
    }
    return !(_prefs.getBool('$shownDialogKeyPrefix${communication.id}') ??
        false);
  }

  /// Permanently silences the startup dialog for [communication].
  Future<void> markDialogShown(Communication communication) {
    return _prefs?.setBool(
          '$shownDialogKeyPrefix${communication.id}',
          true,
        ) ??
        Future.value();
  }
}
