import 'package:flutter/material.dart';

/// A widget that smoothly expands or collapses its child with an animation.
///
/// The animation can be configured to expand either vertically or horizontally
/// and includes both size and fade transitions.
///
/// [AnimatedExpanded] is useful for cases where you want to dynamically show
/// or hide content with a smooth animation, such as expanding a section of a
/// list or a collapsible panel.
///
/// The widget automatically listens for changes to the [expand] property and
/// triggers the animation accordingly.
class AnimatedExpanded extends StatefulWidget {
  /// The widget to display inside the animated container.
  final Widget child;

  /// A boolean flag indicating whether to expand or collapse the [child]
  final bool expand;

  final Duration duration;
  final Curve sizeCurve;
  final Axis axis;

  const AnimatedExpanded({
    this.expand = false,
    required this.child,
    this.duration = const Duration(milliseconds: 425),
    this.sizeCurve = Curves.fastOutSlowIn,
    this.axis = Axis.vertical,
    super.key,
  });

  @override
  _AnimatedExpandedState createState() => _AnimatedExpandedState();
}

class _AnimatedExpandedState extends State<AnimatedExpanded>
    with SingleTickerProviderStateMixin {
  late AnimationController expandController;
  late Animation<double> sizeAnimation;
  late Animation<double> fadeAnimation;

  @override
  void initState() {
    super.initState();
    prepareAnimations();
  }

  void prepareAnimations() {
    expandController = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.expand ? 1.0 : 0.0,
    );
    sizeAnimation = CurvedAnimation(
      parent: expandController,
      curve: widget.sizeCurve,
    );
    fadeAnimation = CurvedAnimation(
      parent: expandController,
      curve: Curves.easeInOut,
    );
    if (widget.expand) {
      expandController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedExpanded oldWidget) {
    super.didUpdateWidget(oldWidget);
    _runExpandCheck();
  }

  void _runExpandCheck() {
    if (widget.expand) {
      expandController.forward();
    } else {
      expandController.reverse();
    }
  }

  @override
  void dispose() {
    expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SizeTransition(
        axis: widget.axis,
        axisAlignment: 1.0,
        sizeFactor: sizeAnimation,
        child: widget.child,
      ),
    );
  }
}
