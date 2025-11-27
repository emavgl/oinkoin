import 'dart:ui';

import 'package:flutter/material.dart';

String serializeColorToString(Color color) {
  return colorComponentToInteger(color.a).toString() +
      ":" +
      colorComponentToInteger(color.r).toString() +
      ":" +
      colorComponentToInteger(color.g).toString() +
      ":" +
      colorComponentToInteger(color.b).toString();
}

int colorComponentToInteger(double colorComponent) {
  return (colorComponent * 255.0).round() & 0xff;
}
