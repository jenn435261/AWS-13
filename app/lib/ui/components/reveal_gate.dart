import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../auth/authenticator.dart';
import '../../l10n/strings.dart';

/// How long a successful reveal stays visible before auto-hiding.
const Duration kRevealTimeout = Duration(seconds: 30);

/// Wraps sensitive content (the Resilience ID / identity QR) behind a Reveal
/// button. The content is hidden by default. Tapping Reveal:
///   * if Settings "Require unlock" is ON and biometric is available, prompts
///     local_auth; on web / unsupported it shows an explicit confirm + a plain
///     warning that no biometric is available;
///   * if the requirement is OFF it reveals directly.
/// The revealed state is in-memory only and auto-hides after [kRevealTimeout]
/// or when the app is backgrounded. It is NEVER persisted.
class RevealGate extends ConsumerStatefulWidget {
  const RevealGate({
    super.key,
    required this.revealLabel,
    required this.builder,
  });

  /// Label on the collapsed Reveal button.
  final String revealLabel;

  /// Builds the sensitive content once revealed. [hide] re-locks immediately.
  final Widget Function(BuildContext context, VoidCallback hide) builder;

  @override
  ConsumerState<RevealGate> createState() => RevealGateState();
}

class RevealGateState extends ConsumerState<RevealGate>
    with WidgetsBindingObserver {
  bool _revealed = false;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding must re-lock immediately — the unlock never survives the
    // app leaving the foreground.
    if (state != AppLifecycleState.resumed && _revealed) {
      _hide();
    }
  }

  void _hide() {
    _timer?.cancel();
    if (mounted) setState(() => _revealed = false);
  }

  void _armTimeout() {
    _timer?.cancel();
    _timer = Timer(kRevealTimeout, _hide);
  }

  Future<void> _onReveal() async {
    if (_busy) return;
    final settings = ref.read(settingsValueProvider);
    if (!settings.requireUnlock) {
      setState(() => _revealed = true);
      _armTimeout();
      return;
    }
    setState(() => _busy = true);
    try {
      final auth = ref.read(authenticatorProvider);
      final available = await auth.isBiometricAvailable();
      if (!mounted) return;
      if (!available) {
        final ok = await _confirmFallback();
        if (!mounted) return;
        if (ok == true) {
          setState(() => _revealed = true);
          _armTimeout();
        }
        return;
      }
      final outcome =
          await auth.authenticate(reason: L10n.of(context).t('unlock_reason'));
      if (!mounted) return;
      if (outcome == AuthOutcome.approved) {
        setState(() => _revealed = true);
        _armTimeout();
      } else if (outcome == AuthOutcome.unavailable) {
        final ok = await _confirmFallback();
        if (!mounted) return;
        if (ok == true) {
          setState(() => _revealed = true);
          _armTimeout();
        }
      }
      // denied => stay hidden.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Web / unsupported-device fallback: an explicit confirm plus a plain
  /// warning that no biometric is available (honest, never pretends to use one).
  Future<bool?> _confirmFallback() {
    final l = L10n.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('reveal_id')),
        content: Text(l.t('no_biometric_warning'),
            style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.t('reveal_anyway'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    if (_revealed) {
      return widget.builder(context, _hide);
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _onReveal,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.visibility_rounded),
            label: Text(widget.revealLabel.isEmpty
                ? l.t('reveal_id')
                : widget.revealLabel),
          ),
        ),
      ],
    );
  }
}
