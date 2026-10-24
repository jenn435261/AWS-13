import 'package:flutter/material.dart';

import 'feedback.dart';
import 'theme.dart';
import 'visuals.dart';

/// The app's only shadow: one plain grey layer, small and close, for things
/// that float over other content (map panels, the bottom bar, the Help
/// button). Never a glow, never colored.
List<BoxShadow> softShadow(BuildContext context, {double lift = 1}) => [
      BoxShadow(
        color: AppColors.of(context).shadow,
        blurRadius: 6 * lift,
        offset: Offset(0, 2 * lift),
      ),
    ];

/// Whether the person asked the phone for less motion.
bool reduceMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// A panel that floats over the map, and the bottom bar: a solid surface
/// with a thin outline and [softShadow], so it stays readable over busy
/// streets. No blur and nothing see-through. In high contrast the outline
/// is thicker and darker and the fill is the page color itself.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.onTap,
    this.onLongPress,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Replaces the fill, for urgent panels. A see-through tint is laid over
  /// the solid fill, so the panel itself stays solid.
  final Color? tint;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Off for small labels that sit flat on the map.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: colors.glassBorder, width: colors.borderWidth),
    );
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null || onLongPress != null) {
      content = InkWell(
        customBorder: shape,
        onTap: onTap == null
            ? null
            : () {
                Haptics.tick();
                onTap!();
              },
        onLongPress: onLongPress == null
            ? null
            : () {
                Haptics.success();
                onLongPress!();
              },
        child: content,
      );
    }
    final panel = Material(
      color: tint == null ? colors.glass : Color.alphaBlend(tint!, colors.glass),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
    if (!shadow) return panel;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: softShadow(context),
      ),
      child: panel,
    );
  }
}

/// A rounded-square icon in a category's color. [solid] fills it with the
/// color and a white icon; otherwise it is a soft tint of the color.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 52,
    this.solid = false,
    this.foreground,
  });

  final IconData icon;
  final Color color;
  final double size;
  final bool solid;

  /// Overrides the icon color, for light hues that need a dark icon.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = foreground ??
        (solid ? Colors.white : dark ? Color.lerp(color, Colors.white, 0.45)! : color);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        color: solid ? color : color.withValues(alpha: dark ? 0.22 : 0.12),
      ),
      child: Icon(icon, color: iconColor, size: size * 0.5),
    );
  }
}

/// The one big action at the bottom of a screen: a solid pill in the brand
/// color, or in [color] when given. Disabled is flat and muted.
class MainButton extends StatelessWidget {
  const MainButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final background = color ?? c.primary;
    final foreground = color == null ? c.onPrimary : Colors.white;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: c.surfaceContainerHighest,
        disabledForegroundColor: c.onSurfaceVariant,
        textStyle: Theme.of(context).textTheme.titleMedium,
      ),
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Rings that grow and fade out from the center, on repeat. Draws a single
/// still ring when the phone asks for less motion.
class Pulse extends StatefulWidget {
  const Pulse({
    super.key,
    required this.color,
    required this.size,
    this.child,
    this.period = const Duration(milliseconds: 2200),
    this.rings = 2,
  });

  final Color color;

  /// Width and height of the area the rings grow into.
  final double size;
  final Widget? child;
  final Duration period;
  final int rings;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PulsePainter(
            animation: _controller,
            color: widget.color,
            rings: widget.rings,
            still: still,
          ),
          child: widget.child == null ? null : Center(child: widget.child),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.animation,
    required this.color,
    required this.rings,
    required this.still,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final int rings;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    if (still) {
      canvas.drawCircle(
        center,
        maxRadius * 0.8,
        Paint()..color = color.withValues(alpha: 0.18),
      );
      return;
    }
    for (var i = 0; i < rings; i++) {
      final t = (animation.value + i / rings) % 1;
      final eased = Curves.easeOut.transform(t);
      canvas.drawCircle(
        center,
        maxRadius * (0.35 + 0.65 * eased),
        Paint()..color = color.withValues(alpha: 0.32 * (1 - t)),
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.color != color || old.still != still || old.rings != rings;
}

/// A rounded card holding a group of rows, like a settings section.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.children, this.margin});

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) Divider(height: 1, indent: 76, color: c.outlineVariant),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// A small heading above a [GroupCard].
class GroupHeader extends StatelessWidget {
  const GroupHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 10),
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

/// One row in a [GroupCard]: a colored icon, a title, one line of state,
/// and a chevron when it opens something.
class GroupTile extends StatelessWidget {
  const GroupTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.hue,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// The icon's color; defaults to the brand color.
  final Color? hue;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ListTile(
      shape: const RoundedRectangleBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: IconTile(icon: icon, color: hue ?? c.primary, size: 44),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing ?? (onTap == null ? null : Icon(Icons.chevron_right, color: c.outline)),
      onTap: onTap == null
          ? null
          : () {
              Haptics.tick();
              onTap!();
            },
    );
  }
}

/// A person's initial on a circle in their own color.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hue = personHue(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: hue),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
