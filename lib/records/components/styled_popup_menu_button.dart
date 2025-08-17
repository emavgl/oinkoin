// ================================
// File: tab_records.dart
// Main widget file - focused on UI structure
// ================================

import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';

class StyledPopupMenuButton extends StatelessWidget {
  final Function(int) onSelected;
  final double scaleFactor;

  const StyledPopupMenuButton({
    Key? key,
    required this.onSelected,
    this.scaleFactor = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double iconSize = 24.0 * scaleFactor;
    final double buttonSize = 48.0 * scaleFactor;

    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: PopupMenuButton<int>(
        icon: Semantics(
          identifier: 'three-dots',
          child: Icon(
            Icons.more_vert,
            color: Colors.white,
            size: iconSize,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10.0)),
        ),
        onSelected: onSelected,
        itemBuilder: _buildPopupMenuItems,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: buttonSize,
          minHeight: buttonSize,
          maxWidth: buttonSize,
          maxHeight: buttonSize,
        ),
      ),
    );
  }

  List<PopupMenuItem<int>> _buildPopupMenuItems(BuildContext context) {
    return {"Export CSV".i18n: 1}.entries.map((entry) {
      return PopupMenuItem<int>(
        padding: EdgeInsets.all(20),
        value: entry.value,
        child: Text(
          entry.key,
          style: TextStyle(fontSize: 16),
        ),
      );
    }).toList();
  }
}
