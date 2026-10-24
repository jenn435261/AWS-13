import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../identity/identity_card.dart';
import '../../l10n/strings.dart';
import '../../location/location_coordinator.dart';
import '../../location/location_providers.dart';
import '../../location/location_state.dart';
import '../../location/position_service.dart';
import '../components/toast.dart';
import '../theme/app_theme.dart';

/// Privacy-first, opt-in location sharing (civil-unrest / hostile-listener
/// safe). OFF by default; the user picks the audience each time, a duration,
/// and precision; a STOP control is always visible while sharing. The public
/// beacon path shows an explicit warning.
///
/// The precise point is end-to-end encrypted per contact over the SAME durable
/// Signal sessions used for messaging (FEAT-003) and delivered as a signed
/// `LOCATION_SHARE` event over the sync client (FEAT-002); STOP publishes a
/// signed `LOCATION_STOP`. The screen shows honest failure states for location
/// denied / off / timeout and never a crash or infinite spinner.
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

  /// null => a long default sentinel ("until you stop"); see DECISIONS.md.
  Duration? _ttl = const Duration(minutes: 15);

  /// The contacts (by resilience id) currently selected to share with.
  final Set<String> _selected = <String>{};

  bool _busy = false;

  /// "Until I stop" has no finite duration, but the spec requires every share
  /// to carry an expiresMs; we use a long sentinel and record it in
  /// docs/DECISIONS.md.
  static const Duration kUntilStoppedTtl = Duration(days: 7);

  Duration get _effectiveTtl => _ttl ?? kUntilStoppedTtl;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final contactsAsync = ref.watch(contactsProvider);
    final outgoing = ref.watch(outgoingSharesProvider).valueOrNull ??
        const <OutgoingShare>[];
    final sharing = outgoing.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('share_location'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (sharing) _activeBanner(l, outgoing.first),
            if (sharing) const SizedBox(height: 16),

            Text(l.t('share_location'),
                style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            RadioGroup<_Audience>(
              groupValue: _audience,
              onChanged: (v) => setState(() => _audience = v!),
              child: Column(
                children: [
                  _audienceTile(_Audience.contact, Icons.person_rounded,
                      l.t('share_with_contact')),
                  _audienceTile(_Audience.channel, Icons.groups_rounded,
                      l.t('share_with_channel')),
                  _audienceTile(_Audience.publicBeacon, Icons.public_rounded,
                      l.t('share_public_beacon')),
                ],
              ),
            ),

            // Contact picker (only for the contact audience).
            if (_audience == _Audience.contact)
              _contactPicker(l, contactsAsync),

            // Channel sharing is not wired in this screen yet: be honest.
            if (_audience == _Audience.channel)
              _honestNote(scheme, l.t('mission_not_wired')),

            // Explicit warning for the public beacon path.
            if (_audience == _Audience.publicBeacon)
              _beaconWarning(scheme, l),

            const SizedBox(height: 20),
            Text(l.t('precision'),
                style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
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
                style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 4, children: [
              for (final (String key, Duration? d) in <(String, Duration?)>[
                ('dur_15m', const Duration(minutes: 15)),
                ('dur_1h', const Duration(hours: 1)),
                ('dur_4h', const Duration(hours: 4)),
                ('dur_24h', const Duration(hours: 24)),
                ('dur_indefinite', null),
              ])
                ChoiceChip(
                  label: Text(l.t(key)),
                  selected: _ttl == d,
                  onSelected: (_) => setState(() => _ttl = d),
                ),
            ]),

            const SizedBox(height: 28),
            if (!sharing)
              FilledButton.icon(
                onPressed: _busy ? null : () => _share(l),
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded),
                label: Text(l.t('share_now')),
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: scheme.error),
                onPressed: _busy ? null : () => _stop(l),
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(l.t('stop_sharing')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _activeBanner(L10n l, OutgoingShare share) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.verified.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.verified.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location_rounded, color: AppTheme.verified),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${l.t('sharing_active')} — ${l.t('expires_in')} '
              '${_remaining(share.remaining)}',
              style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactPicker(
      L10n l, AsyncValue<List<IdentityCard>> contactsAsync) {
    return contactsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => _honestNote(
          Theme.of(context).colorScheme, l.t('share_no_contacts_hint')),
      data: (contacts) {
        if (contacts.isEmpty) {
          return _honestNote(
              Theme.of(context).colorScheme, l.t('share_no_contacts_hint'));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(l.t('share_choose_contacts'),
                style: const TextStyle(
                    fontFamily: 'Roboto', fontSize: 16)),
            for (final c in contacts)
              CheckboxListTile(
                value: _selected.contains(c.resilienceId),
                onChanged: (v) => setState(() {
                  if (v ?? false) {
                    _selected.add(c.resilienceId);
                  } else {
                    _selected.remove(c.resilienceId);
                  }
                }),
                title: Text(c.displayName,
                    style: const TextStyle(
                        fontFamily: 'Roboto', fontSize: 16)),
                subtitle: Text(c.resilienceId,
                    style: const TextStyle(
                        fontFamily: 'Roboto', fontSize: 14)),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        );
      },
    );
  }

  Widget _honestNote(ColorScheme scheme, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text,
          style: TextStyle(
              fontFamily: 'Roboto', fontSize: 16, color: scheme.outline)),
    );
  }

  Widget _beaconWarning(ColorScheme scheme, L10n l) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l.t('public_beacon_warning'),
                style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  Widget _audienceTile(_Audience a, IconData icon, String label) {
    return RadioListTile<_Audience>(
      value: a,
      secondary: Icon(icon),
      title: Text(label,
          style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
      contentPadding: EdgeInsets.zero,
    );
  }

  String _remaining(Duration left) {
    if (left.isNegative || left == Duration.zero) return '0m';
    final m = left.inMinutes;
    if (m >= 1440) return '${m ~/ 1440}d';
    return m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '${m}m';
  }

  Future<void> _share(L10n l) async {
    if (_audience == _Audience.channel) {
      Toast.show(context, l.t('mission_not_wired'), urgent: true);
      return;
    }
    if (_audience == _Audience.contact && _selected.isEmpty) {
      Toast.show(context, l.t('share_pick_one'), urgent: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final coordinator =
          await ref.read(locationCoordinatorProvider.future);

      if (_audience == _Audience.publicBeacon) {
        await _sharePublicBeacon(l, coordinator);
        return;
      }

      // Contact scope: resolve the selected cards to pubkeys.
      final contacts = await ref.read(contactsProvider.future);
      final chosen = contacts
          .where((c) => _selected.contains(c.resilienceId))
          .map((c) => c.signingPublicKey.toList())
          .toList();

      final ShareResult res = await coordinator.shareWithContacts(
        contacts: chosen,
        precision: _precision == _Precision.exact
            ? SharePrecision.exact
            : SharePrecision.approximate,
        ttl: _effectiveTtl,
      );
      _handleResult(l, res);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        bumpWorld(ref); // triggers a sync + recomputes derived state
      }
    }
  }

  Future<void> _sharePublicBeacon(
      L10n l, LocationCoordinator coordinator) async {
    // A public beacon shares a coarse point in the clear; use the sharer
    // directly with a one-shot position.
    final pos = await readPosition();
    final at = pos.position;
    if (at == null) {
      _showPositionFailure(l, pos.failure ?? PositionFailure.unknown);
      return;
    }
    final ev = await coordinator.sharer.broadcastPublicBeacon(
      geoPointFor(at), // coarse by default
      ttl: _effectiveTtl,
    );
    await coordinator.store.apply(ev);
    if (!mounted) return;
    Toast.show(context, l.t('location_shared'));
  }

  void _handleResult(L10n l, ShareResult res) {
    if (!mounted) return;
    if (res.failure != null) {
      _showPositionFailure(l, res.failure!);
      return;
    }
    if (!res.succeeded) {
      Toast.show(context, l.t('share_not_delivered'), urgent: true);
      return;
    }
    final msg = res.unreachable.isEmpty
        ? '${l.t('location_shared')} — ${_precision == _Precision.exact ? l.t('shared_as_exact') : l.t('shared_as_approx')}'
        : l.t('share_some_unreachable');
    HapticFeedback.mediumImpact();
    Toast.show(context, msg);
  }

  void _showPositionFailure(L10n l, PositionFailure f) {
    Toast.show(
        context,
        switch (f) {
          PositionFailure.serviceOff => l.t('loc_service_off'),
          PositionFailure.denied ||
          PositionFailure.deniedForever =>
            l.t('loc_denied'),
          PositionFailure.timeout => l.t('loc_timeout'),
          PositionFailure.unknown => l.t('loc_unknown'),
        },
        urgent: true);
  }

  Future<void> _stop(L10n l) async {
    setState(() => _busy = true);
    try {
      final coordinator =
          await ref.read(locationCoordinatorProvider.future);
      // Stop ALL of our shares (empty shareId) so the Stop control reliably
      // revokes whatever is active, not just the one started this session.
      await coordinator.stop();
      HapticFeedback.mediumImpact();
      if (mounted) {
        Toast.show(context, l.t('location_share_stopped'));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        bumpWorld(ref);
      }
    }
  }
}
