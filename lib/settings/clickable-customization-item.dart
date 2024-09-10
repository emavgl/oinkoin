import 'package:flutter/material.dart';
import 'package:piggybank/settings/style.dart';

import '../services/service-config.dart';

class ClickableCustomizationItem<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final Function()? action;

  ClickableCustomizationItem(
      {required this.title,
        required this.subtitle,
        this.action});

  Widget buildHeader() {
    return Column(
      children: [
        ListTile(
          title: Text(title),
          subtitle: Text(subtitle),
        ),
        Divider()
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: action,
      title: Text(title, style: titleTextStyle),
      subtitle: Text(subtitle, style: subtitleTextStyle),
      contentPadding: EdgeInsets.fromLTRB(16, 0, 10, 10),
    );
  }
}
