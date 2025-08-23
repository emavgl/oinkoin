import 'package:flutter/material.dart';

class StyledActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final String? semanticsId;
  final double scaleFactor;

  const StyledActionButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.semanticsId,
    this.scaleFactor = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double iconSize = 24.0 * scaleFactor;
    final double buttonSize = 48.0 * scaleFactor;

    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: IconButton(
        icon: Semantics(
          identifier: semanticsId,
          child: Icon(
            icon,
            color: Colors.white,
            size: iconSize,
          ),
        ),
        onPressed: onPressed,
        tooltip: tooltip,
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
}
