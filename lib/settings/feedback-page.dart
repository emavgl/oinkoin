import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:piggybank/i18n.dart';

class FeedbackPage extends StatelessWidget {
  /// Help & Support Page
  ///
  /// Provides multiple ways for users to get support:
  /// - Direct email to the developer
  /// - Web help center (oinkoin.com/support)
  /// - Rate the app on Google Play (if installed from Play Store)

  static Future<bool> isInstalledFromPlayStore() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      // On Android, this maps directly to the native installer package name
      String? installer = packageInfo.installerStore;

      // 'com.android.vending' is the package name for the Google Play Store
      return installer == 'com.android.vending';
    } catch (e) {
      // Fallback in case of an error
      return false;
    }
  }

  _launchURL(String toMailId, String subject, String body) async {
    body += "\n\n ${ServiceConfig.packageName}-${ServiceConfig.version}";
    var url = 'mailto:$toMailId?subject=$subject&body=$body';

    try {
      // On Linux, url_launcher is unreliable, so we use xdg-open directly
      if (Platform.isLinux) {
        try {
          final result = await Process.run('xdg-open', [url]);
          if (result.exitCode != 0) {
            print('xdg-open failed with exit code: ${result.exitCode}');
            print('stderr: ${result.stderr}');
          }
        } catch (e) {
          print('Failed to run xdg-open: $e');
        }
      } else {
        // On other platforms, use url_launcher
        var uri = Uri.parse(url);
        final mode = (Platform.isWindows || Platform.isMacOS)
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault;

        if (await canLaunchUrl(uri)) {
          final success = await launchUrl(uri, mode: mode);
          if (!success) {
            print('Failed to launch URL: $url');
          }
        } else {
          print('Cannot launch URL: $url');
        }
      }
    } catch (e) {
      print('Error launching URL: $url - $e');
    }
  }

  Future<void> _openWebsite(BuildContext context, String url) async {
    try {
      if (Platform.isLinux) {
        try {
          final result = await Process.run('xdg-open', [url]);
          if (result.exitCode != 0) {
            print('xdg-open failed with exit code: ${result.exitCode}');
          }
        } catch (e) {
          print('Failed to run xdg-open: $e');
        }
      } else {
        var uri = Uri.parse(url);
        final mode = (Platform.isWindows || Platform.isMacOS)
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault;

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: mode);
        } else if (url.startsWith("market://")) {
          // Fallback: try the https Play Store URL
          final httpsUrl = url.replaceFirst(
            "market://details?id=",
            "https://play.google.com/store/apps/details?id=",
          );
          final httpsUri = Uri.parse(httpsUrl);
          if (await canLaunchUrl(httpsUri)) {
            await launchUrl(httpsUri, mode: mode);
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Could not open link".i18n)),
            );
          }
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not open link".i18n)),
          );
        }
      }
    } catch (e) {
      print('Error launching URL: $url - $e');
    }
  }

  Future<String?> _getAppStorePackageName() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.packageName;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Support".i18n),
      ),
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.center,
          child: Column(
            children: <Widget>[
              SizedBox(height: 32),
              Image.asset(
                'assets/images/feedback.png',
                width: 200,
              ),
              SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  "Support the project".i18n,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  "Choose how you'd like to get in touch or support the project."
                      .i18n,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 32),

              // --- Help & Support card ---
              _SupportCard(
                icon: Icons.help_outline,
                iconColor: Colors.blue.shade600,
                iconBackgroundColor: Colors.blue.shade50,
                title: "Support & Contribute".i18n,
                subtitle: "Visit our support page with ways to contribute"
                    .i18n,
                onTap: () => _openWebsite(
                  context,
                  "https://oinkoin.com/support",
                ),
              ),

              SizedBox(height: 12),

              // --- Email card ---
              _SupportCard(
                icon: Icons.email_outlined,
                iconColor: Colors.red.shade600,
                iconBackgroundColor: Colors.red.shade50,
                title: "Send an Email".i18n,
                subtitle:
                    "Write us directly — we read every message".i18n,
                onTap: () => _launchURL(
                  'emavgl.app@gmail.com',
                  'Oinkoin feedback',
                  'Oinkoin app is ..., because ...',
                ),
              ),

              SizedBox(height: 12),

              // --- Rate the app card (Play Store / alpha builds) ---
              FutureBuilder<bool>(
                future: isInstalledFromPlayStore(),
                builder: (context, snapshot) {
                  final isPlayStore = snapshot.data == true;
                  final isAlpha = ServiceConfig.packageName?.contains("alpha") == true;
                  if (!isPlayStore && !isAlpha) return SizedBox.shrink();

                  return FutureBuilder<String?>(
                    future: _getAppStorePackageName(),
                    builder: (context, pkgSnapshot) {
                      final pkgName = pkgSnapshot.data;
                      if (pkgName == null) return SizedBox.shrink();

                      return _SupportCard(
                        icon: Icons.star_border,
                        iconColor: Colors.amber.shade700,
                        iconBackgroundColor: Colors.amber.shade50,
                        title: "Rate the app".i18n,
                        subtitle:
                            "Love Oinkoin? Leave a review on Google Play".i18n,
                        onTap: () => _openWebsite(
                          context,
                          "market://details?id=$pkgName",
                        ),
                      );
                    },
                  );
                },
              ),

              SizedBox(height: 32),

              // Version info
              Text(
                "${ServiceConfig.packageName} ${ServiceConfig.version}",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),

              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// A reusable card widget for support options
class _SupportCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
