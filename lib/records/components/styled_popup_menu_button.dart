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

    return Container(
      // Use flexible constraints instead of rigid SizedBox
      constraints: BoxConstraints(
        minWidth: 40.0 * scaleFactor,
        minHeight: 40.0 * scaleFactor,
        maxWidth: 56.0 * scaleFactor,
        maxHeight: 56.0 * scaleFactor,
      ),
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
        padding:
            EdgeInsets.all(8.0), // Add some padding for better touch target
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
