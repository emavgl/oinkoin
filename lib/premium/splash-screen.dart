import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:piggybank/i18n.dart';

class PremiumSplashScreen extends StatelessWidget {
  final _biggerFont = const TextStyle(fontSize: 18.0);

  _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Upgrade to Pro".i18n),
      ),
      body: SingleChildScrollView(
          child: Align(
        alignment: Alignment.center,
        child: Column(
          children: <Widget>[
            Image.asset(
              'assets/images/premium_page_banner.png',
              width: 250,
            ),
            RichText(
              text: new TextSpan(
                // Note: Styles for TextSpans must be explicitly defined.
                // Child text spans will inherit styles from parent
                style: new TextStyle(
                  fontSize: 16.0,
                  color: Colors.black,
                ),
                children: <TextSpan>[
                  new TextSpan(text: 'Upgrade to'.i18n),
                  new TextSpan(text: ' '),
                  new TextSpan(
                      text: 'Oinkoin Pro'.i18n,
                      style: new TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Container(
                margin: EdgeInsets.all(15),
                padding: EdgeInsets.all(5),
                child: Column(
                  children: <Widget>[
                    new Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                            child: Row(
                              children: <Widget>[
                                Container(
                                    height: 10,
                                    width: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.amber,
                                    )),
                                SizedBox(width: 8), // Add some space between the circle and text
                                Expanded( // Wrap the text widget with Flexible
                                  child: Text(
                                    "Filter records by year or custom date range".i18n,
                                    style: _biggerFont,
                                    overflow: TextOverflow.visible, // Ensure text can wrap
                                    softWrap: true, // Enable soft wrapping
                                  ),
                                ),
                              ],
                            )),
                      ],
                    ),
                    new Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                            child: Row(
                              children: <Widget>[
                                Container(
                                    height: 10,
                                    width: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.amber,
                                    )),
                                SizedBox(width: 8), // Add some space between the circle and text
                                Expanded( // Wrap the text widget with Flexible
                                  child: Text(
                                    "Full category icon pack and color picker"
                                        .i18n,
                                    style: _biggerFont,
                                  ),
                                ),
                              ],
                            )),
                      ],
                    ),
                    new Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                            child: Row(
                              children: <Widget>[
                                Container(
                                    height: 10,
                                    width: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.amber,
                                    )),
                                SizedBox(width: 8), // Add some space between the circle and text
                                Expanded( // Wrap the text widget with Flexible
                                  child: Text(
                                    "Backup/Restore the application data".i18n,
                                    style: _biggerFont,
                                  ),
                                ),
                              ],
                            )),
                      ],
                    ),
                    new Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                            child: Row(
                              children: <Widget>[
                                Container(
                                    height: 10,
                                    width: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.amber,
                                    )),
                                SizedBox(width: 8), // Add some space between the circle and text
                                Expanded( // Wrap the text widget with Flexible
                                  child: Text(
                                    "Add recurrent expenses".i18n,
                                    style: _biggerFont,
                                  ),
                                ),
                              ],
                            )),
                      ],
                    )
                  ],
                )),
            Container(
              child: Align(
                alignment: Alignment.center,
                child: ElevatedButton(
                  onPressed: () async => await _launchURL(
                      "https://play.google.com/store/apps/details?id=com.github.emavgl.piggybankpro"),
                  child: Text("DOWNLOAD IT NOW!".i18n, style: _biggerFont),
                ),
              ),
            )
          ],
        ),
      )),
    );
  }
}
