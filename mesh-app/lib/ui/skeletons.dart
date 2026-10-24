import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Skeleton loaders that fade one flat color in and out, instead of the
/// package's default shimmering gradient (rule 14). The fade says "still
/// loading"; with reduce motion on it holds still.
PaintingEffect flatSkeletonEffect(Brightness brightness, {bool still = false}) {
  final (from, to) = brightness == Brightness.light
      ? (const Color(0xFFE9EDF4), const Color(0xFFDDE2EB))
      : (const Color(0xFF1B263D), const Color(0xFF223049));
  return still ? SolidColorEffect(color: from) : PulseEffect(from: from, to: to);
}

/// Gives every Skeletonizer below it the flat look. Wrap the app once.
class FlatSkeletons extends StatelessWidget {
  const FlatSkeletons({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SkeletonizerConfig(
      data: SkeletonizerConfigData(
        effectResolver: (brightness) => flatSkeletonEffect(brightness, still: still),
      ),
      child: child,
    );
  }
}
