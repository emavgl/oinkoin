import 'package:flutter/material.dart';

Widget getProLabel({labelFontSize = 10.0}) {
  return Container(
    color: Colors.black,
    padding: EdgeInsets.all(5),
    child: Text(
      "PRO",
      style: TextStyle(fontSize: labelFontSize, color: Colors.white),
    ),
  );
}
