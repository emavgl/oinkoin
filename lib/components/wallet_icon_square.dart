import 'package:flutter/material.dart';

class WalletIconSquare extends StatelessWidget {
  final String? iconEmoji;
  final IconData? iconDataFromDefaultIconSet;
  final Color? backgroundColor;
  final IconData? overlayIcon;
  final double mainIconSize;
  final double size;
  final double cornerRadius;

  const WalletIconSquare({
    Key? key,
    this.iconEmoji,
    this.iconDataFromDefaultIconSet,
    this.backgroundColor,
    this.overlayIcon,
    this.mainIconSize = 20.0,
    this.size = 40.0,
    this.cornerRadius = 10.0,
  }) : super(key: key);

  Widget _buildSquare(BuildContext context) {
    final bg = backgroundColor ?? Theme.of(context).colorScheme.surface;
    final iconColor = iconEmoji == null
        ? (backgroundColor != null
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface)
        : null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: iconEmoji != null
          ? Center(
              child: Text(
                iconEmoji!,
                style: TextStyle(fontSize: mainIconSize),
              ),
            )
          : Icon(
              iconDataFromDefaultIconSet,
              size: mainIconSize,
              color: iconColor ?? Theme.of(context).colorScheme.onSurface,
            ),
    );
  }

  Widget _buildOverlayIcon(BuildContext context) {
    final overlaySize = size / 2;
    return Transform.translate(
      offset: Offset(size - 10, size - 16),
      child: Container(
        width: overlaySize,
        height: overlaySize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor != null
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context)
                  .colorScheme
                  .surfaceContainer
                  .withValues(alpha: 0.8),
        ),
        child: Icon(
          overlayIcon,
          size: size * 0.375,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildSquare(context),
        if (overlayIcon != null) _buildOverlayIcon(context),
      ],
    );
  }
}
