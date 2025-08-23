import 'package:flutter/material.dart';

class TagChip extends StatelessWidget {
  final String labelText;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  final Color? color;
  final Color? selectedColor;
  final Color? textLabelColor;

  const TagChip({
    Key? key,
    required this.labelText,
    required this.isSelected,
    this.onSelected,
    this.color,
    this.selectedColor,
    this.textLabelColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color effectiveLabelColor =
        textLabelColor ?? Theme.of(context).colorScheme.onSurface;

    final effectiveLabelStyle = TextStyle(
      color: effectiveLabelColor,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      fontSize: 14,
    );

    return FilterChip(
        label: Text(labelText, style: effectiveLabelStyle),
        labelStyle: effectiveLabelStyle,
        selected: isSelected,
        onSelected: onSelected,
        checkmarkColor: effectiveLabelColor,
        backgroundColor: color ??
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
        selectedColor: selectedColor ??
            Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.4));
  }
}
