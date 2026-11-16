import 'dart:math' as math;
import 'package:flutter/material.dart';

RectTween arcTween(Rect? a, Rect? b) => MaterialRectArcTween(begin: a, end: b);

class Reveal extends StatelessWidget {
  final double from;
  final Widget child;
  const Reveal({super.key, required this.from, required this.child});

  @override
  Widget build(BuildContext context) {
    final Animation<double> route =
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    final a = route.drive(CurveTween(
      curve: Interval(from, math.min(1.0, from + 0.35),
          curve: Curves.easeOutCubic),
    ));
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: a.drive(Tween(begin: const Offset(0, 0.2), end: Offset.zero)),
        child: child,
      ),
    );
  }
}

class PressScaleCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const PressScaleCard({super.key, required this.child, required this.onTap});

  @override
  State<PressScaleCard> createState() => _PressScaleCardState();
}

class _PressScaleCardState extends State<PressScaleCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: pressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => pressed = true),
        onTapUp: (_) => setState(() => pressed = false),
        onTapCancel: () => setState(() => pressed = false),
        onTap: widget.onTap,
        child: widget.child,
      ),
    );
  }
}
