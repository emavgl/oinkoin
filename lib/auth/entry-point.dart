import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:piggybank/auth/signin-page.dart';
import '../home-page.dart';

class EntryPoint extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Login failed"));
          } else if (snapshot.hasData) {
            // login successful
            return HomePage();
          }
          return SigninPage();
        }
    );
  }
}