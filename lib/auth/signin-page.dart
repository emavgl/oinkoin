import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import './i18n/login-page.i18n.dart';
import 'google_sign_in.dart';

class SigninPage extends StatefulWidget {

  @override
  SigninPageState createState() => SigninPageState();
}

class SigninPageState extends State<SigninPage> {

  final _biggerFont = const TextStyle(fontSize: 18.0);

  @override
  void initState() {
    final provider = Provider.of<GoogleSignInProvider>(context, listen: false);
    provider.googleLoginSilently();
  }

  @override
  Widget build(BuildContext context)  => ChangeNotifierProvider<GoogleSignInProvider>(
    create: (context) => GoogleSignInProvider(),
    child: Scaffold(
      appBar: AppBar(title: Text("Login".i18n),),
      body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.center,
            child: Column(
              children: <Widget>[
                Image.asset(
                  'assets/no_entry_2.png', width: 250,
                ),
                Container(
                  margin: EdgeInsets.all(20),
                  child: Text("Start saving with Oinkoin!".i18n, style: TextStyle(fontSize: 21),)
                ),
                Container(
                  margin: EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.center,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          primary: Colors.red,
                          onPrimary: Colors.white,
                          minimumSize: Size(double.infinity, 50)
                      ),
                      icon: FaIcon(FontAwesomeIcons.google, color: Colors.white),
                      onPressed: () {
                        final provider = Provider.of<GoogleSignInProvider>(context, listen: false);
                        provider.googleLogin();
                      },
                      label: Text("Sign in with Google".i18n, style: _biggerFont),
                    ),
                  ),
                )
              ],
            ),
          )
      ),
    )
  );
}