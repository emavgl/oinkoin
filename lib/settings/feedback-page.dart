import 'dart:io';

import 'package:flutter/material.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:piggybank/i18n.dart';

class FeedbackPage extends StatelessWidget {
  /// FeedbackPage Page
  /// It is a page with one button that launch a email intent.

  final _biggerFont = const TextStyle(fontSize: 18.0);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Send a feedback".i18n),
      ),
      body: SingleChildScrollView(
          child: Align(
        alignment: Alignment.center,
        child: Column(
          children: <Widget>[
            Image.asset(
              'assets/images/feedback.png',
              width: 250,
            ),
            new Container(
                margin: EdgeInsets.all(20),
                child: Row(
                  children: <Widget>[
                    Flexible(
                        child: new Text(
                      "Clicking the button below you can send us a feedback email. Your feedback is very appreciated and will help us to grow!"
                          .i18n,
                      style: _biggerFont,
                    ))
                  ],
                )),
            Container(
              child: Align(
                alignment: Alignment.center,
                child: ElevatedButton(
                  onPressed: () => _launchURL('emavgl.app@gmail.com',
                      'Oinkoin feedback', 'Oinkoin app is ..., because ...'),
                  child: Text("Send a feedback".i18n.toUpperCase(),
                      style: _biggerFont),
                ),
              ),
            ),
            Container(
              child: Align(
                  alignment: Alignment.center,
                  child: Text("Version: ${ServiceConfig.version}")),
            )
          ],
        ),
      )),
    );
  }
}
