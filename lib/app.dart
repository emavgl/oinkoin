// app.dart

import 'package:flutter/material.dart';
import 'package:piggybank/screens/main.dart';

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp( // Material app add the bar
      title: 'Welcome to PiggyBank',
      home: RandomMovements(), // The actual content
      //theme: ThemeData(          // Add the 3 lines from here...
      // primaryColor: Colors.white,
      // ),
    );
  }
}