import 'dart:core';

import 'package:flutter/material.dart';

class CategoryIconCircle extends StatelessWidget {
  final String? iconEmoji;
  final IconData? iconDataFromDefaultIconSet;
  final Color? backgroundColor;
  final IconData? overlayIcon;
  final double mainIconSize;
  final double overlayIconSize;
  final double circleSize;

  CategoryIconCircle({
    this.iconEmoji,
    this.iconDataFromDefaultIconSet,
    this.backgroundColor,
    this.overlayIcon = null,
    this.mainIconSize = 20.0,
    this.overlayIconSize = 15.0,
    this.circleSize = 40.0,
  });

  // Helper function to build the main icon container
  Widget _buildMainIcon(
      BuildContext context, Color? iconColor, Color backgroundColor) {
    return Container(
      width: circleSize,
      height: circleSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
      ),
      child: iconEmoji != null
            ?
            Center(
              child: Text(
                iconEmoji!, // Display the emoji
                style: TextStyle(
                  fontSize: mainIconSize, // Adjust the emoji size
                ),
              ),
            )
            : Icon(
          iconDataFromDefaultIconSet, // Fallback to the icon
          size: mainIconSize,
          color: iconColor ?? Theme.of(context).colorScheme.onSurface,
        ),
    );
  }

  // Helper function to build the overlay icon container
  Widget _buildOverlayIcon(
      BuildContext context, IconData overlayIcon, bool iconBackground) {
    return Container(
      margin: EdgeInsets.only(left: circleSize - 8, top: circleSize - 18),
      width: circleSize / 2,
      height: circleSize / 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: iconBackground
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.8),
      ),
      child: Icon(
        overlayIcon,
        size: overlayIconSize,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  // Main function for building icons with or without overlays
  Widget _buildLeadingIcon(BuildContext context, {IconData? overlayIcon}) {
    var iconColor = iconEmoji == null
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return Stack(
      children: [
        _buildMainIcon(
          context,
          iconColor,
          backgroundColor ?? Theme.of(context).colorScheme.surface,
        ),
        if (overlayIcon != null)
          _buildOverlayIcon(
              context, overlayIcon, backgroundColor != null),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildLeadingIcon(context, overlayIcon: overlayIcon);
  }
}
