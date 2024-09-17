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
    var uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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
                      "Clicking the button below you can send us a feedback email. Your feedback is very appreciated and will help us to grow!".i18n,
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
