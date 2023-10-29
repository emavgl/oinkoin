import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import './i18n/feedback-page.i18n.dart';

class FeedbackPage extends StatelessWidget {

  /// FeedbackPage Page
  /// It is a page with one button that launch a email intent.

  final _biggerFont = const TextStyle(fontSize: 18.0);

  _launchURL(String toMailId, String subject, String body) async {
    var url = 'mailto:$toMailId?subject=$subject&body=$body';
    if (await canLaunch(url)) {
      await launch(url);
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
                  'assets/feedback.png', width: 250,
                ),
                new Container(
                    margin: EdgeInsets.all(20),
                    child: Row(
                    children: <Widget>[
                      Flexible(
                          child: new Text("Clicking the button below you can send us a feedback email. Your feedback is very appreciated and will help us to grow!".i18n, style: _biggerFont,))
                    ],
                  )),
                Container(
                  child: Align(
                    alignment: Alignment.center,
                    child: ElevatedButton(
                      onPressed: () => _launchURL('emavgl.app@gmail.com', 'Oinkoin feedback', 'Oinkoin app is ..., because ...'),
                      child: Text("Send a feedback".i18n.toUpperCase(), style: _biggerFont),
                    ),
                  ),
                )
              ],
            ),
          )
      ),
    );
  }

}
