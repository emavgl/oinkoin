import 'package:flutter/material.dart';
import 'package:piggybank/settings/style.dart';

class SettingsItem extends StatelessWidget {
  final Icon icon;
  final String title;
  final Function onPressed;

  final String? subtitle;
  final Color? iconBackgroundColor;

  SettingsItem(
      {this.iconBackgroundColor,
      required this.icon,
      required this.title,
      required this.onPressed,
      this.subtitle});

  @override
  Widget build(BuildContext context) {
    return RawMaterialButton(
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor:
                iconBackgroundColor == null ? Colors.blue : iconBackgroundColor,
            child: icon),
        title: Text(title, style: titleTextStyle),
        subtitle:
            subtitle == null ? null : Text(subtitle!, style: subtitleTextStyle),
      ),
      onPressed: onPressed as void Function()?,
    );
  }
}
