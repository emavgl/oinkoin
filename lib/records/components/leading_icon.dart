import 'dart:core';

import 'package:flutter/material.dart';
import 'package:piggybank/models/record.dart';

class LeadingIcon extends StatelessWidget {
  final Record movement;

  LeadingIcon({required this.movement});

  // Helper function to build the main icon container
  Widget _buildMainIcon(BuildContext context, IconData iconData, Color? iconColor, Color backgroundColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
      ),
      child: Icon(
        iconData,
        size: 20,
        color: iconColor ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  // Helper function to build the overlay icon container
  Widget _buildOverlayIcon(BuildContext context, IconData overlayIcon) {
    return Container(
      margin: EdgeInsets.only(left: 32, top: 22),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Icon(
        overlayIcon,
        size: 15,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  // Main function for building icons with or without overlays
  Widget _buildLeadingIcon(BuildContext context, {IconData? overlayIcon}) {
    return Stack(
      children: [
        _buildMainIcon(
          context,
          movement.category!.icon!,
          movement.category!.color != null ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
          movement.category!.color != null ? movement.category!.color!
              : Theme.of(context).colorScheme.surface,
        ),
        if (overlayIcon != null) _buildOverlayIcon(context, overlayIcon),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (movement.category!.isArchived) {
      return _buildLeadingIcon(context, overlayIcon: Icons.archive);
    } else if (movement.recurrencePatternId != null) {
      return _buildLeadingIcon(context, overlayIcon: Icons.repeat);
    } else {
      return _buildLeadingIcon(context);
    }
  }
}
