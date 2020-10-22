import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import './i18n/splash-screen.i18n.dart';

class PremiumSplashScren extends StatelessWidget {

  /// Statistics Page
  /// It has takes the initial date, ending date and a list of records
  /// and shows widgets representing statistics of the given records

  final _biggerFont = const TextStyle(fontSize: 18.0);
  final _subtitleFont = const TextStyle(fontSize: 13.0);

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
                  'assets/premium_page_banner.png', width: 250,
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
                      new TextSpan(text: 'Oinkoin Pro'.i18n, style: new TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(
                    margin: EdgeInsets.all(15),
                    child: Column(
                      children: <Widget>[
                        new Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Container(
                                margin: EdgeInsets.all(5),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                        height: 10,
                                        width: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.amber,
                                        )
                                    ),
                                    Text("Filter records by year or custom date range".i18n, style: _biggerFont,),
                                  ],
                                )
                            ),
                          ],
                        ),
                        new Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Container(
                                margin: EdgeInsets.all(5),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                        height: 10,
                                        width: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.amber,
                                        )
                                    ),
                                    Text("Full category icon pack and color picker".i18n, style: _biggerFont,),
                                  ],
                                )
                            ),
                          ],
                        ),
                        new Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Container(
                                margin: EdgeInsets.all(5),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                        height: 10,
                                        width: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.amber,
                                        )
                                    ),
                                    Text("Backup/Restore the application data".i18n, style: _biggerFont,),
                                  ],
                                )
                            ),
                          ],
                        ),
/*                        new Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Container(
                                margin: EdgeInsets.all(5),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                        height: 10,
                                        width: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.amber,
                                        )
                                    ),
                                    Text("Set budgets".i18n, style: _biggerFont,),
                                  ],
                                )
                            ),
                          ],
                        ),*/
                        new Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Container(
                                margin: EdgeInsets.all(5),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                        height: 10,
                                        width: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.amber,
                                        )
                                    ),
                                    Text("Add recurrent expenses".i18n, style: _biggerFont,),
                                  ],
                                )
                            ),
                          ],
                        )
                      ],
                    )
                ),
                Container(
                  child: Align(
                    alignment: Alignment.center,
                    child: RaisedButton(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0.0),
                          side: BorderSide(color: Colors.red)
                      ),
                      onPressed: () async => await _launchURL("https://play.google.com/store/apps/details?id=com.github.emavgl.piggybankpro"),
                      color: Colors.red,
                      textColor: Colors.white,
                      child: Text("DOWNLOAD IT NOW!".i18n, style: _biggerFont),
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
