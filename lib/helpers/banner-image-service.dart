import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:uuid/uuid.dart';

/// A picture the user imported from their device to be used as a monthly
/// banner on the homepage.
class UploadedBannerImage {
  final String id;
  final String path;

  const UploadedBannerImage({required this.id, required this.path});

  /// Storage token referencing this image (starts with [BannerImageService.userPrefix]).
  String get token => '${BannerImageService.userPrefix}$path';

  Map<String, dynamic> toJson() => {'id': id, 'path': path};

  factory UploadedBannerImage.fromJson(Map<String, dynamic> json) {
    return UploadedBannerImage(
      id: json['id'] as String? ?? '',
      path: json['path'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UploadedBannerImage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Handles storage and resolution of the monthly homepage banner images.
///
/// A banner is referenced by a "token":
///  - `asset:assets/images/bkg-N.png` -> a built-in picture
///  - `user:/abs/path/to/file.png`    -> a picture imported by the user
///
/// Tokens are persisted in [PreferencesKeys.monthlyBannerAssignments] as a
/// JSON map `month -> token`; imported pictures are listed in
/// [PreferencesKeys.monthlyBannerUploads] and copied into the app documents
/// directory under `user_banners/`.
class BannerImageService {
  BannerImageService._();

  static const String userPrefix = 'user:';
  static const String assetPrefix = 'asset:';
  static const String defaultAsset = 'assets/images/bkg-default.png';

  static String assetToken(String assetName) => '$assetPrefix$assetName';

  static String monthAssetName(int monthIndex) {
    final fileName = (monthIndex > 0 && monthIndex <= 12)
        ? monthIndex.toString()
        : 'default';
    return 'assets/images/bkg-$fileName.png';
  }

  /// Whether monthly banner images should be shifted by 6 months to match
  /// Southern Hemisphere seasons (January shows July's image, and so on).
  static bool get reverseMonthlyImages {
    return ServiceConfig.sharedPreferences
            ?.getBool(PreferencesKeys.reverseMonthlyImages) ??
        false;
  }

  /// Maps a calendar month (1-12) to the built-in image month that should be
  /// displayed for it. When [reverseMonthlyImages] is enabled, images are
  /// shifted by 6 months so January shows July's image and vice versa,
  /// matching the opposite seasons of the Southern Hemisphere.
  static int displayMonth(int monthIndex) {
    if (monthIndex < 1 || monthIndex > 12) return monthIndex;
    if (!reverseMonthlyImages) return monthIndex;
    return ((monthIndex + 5) % 12) + 1;
  }

  static Future<Directory> get _imagesDirectory async {
    final documents = await getApplicationDocumentsDirectory();
    final dir =
        Directory('${documents.path}${Platform.pathSeparator}user_banners');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ---------------- Assignments ----------------

  static Map<int, String> loadAssignmentsSync() {
    final prefs = ServiceConfig.sharedPreferences;
    final raw = prefs?.getString(PreferencesKeys.monthlyBannerAssignments);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <int, String>{};
      decoded.forEach((key, value) {
        final month = int.tryParse(key);
        if (month != null && month >= 1 && month <= 12 && value is String) {
          result[month] = value;
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveAssignments(Map<int, String> assignments) async {
    final prefs = ServiceConfig.sharedPreferences;
    if (prefs == null) return;
    final payload = assignments.map((key, value) => MapEntry('$key', value));
    await prefs.setString(
        PreferencesKeys.monthlyBannerAssignments, jsonEncode(payload));
  }

  // ---------------- Uploads ----------------

  static List<UploadedBannerImage> loadUploadsSync() {
    final prefs = ServiceConfig.sharedPreferences;
    final raw = prefs?.getString(PreferencesKeys.monthlyBannerUploads);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(UploadedBannerImage.fromJson)
          .where((u) => u.id.isNotEmpty && u.path.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveUploads(List<UploadedBannerImage> uploads) async {
    final prefs = ServiceConfig.sharedPreferences;
    if (prefs == null) return;
    final payload = uploads.map((u) => u.toJson()).toList();
    await prefs.setString(
        PreferencesKeys.monthlyBannerUploads, jsonEncode(payload));
  }

  /// Copies [sourcePath] into the app documents directory and returns a new
  /// [UploadedBannerImage]. Returns null on failure.
  static Future<UploadedBannerImage?> importImage(String sourcePath) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) return null;
      final id = const Uuid().v4();
      final fileName = '$id${p.extension(sourcePath)}';
      final directory = await _imagesDirectory;
      final destination = File(p.join(directory.path, fileName));
      await source.copy(destination.path);
      return UploadedBannerImage(id: id, path: destination.path);
    } catch (_) {
      return null;
    }
  }

  // ---------------- Resolution ----------------

  static ImageProvider resolveToken(String token) {
    if (token.startsWith(assetPrefix)) {
      return AssetImage(token.substring(assetPrefix.length));
    }
    if (token.startsWith(userPrefix)) {
      final path = token.substring(userPrefix.length);
      if (File(path).existsSync()) return FileImage(File(path));
    }
    return AssetImage(defaultAsset);
  }

  /// Returns the banner [ImageProvider] to show for the given month (1-12).
  /// If the user assigned a custom picture it is used, otherwise the built-in
  /// month picture (or the default picture for non-premium users).
  static ImageProvider getBannerImage(int monthIndex) {
    if (!ServiceConfig.isPremium) {
      return AssetImage(defaultAsset);
    }
    final token = loadAssignmentsSync()[monthIndex];
    if (token != null && token.isNotEmpty) {
      return resolveToken(token);
    }
    return AssetImage(monthAssetName(displayMonth(monthIndex)));
  }
}
