import 'dart:math';

import 'package:flutter/material.dart';

double _bottomOsHeightAdjustment = 10;

extension PaddingExtension on EdgeInsets {
  EdgeInsets withSafeBottom(BuildContext context) {
    double bottomSafeAreaPadding = MediaQuery.paddingOf(context).bottom;

    if (bottomSafeAreaPadding > 0) {
      bottomSafeAreaPadding = max(
        bottomSafeAreaPadding - _bottomOsHeightAdjustment,
        _bottomOsHeightAdjustment,
      );
    }

    return EdgeInsets.only(
      left: left,
      top: top,
      right: right,
      bottom: bottom + bottomSafeAreaPadding,
    );
  }
}

extension PaddingDirectionalExtension on EdgeInsetsDirectional {
  EdgeInsetsDirectional withSafeBottom(BuildContext context) {
    double bottomSafeAreaPadding = MediaQuery.paddingOf(context).bottom;

    if (bottomSafeAreaPadding > 0) {
      bottomSafeAreaPadding = max(
        bottomSafeAreaPadding - _bottomOsHeightAdjustment,
        _bottomOsHeightAdjustment,
      );
    }

    return EdgeInsetsDirectional.only(
      start: start,
      top: top,
      end: end,
      bottom: bottom + bottomSafeAreaPadding,
    );
  }
}
