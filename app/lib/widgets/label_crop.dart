import 'package:flutter/widgets.dart';

/// Shows only the top of a saree photo: the bottom strip of every catalogue
/// photo carries the shop label (wholesale "Rs n/-", fabric/brand names,
/// FOAM POUCH card), which must never show on editorial tiles.
/// [keep] is the fraction of the photo height that stays visible.
class LabelCrop extends StatelessWidget {
  final Widget child;
  final double keep;
  const LabelCrop({super.key, required this.child, this.keep = 0.62});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, box) {
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: box.maxWidth,
          maxWidth: box.maxWidth,
          minHeight: box.maxHeight / keep,
          maxHeight: box.maxHeight / keep,
          child: child,
        ),
      );
    });
  }
}
