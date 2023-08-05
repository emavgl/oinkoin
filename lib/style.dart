import 'package:flutter/material.dart';

const String FontNameDefault = 'Montserrat';

const Body1Style = TextStyle(
  fontFamily: FontNameDefault,
  fontWeight: FontWeight.w300,
  fontSize: 26.0,
  color: Colors.black,
);

ThemeData materialTheme = ThemeData(
    colorSchemeSeed: Color.fromARGB(255, 0, 92, 184),
    useMaterial3: true,
    brightness: Brightness.light
);