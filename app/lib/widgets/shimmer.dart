import 'package:flutter/material.dart';

import '../theme.dart';

/// Linen placeholder with a slow champagne sheen sweeping across — shown
/// while a saree photo loads (in place of a spinner).
class Shimmer extends StatefulWidget {
  const Shimmer({super.key});
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect "remove animations" in the phone's accessibility settings.
    if (MediaQuery.of(context).disableAnimations) return const ColoredBox(color: kLinen);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final x = -1.5 + 3.0 * _c.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(x - 1, -0.3),
              end: Alignment(x + 1, 0.3),
              colors: const [kLinen, Color(0xFFFBF6EC), kLinen],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}
