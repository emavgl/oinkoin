import 'package:flutter/material.dart';
import 'package:piggybank/settings/style.dart';

class SettingsItem extends StatelessWidget {
  final Color? iconBackgroundColor;
  final Icon icon;
  final String title;
  final String subtitle;
  final Function onPressed;

  SettingsItem(
      {this.iconBackgroundColor,
      required this.icon,
      required this.title,
      required this.onPressed,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return RawMaterialButton(
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor:
                iconBackgroundColor == null ? Colors.blue : iconBackgroundColor,
            child: icon),
        title: Text(title, style: titleTextStyle),
        subtitle: Text(subtitle, style: subtitleTextStyle),
      ),
      onPressed: onPressed as void Function()?,
    );
  }
}
