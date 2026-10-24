import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/mesh_node.dart';
import '../../ui/surfaces.dart';
import '../../ui/theme.dart';

/// Size of a map pin, and of the marker box that leaves room to grow it when
/// selected. Pins point at their place with the tip.
const pinSize = Size(40, 52);
const pinBox = Size(56, 66);

/// A teardrop map pin in a category's color. [solid] pins are filled (for
/// verified places and requests); others are white with a colored edge.
/// [mark] is a small trust sign in the top corner.
class MapPin extends StatelessWidget {
  const MapPin({
    super.key,
    required this.icon,
    required this.hue,
    this.solid = true,
    this.mark,
    this.selected = false,
    this.faded = false,
  });

  final IconData icon;
  final Color hue;
  final bool solid;
  final Widget? mark;

  /// Selected pins grow a little, so you can match the pin to its card.
  final bool selected;

  /// Stale information stays visible but fades (Spec 10, 66).
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = solid
        ? Colors.white
        : dark
            ? Color.lerp(hue, Colors.white, 0.45)!
            : hue;

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedScale(
        scale: selected ? 1.25 : 1,
        alignment: Alignment.bottomCenter,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Opacity(
          opacity: faded ? 0.55 : 1,
          child: SizedBox.fromSize(
            size: pinSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PinPainter(
                      fill: solid ? hue : c.surfaceContainerLowest,
                      edge: solid ? Colors.white : hue,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: pinSize.width / 2 - 10,
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                if (mark != null) Positioned(right: -6, top: -5, child: mark!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  _PinPainter({required this.fill, required this.edge});

  final Color fill;
  final Color edge;

  Path _shape(Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final d = size.height - r;
    final a = acos(r / d);
    final start = pi / 2 - a;
    return Path()
      ..moveTo(r, size.height)
      ..lineTo(center.dx + r * cos(start), center.dy + r * sin(start))
      ..arcTo(Rect.fromCircle(center: center, radius: r), start, -(2 * pi - 2 * a), false)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shape(size);
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.fill != fill || old.edge != edge;
}

/// A small round sign on a pin or badge: a check for verified, a warning for
/// unconfirmed.
class TrustMark extends StatelessWidget {
  const TrustMark({super.key, required this.icon, required this.color, this.size = 22});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
      child: Icon(icon, size: max(minFontSize, size * 0.78), color: color),
    );
  }
}

/// A radio on the map, dimmed when it hasn't been heard lately.
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.node});

  final MeshNode node;

  static const size = 36.0;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final mesh = AppColors.of(context).map.mesh;
    final online = node.isOnline;
    return Center(
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c.surfaceContainerLowest,
          shape: BoxShape.circle,
          border: Border.all(color: online ? mesh : c.outline, width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
        ),
        child: Icon(Icons.cell_tower, size: 18, color: online ? mesh : c.outline),
      ),
    );
  }
}

/// You are here: a dot with a slow pulse, like the phone's own maps.
class MeDot extends StatelessWidget {
  const MeDot({super.key});

  static const size = 64.0;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Pulse(
        color: c.primary,
        size: size,
        period: const Duration(milliseconds: 2600),
        rings: 1,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.primary,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}
