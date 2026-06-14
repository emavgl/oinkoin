import 'package:flutter/material.dart';

extension PaddingExtension on EdgeInsets {
  EdgeInsets withSafeBottom(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return EdgeInsets.only(
      left: left,
      top: top,
      right: right,
      bottom: bottom + safeBottom,
    );
  }
}

extension PaddingDirectionalExtension on EdgeInsetsDirectional {
  EdgeInsetsDirectional withSafeBottom(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return EdgeInsetsDirectional.only(
      start: start,
      top: top,
      end: end,
      bottom: bottom + safeBottom,
    );
  }
}
