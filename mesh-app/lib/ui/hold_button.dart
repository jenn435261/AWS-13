import 'package:flutter/material.dart';

import 'feedback.dart';

/// Press and hold to confirm. Used for SOS and erase, so a bump in a pocket
/// can't set them off. Ticks at each quarter, then a strong buzz when done.
///
/// Screen reader users trigger it with their long-press gesture.
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.onHeld,
    required this.builder,
    required this.semanticsLabel,
    this.semanticsHint,
    this.onTap,
    this.duration = const Duration(seconds: 2),
  });

  final VoidCallback onHeld;

  /// A quick tap, released before the hold had a chance to start.
  final VoidCallback? onTap;
  final Duration duration;

  /// [progress] runs from 0 to 1 while held.
  final Widget Function(BuildContext context, double progress) builder;
  final String semanticsLabel;
  final String? semanticsHint;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )
    ..addListener(_onProgress)
    // Completion comes from the status, not the value: a slow phone can
    // jump straight to the end in one frame.
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && !_fired) _fire();
    });

  int _quarter = 0;
  bool _fired = false;

  void _onProgress() {
    final q = (_controller.value * 4).floor();
    if (q > _quarter && q < 4) Haptics.tick();
    _quarter = q;
  }

  void _fire() {
    _fired = true;
    Haptics.strong();
    widget.onHeld();
  }

  void _down() {
    _fired = false;
    // Start from zero every time. A controller left at 1.0 by a cancelled
    // hold would never report "completed" again, so the next SOS would not fire.
    _controller.forward(from: 0);
  }

  void _up() {
    final wasTap = _controller.value < 0.15;
    if (!_fired) _controller.reverse();
    if (wasTap && !_fired) widget.onTap?.call();
    if (_fired) _controller.value = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      hint: widget.semanticsHint,
      excludeSemantics: true,
      onTap: widget.onTap,
      onLongPress: _fire,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _down(),
        onTapUp: (_) => _up(),
        onTapCancel: () {
          if (_fired) {
            _controller.value = 0;
          } else {
            _controller.reverse();
          }
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => widget.builder(context, _controller.value),
        ),
      ),
    );
  }
}
