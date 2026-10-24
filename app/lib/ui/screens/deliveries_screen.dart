import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../identity/identity_card.dart';
import '../../l10n/strings.dart';
import '../../logistics/mission.dart';
import '../components/toast.dart';
import '../theme/app_theme.dart';

/// Deliveries (conditional tab): operational buckets for providers and
/// carriers (spec §22). A provider sees every mission and can assign a carrier
/// (emitting `MISSION_MATCHED`); a carrier accepts a mission (emitting
/// `MISSION_ACCEPTED`). Missions are folded from the local log via
/// [missionsProvider], which ignores a create/assign from a non-verified key.
class DeliveriesScreen extends ConsumerWidget {
  const DeliveriesScreen({super.key});

  static final _order = <MissionBucket>[
    MissionBucket.assigned,
    MissionBucket.available,
    MissionBucket.inTransit,
    MissionBucket.awaitingHandoff,
    MissionBucket.completed,
  ];

  String _bucketLabel(L10n l, MissionBucket b) {
    switch (b) {
      case MissionBucket.assigned:
        return l.t('bucket_assigned');
      case MissionBucket.available:
        return l.t('bucket_available');
      case MissionBucket.inTransit:
        return l.t('bucket_in_transit');
      case MissionBucket.awaitingHandoff:
        return l.t('bucket_awaiting_handoff');
      case MissionBucket.completed:
        return l.t('bucket_completed');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final missionsAsync = ref.watch(missionsProvider);
    final verified = ref.watch(isVerifiedProviderProvider);

    return DefaultTabController(
      length: _order.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.t('nav_deliveries')),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final b in _order) Tab(text: _bucketLabel(l, b))],
          ),
        ),
        body: missionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(l.t('deliveries_error'),
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
          ),
          data: (missions) => TabBarView(
            children: [
              for (final b in _order)
                _BucketList(
                  bucket: b,
                  label: _bucketLabel(l, b),
                  missions:
                      missions.where((m) => m.bucket == b).toList(),
                  verified: verified,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BucketList extends ConsumerWidget {
  final MissionBucket bucket;
  final String label;
  final List<MissionView> missions;
  final bool verified;
  const _BucketList({
    required this.bucket,
    required this.label,
    required this.missions,
    required this.verified,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    if (missions.isEmpty) {
      return Center(
        child: Text(l.t('no_missions_in_bucket'),
            style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                color: Theme.of(context).colorScheme.outline)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: missions.length,
      separatorBuilder: (_, i) => const Divider(height: 1),
      itemBuilder: (_, i) =>
          _MissionTile(mission: missions[i], verified: verified),
    );
  }
}

class _MissionTile extends ConsumerWidget {
  final MissionView mission;
  final bool verified;
  const _MissionTile({required this.mission, required this.verified});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final subtitle = <String>[
      if (mission.cargoDescription.isNotEmpty) mission.cargoDescription,
      '${mission.pickupName} → ${mission.destinationName}',
    ].join(' · ');

    // A provider may assign an unaccepted mission; a carrier may accept an
    // available (unaccepted) mission. Both are offered honestly only when the
    // action is possible.
    final canAssign = verified && mission.carrier == null;
    final canAccept = mission.carrier == null;

    return ListTile(
      isThreeLine: true,
      leading: const Icon(Icons.local_shipping_outlined),
      title: Text('#${mission.missionId}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 4),
          Text(
            mission.carrier == null
                ? l.t('mission_unassigned')
                : l.t('mission_has_carrier'),
            style: TextStyle(
                color: mission.carrier == null
                    ? AppTheme.communityAccent
                    : AppTheme.verified,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
      trailing: Wrap(
        spacing: 6,
        children: [
          if (canAssign)
            TextButton(
              onPressed: () => _assign(context, ref, l),
              child: Text(l.t('assign_carrier')),
            ),
          if (canAccept)
            FilledButton(
              onPressed: () => _accept(context, ref, l),
              child: Text(l.t('accept_mission')),
            ),
        ],
      ),
    );
  }

  /// Carrier accepts the mission, emitting a `MISSION_ACCEPTED` for its own key.
  Future<void> _accept(BuildContext context, WidgetRef ref, L10n l) async {
    final id = await ref.read(identityProvider.future);
    final kp = await authorKeyPair(id);
    final store = ref.read(eventStoreProvider);
    final event = await MissionEvents(factory: ref.read(eventFactoryProvider))
        .accepted(
      carrierKeyPair: kp,
      clock: store.clock,
      missionId: mission.missionId,
    );
    await store.apply(event);
    bumpWorld(ref);
    if (context.mounted) Toast.show(context, l.t('mission_accepted_toast'));
  }

  /// Provider assigns the mission to a named carrier chosen from contacts,
  /// emitting a `MISSION_MATCHED`. The fold honors this only for a verified
  /// provider; a non-provider's assignment is ignored.
  Future<void> _assign(BuildContext context, WidgetRef ref, L10n l) async {
    final contacts = await ref.read(contactsProvider.future);
    if (!context.mounted) return;
    if (contacts.isEmpty) {
      Toast.show(context, l.t('no_contacts_for_assign'));
      return;
    }
    final picked = await showModalBottomSheet<IdentityCard>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.t('assign_carrier'),
                style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
          for (final c in contacts)
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(
                  c.displayName.isEmpty ? c.resilienceId : c.displayName),
              onTap: () => Navigator.pop(ctx, c),
            ),
        ]),
      ),
    );
    if (picked == null || !context.mounted) return;
    final id = await ref.read(identityProvider.future);
    final kp = await authorKeyPair(id);
    final store = ref.read(eventStoreProvider);
    final event = await MissionEvents(factory: ref.read(eventFactoryProvider))
        .matched(
      matcherKeyPair: kp,
      clock: store.clock,
      missionId: mission.missionId,
      requestId: '',
      offerId: '',
    );
    await store.apply(event);
    bumpWorld(ref);
    if (context.mounted) {
      Toast.show(context, l.t('mission_assigned_toast'));
    }
  }
}
