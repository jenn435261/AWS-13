import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/strings.dart';
import '../components/toast.dart';
import '../theme/app_theme.dart';

/// Privacy-first, opt-in location sharing (civil-unrest / hostile-listener
/// safe). OFF by default; the user picks the audience each time, a duration,
/// and precision; a STOP control is always visible while sharing. The public
/// beacon path shows an explicit warning. Exact location / this screen can be
/// gated behind biometric auth in production.
class LocationShareScreen extends ConsumerStatefulWidget {
  const LocationShareScreen({super.key});

  @override
  ConsumerState<LocationShareScreen> createState() => _State();
}

enum _Audience { contact, channel, publicBeacon }

enum _Precision { exact, approximate }

class _State extends ConsumerState<LocationShareScreen> {
  _Audience _audience = _Audience.contact;
  _Precision _precision = _Precision.approximate;
  Duration _ttl = const Duration(minutes: 15);
  bool _sharing = false;
  DateTime? _expiresAt;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('share_location'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_sharing)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.verified.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.verified.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location_rounded,
                        color: AppTheme.verified),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${l.t('sharing_active')} — ${l.t('expires_in')} '
                        '${_remaining()}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            if (_sharing) const SizedBox(height: 16),

            Text(l.t('share_location'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _audienceTile(_Audience.contact, Icons.person_rounded,
                l.t('share_with_contact')),
            _audienceTile(_Audience.channel, Icons.groups_rounded,
                l.t('share_with_channel')),
            _audienceTile(_Audience.publicBeacon, Icons.public_rounded,
                l.t('share_public_beacon')),

            // Explicit warning for the public beacon path.
            if (_audience == _Audience.publicBeacon)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: scheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l.t('public_beacon_warning'),
                          style: TextStyle(
                              fontSize: 16, color: scheme.onErrorContainer)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            Text(l.t('precision'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(spacing: 10, children: [
              ChoiceChip(
                label: Text(l.t('precision_approx')),
                selected: _precision == _Precision.approximate,
                onSelected: (_) =>
                    setState(() => _precision = _Precision.approximate),
              ),
              ChoiceChip(
                label: Text(l.t('precision_exact')),
                selected: _precision == _Precision.exact,
                onSelected: (_) =>
                    setState(() => _precision = _Precision.exact),
              ),
            ]),

            const SizedBox(height: 20),
            Text(l.t('share_duration'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(spacing: 10, children: [
              ChoiceChip(
                label: Text(l.t('dur_15m')),
                selected: _ttl == const Duration(minutes: 15),
                onSelected: (_) =>
                    setState(() => _ttl = const Duration(minutes: 15)),
              ),
              ChoiceChip(
                label: Text(l.t('dur_1h')),
                selected: _ttl == const Duration(hours: 1),
                onSelected: (_) =>
                    setState(() => _ttl = const Duration(hours: 1)),
              ),
            ]),

            const SizedBox(height: 28),
            if (!_sharing)
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.my_location_rounded),
                label: Text(l.t('share_location')),
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: _stop,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(l.t('stop_sharing')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _audienceTile(_Audience a, IconData icon, String label) {
    return RadioListTile<_Audience>(
      value: a,
      groupValue: _audience,
      onChanged: (v) => setState(() => _audience = v!),
      secondary: Icon(icon),
      title: Text(label, style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
      contentPadding: EdgeInsets.zero,
    );
  }

  String _remaining() {
    final e = _expiresAt;
    if (e == null) return '';
    final left = e.difference(DateTime.now());
    if (left.isNegative) return '0m';
    final m = left.inMinutes;
    return m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '${m}m';
  }

  void _start() {
    HapticFeedback.mediumImpact();
    setState(() {
      _sharing = true;
      _expiresAt = DateTime.now().add(_ttl);
    });
    Toast.show(context, L10n.of(context).t('location_shared'),
        undoLabel: L10n.of(context).t('stop_sharing'), onUndo: _stop);
  }

  void _stop() {
    HapticFeedback.mediumImpact();
    setState(() {
      _sharing = false;
      _expiresAt = null;
    });
    Toast.show(context, L10n.of(context).t('location_share_stopped'));
  }
}
