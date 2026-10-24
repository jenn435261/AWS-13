import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../gen/resilience/v1/event.pb.dart';
import '../../identity/identity_card.dart';
import '../../l10n/strings.dart';
import '../../location/position_service.dart';
import '../../logistics/mission.dart';
import '../components/location_field.dart';
import '../components/toast.dart';
import '../components/trust_badges.dart';
import '../theme/app_theme.dart';
import 'supply_editor_screen.dart';
import 'trusted_orgs_screen.dart';

/// Provider tools. A *provider* is an author the device's trust roots vouch for
/// (a trusted root, or someone a root certified). Providers can publish
/// verified supplies, issue emergency alerts and create missions; everyone else
/// sees why they cannot and how to become one. Gating here is a convenience:
/// every other device re-derives provider status from the signed certificate
/// chain, so a tampered client cannot fake the badge for anyone else.
class ProviderScreen extends ConsumerWidget {
  const ProviderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final verified = ref.watch(isVerifiedProviderProvider);
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(identityProvider).valueOrNull;
    const head = TextStyle(
        fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w700);
    const body = TextStyle(fontFamily: 'Roboto', fontSize: 16);

    return Scaffold(
      appBar: AppBar(title: Text(l.t('provider_tools'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: verified
                  ? AppTheme.verified.withValues(alpha: 0.12)
                  : scheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                          verified
                              ? Icons.verified_rounded
                              : Icons.person_outline_rounded,
                          color: verified ? AppTheme.verified : scheme.outline),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            verified
                                ? l.t('you_are_provider')
                                : l.t('you_are_community'),
                            style: head),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                        verified
                            ? l.t('provider_verified_explain')
                            : l.t('provider_unverified_explain'),
                        style: body),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!verified) ...[
              Text(l.t('how_to_become_provider'), style: head),
              const SizedBox(height: 8),
              for (final s in ['provider_step1', 'provider_step2', 'provider_step3'])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(l.t(s), style: body),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const TrustedOrgsScreen())),
                icon: const Icon(Icons.verified_outlined),
                label: Text(l.t('trusted_organizations')),
              ),
            ] else ...[
              Text(l.t('provider_actions'), style: head),
              const SizedBox(height: 4),
              _Action(
                icon: Icons.inventory_2_outlined,
                title: l.t('publish_verified_supply'),
                subtitle: l.t('publish_verified_supply_hint'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SupplyEditorScreen())),
              ),
              _Action(
                icon: Icons.campaign_outlined,
                title: l.t('post_alert'),
                subtitle: l.t('post_alert_hint'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AlertEditorScreen())),
              ),
              _Action(
                icon: Icons.local_shipping_outlined,
                title: l.t('create_mission'),
                subtitle: l.t('create_mission_hint'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const MissionEditorScreen())),
              ),
              if (me != null &&
                  ref
                      .watch(trustRootsProvider)
                      .isTrustedRoot(me.keys.signingPublicKey))
                _Action(
                  icon: Icons.badge_outlined,
                  title: l.t('issue_certificate'),
                  subtitle: l.t('issue_certificate_hint'),
                  onTap: () => _issueCert(context, ref),
                ),
              const SizedBox(height: 16),
              Text(l.t('my_alerts_missions'), style: head),
              const SizedBox(height: 4),
              const _MyBroadcasts(),
              const SizedBox(height: 16),
              Text(l.t('community_needs'), style: head),
              const SizedBox(height: 4),
              const _NeedsPanel(),
            ],
            const SizedBox(height: 24),
            Text(l.t('provider_limits'), style: head),
            const SizedBox(height: 6),
            Text(l.t('provider_limits_body'), style: body),
          ],
        ),
      ),
    );
  }

  /// Root-only: certify a saved contact as a member of this organization.
  Future<void> _issueCert(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final contacts = await ref.read(contactsProvider.future);
    if (!context.mounted) return;
    if (contacts.isEmpty) {
      Toast.show(context, l.t('no_contacts_for_org'));
      return;
    }
    final picked = await showModalBottomSheet<IdentityCard>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.t('issue_certificate'),
                style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
          for (final c in contacts)
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(c.displayName.isEmpty ? c.resilienceId : c.displayName),
              onTap: () => Navigator.pop(ctx, c),
            ),
        ]),
      ),
    );
    if (picked == null || !context.mounted) return;
    final me = await ref.read(identityProvider.future);
    final kp = await authorKeyPair(me);
    final now = DateTime.now().millisecondsSinceEpoch;
    final event = await ref.read(eventFactoryProvider).buildFromMessage(
          keyPair: kp,
          clock: ref.read(lamportClockProvider),
          type: EventType.EVENT_TYPE_ORG_CERTIFICATE,
          body: OrgCertificateBody(
            orgRootPubkey: me.keys.signingPublicKey,
            subjectPubkey: picked.signingPublicKey,
            orgName: me.displayName,
            facilityName: picked.displayName,
            provenance: ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG,
            validFromMs: Int64(now),
            validUntilMs: Int64(now + 365 * 24 * 3600 * 1000),
          ),
        );
    await ref.read(eventStoreProvider).apply(event);
    bumpWorld(ref);
    if (context.mounted) Toast.show(context, l.t('certificate_issued'));
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Action(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}

/// A row in the "my alerts & missions" panel. [alertId] is non-empty only for
/// an alert that is still active (so it can be recalled); empty otherwise.
class _Broadcast {
  final EventType type;
  final String label;
  final int atMs;

  /// The alert id, when this row is a live (recallable) alert.
  final String alertId;
  const _Broadcast(this.type, this.label, this.atMs, {this.alertId = ''});
}

/// Alerts and missions this device has published, read from the local log.
/// Uses the folded [WorldState] for alerts so a row is shown as "live" (and
/// recallable) only while the alert is actually active.
final _myBroadcastsProvider =
    FutureProvider.autoDispose<List<_Broadcast>>((ref) async {
  ref.watch(worldRevisionProvider);
  final me = await ref.watch(identityProvider.future);
  final world = await ref.watch(worldStateProvider.future);
  final all = await ref.watch(databaseProvider).eventDao.allEvents();

  // Which of my alert ids are currently live (not expired/recalled)?
  final liveAlertIds = <String>{
    for (final a in world.emergencyAlerts)
      if (_eq(a.author, me.keys.signingPublicKey)) a.alertId,
  };

  final out = <_Broadcast>[];
  final seenAlerts = <String>{};
  for (final e in all) {
    final mine =
        e.header.authorPubkey.length == me.keys.signingPublicKey.length &&
            _eq(e.header.authorPubkey, me.keys.signingPublicKey);
    if (!mine) continue;
    final t = e.header.type;
    try {
      if (t == EventType.EVENT_TYPE_EMERGENCY_ALERT) {
        final b = EmergencyAlertBody.fromBuffer(e.body);
        if (!seenAlerts.add(b.alertId)) continue; // one row per alert id
        out.add(_Broadcast(t, b.title, e.header.createdAtMs.toInt(),
            alertId: liveAlertIds.contains(b.alertId) ? b.alertId : ''));
      } else if (t == EventType.EVENT_TYPE_MISSION_CREATED) {
        final b = MissionBody.fromBuffer(e.body);
        out.add(_Broadcast(t, '#${b.missionId} · ${b.cargoDescription}',
            e.header.createdAtMs.toInt()));
      }
    } catch (_) {}
  }
  out.sort((a, b) => b.atMs.compareTo(a.atMs));
  return out;
});

bool _eq(List<int> a, List<int> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _MyBroadcasts extends ConsumerWidget {
  const _MyBroadcasts();

  /// Recalls a live alert by publishing a NEW EMERGENCY_ALERT with the SAME
  /// alert_id and `expires_ms` in the past. The fold (author-only) supersedes
  /// the original with this expired version, so it disappears from the banner.
  Future<void> _recall(
      BuildContext context, WidgetRef ref, L10n l, String alertId,
      String title) async {
    final me = await ref.read(identityProvider.future);
    final kp = await authorKeyPair(me);
    final store = ref.read(eventStoreProvider);
    final event = await ref.read(eventFactoryProvider).buildFromMessage(
          keyPair: kp,
          clock: store.clock,
          type: EventType.EVENT_TYPE_EMERGENCY_ALERT,
          body: EmergencyAlertBody(
            alertId: alertId,
            title: title,
            // Expire one minute in the past so the fold drops it immediately.
            expiresMs: Int64(
                DateTime.now().millisecondsSinceEpoch - 60 * 1000),
          ),
        );
    await store.apply(event);
    bumpWorld(ref);
    if (context.mounted) Toast.show(context, l.t('alert_recalled'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final rows = ref.watch(_myBroadcastsProvider).valueOrNull ?? const [];
    if (rows.isEmpty) {
      return Text(l.t('nothing_published'),
          style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              color: Theme.of(context).colorScheme.outline));
    }
    return Column(children: [
      for (final r in rows)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(r.type == EventType.EVENT_TYPE_EMERGENCY_ALERT
              ? Icons.campaign_outlined
              : Icons.local_shipping_outlined),
          title: Text(r.label),
          subtitle: Text(DateTime.fromMillisecondsSinceEpoch(r.atMs)
              .toLocal()
              .toString()
              .substring(0, 16)),
          trailing: r.alertId.isEmpty
              ? null
              : TextButton(
                  onPressed: () =>
                      _recall(context, ref, l, r.alertId, r.label),
                  child: Text(l.t('recall_alert')),
                ),
        ),
    ]);
  }
}

/// Aggregate community needs from the cloud (/v1/org/needs). Requires an org
/// token issued by the cloud operator; it is kept in memory only.
class _NeedsPanel extends ConsumerStatefulWidget {
  const _NeedsPanel();
  @override
  ConsumerState<_NeedsPanel> createState() => _NeedsPanelState();
}

class _NeedsPanelState extends ConsumerState<_NeedsPanel> {
  final _token = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, int>? _totals;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final l = L10n.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final base = ref.read(cloudBaseUrlProvider);
      final r = await http.get(Uri.parse('$base/v1/org/needs'), headers: {
        'X-Org-Token': _token.text.trim(),
        'X-Api-Key': ref.read(cloudApiKeyProvider),
      }).timeout(const Duration(seconds: 8));
      if (r.statusCode == 401) throw l.t('org_token_rejected');
      if (r.statusCode != 200) throw '${r.statusCode}';
      final cells = (jsonDecode(r.body)['cells'] as List? ?? []);
      final totals = <String, int>{};
      for (final c in cells.whereType<Map<String, dynamic>>()) {
        final cat = c['category'] as String? ?? '?';
        totals[cat] = (totals[cat] ?? 0) + ((c['count'] as num?)?.toInt() ?? 0);
      }
      if (mounted) setState(() => _totals = totals);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final outline = Theme.of(context).colorScheme.outline;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.t('community_needs_hint'),
          style: TextStyle(fontFamily: 'Roboto', fontSize: 16, color: outline)),
      const SizedBox(height: 8),
      TextField(
        controller: _token,
        obscureText: true,
        decoration: InputDecoration(labelText: l.t('org_token')),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy || _token.text.trim().isEmpty ? null : _load,
        icon: const Icon(Icons.cloud_download_outlined),
        label: Text(l.t('load_needs')),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      if (_totals != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _totals!.isEmpty
              ? Text(l.t('no_needs_reported'))
              : Column(children: [
                  for (final e in _totals!.entries)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.key.replaceFirst('RESOURCE_CATEGORY_', '')),
                        trailing: Text('${e.value}')),
                ]),
        ),
    ]);
  }
}

/// Verified providers only: broadcast an emergency alert to the map banner.
class AlertEditorScreen extends ConsumerStatefulWidget {
  const AlertEditorScreen({super.key});
  @override
  ConsumerState<AlertEditorScreen> createState() => _AlertEditorState();
}

class _AlertEditorState extends ConsumerState<AlertEditorScreen> {
  final _title = TextEditingController();
  final _detail = TextEditingController();
  Priority _priority = Priority.PRIORITY_HIGH;
  int _hours = 6;
  LatLng? _where;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = L10n.of(context);
    if (_title.text.trim().isEmpty) {
      setState(() => _error = l.t('alert_needs_title'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final me = await ref.read(identityProvider.future);
    final kp = await authorKeyPair(me);
    final event = await ref.read(eventFactoryProvider).buildFromMessage(
          keyPair: kp,
          clock: ref.read(lamportClockProvider),
          type: EventType.EVENT_TYPE_EMERGENCY_ALERT,
          body: EmergencyAlertBody(
            alertId: const Uuid().v4(),
            title: _title.text.trim(),
            detail: _detail.text.trim(),
            priority: _priority,
            area: _where == null ? null : geoPointFor(_where!),
            expiresMs: Int64(DateTime.now()
                .add(Duration(hours: _hours))
                .millisecondsSinceEpoch),
          ),
        );
    await ref.read(eventStoreProvider).apply(event);
    bumpWorld(ref);
    if (!mounted) return;
    Toast.show(context, l.t('alert_posted'));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('post_alert'))),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              TextField(
                  controller: _title,
                  decoration: InputDecoration(labelText: l.t('alert_title'))),
              const SizedBox(height: 12),
              TextField(
                  controller: _detail,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(labelText: l.t('alert_detail'))),
              const SizedBox(height: 16),
              Text(l.t('priority'),
                  style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 10, children: [
                for (final p in const [
                  (Priority.PRIORITY_NORMAL, 'priority_normal'),
                  (Priority.PRIORITY_HIGH, 'priority_high'),
                  (Priority.PRIORITY_CRITICAL, 'priority_critical'),
                ])
                  ChoiceChip(
                      label: Text(l.t(p.$2)),
                      selected: _priority == p.$1,
                      onSelected: (_) => setState(() => _priority = p.$1)),
              ]),
              const SizedBox(height: 16),
              Text(l.t('alert_expires'),
                  style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 10, children: [
                for (final h in const [1, 6, 24, 48])
                  ChoiceChip(
                      label: Text('$h h'),
                      selected: _hours == h,
                      onSelected: (_) => setState(() => _hours = h)),
              ]),
              const SizedBox(height: 16),
              LocationField(
                  value: _where, onChanged: (v) => setState(() => _where = v)),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _saving ? null : _send,
                icon: const Icon(Icons.campaign_rounded),
                label: Text(l.t('post_alert')),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Verified providers only: create a delivery mission (cargo, pickup,
/// destination). Carriers accept it from the Deliveries tab once sync delivers
/// the event to them.
class MissionEditorScreen extends ConsumerStatefulWidget {
  const MissionEditorScreen({super.key});
  @override
  ConsumerState<MissionEditorScreen> createState() => _MissionEditorState();
}

class _MissionEditorState extends ConsumerState<MissionEditorScreen> {
  final _cargo = TextEditingController();
  final _qty = TextEditingController();
  final _pickup = TextEditingController();
  final _dest = TextEditingController();
  ResourceCategory _category = ResourceCategory.RESOURCE_CATEGORY_WATER;
  Priority _priority = Priority.PRIORITY_NORMAL;
  LatLng? _pickupAt;
  LatLng? _destAt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _cargo.dispose();
    _qty.dispose();
    _pickup.dispose();
    _dest.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l = L10n.of(context);
    if (_cargo.text.trim().isEmpty ||
        _pickup.text.trim().isEmpty ||
        _dest.text.trim().isEmpty) {
      setState(() => _error = l.t('mission_needs_fields'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final me = await ref.read(identityProvider.future);
    final kp = await authorKeyPair(me);
    final event = await MissionEvents(factory: ref.read(eventFactoryProvider))
        .created(
      creatorKeyPair: kp,
      clock: ref.read(lamportClockProvider),
      missionId: const Uuid().v4().substring(0, 6).toUpperCase(),
      cargoCategory: _category,
      cargoDescription: _cargo.text.trim(),
      cargoQuantity: int.tryParse(_qty.text.trim()) ?? 0,
      pickupName: _pickup.text.trim(),
      pickupLocation: _pickupAt == null ? null : geoPointFor(_pickupAt!),
      destinationName: _dest.text.trim(),
      destinationLocation: _destAt == null ? null : geoPointFor(_destAt!),
      priority: _priority,
    );
    await ref.read(eventStoreProvider).apply(event);
    bumpWorld(ref);
    if (!mounted) return;
    Toast.show(context, l.t('mission_created'));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    const label = TextStyle(
        fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w600);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('create_mission'))),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text(l.t('supply_type'), style: label),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 8, children: [
                for (final c in const [
                  ResourceCategory.RESOURCE_CATEGORY_WATER,
                  ResourceCategory.RESOURCE_CATEGORY_FOOD,
                  ResourceCategory.RESOURCE_CATEGORY_MEDICINE,
                  ResourceCategory.RESOURCE_CATEGORY_POWER,
                  ResourceCategory.RESOURCE_CATEGORY_OTHER,
                ])
                  ChoiceChip(
                      avatar: Icon(iconForCategory(c), size: 20),
                      label: Text(categoryLabel(l, c)),
                      selected: _category == c,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _category = c)),
              ]),
              const SizedBox(height: 16),
              TextField(
                  controller: _cargo,
                  decoration: InputDecoration(
                      labelText: l.t('cargo'), hintText: l.t('cargo_hint'))),
              const SizedBox(height: 12),
              TextField(
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.t('number'))),
              const SizedBox(height: 16),
              TextField(
                  controller: _pickup,
                  decoration: InputDecoration(labelText: l.t('pickup'))),
              LocationField(
                  value: _pickupAt,
                  onChanged: (v) => setState(() => _pickupAt = v)),
              const SizedBox(height: 16),
              TextField(
                  controller: _dest,
                  decoration: InputDecoration(labelText: l.t('destination'))),
              LocationField(
                  value: _destAt,
                  onChanged: (v) => setState(() => _destAt = v)),
              const SizedBox(height: 16),
              Text(l.t('priority'), style: label),
              const SizedBox(height: 8),
              Wrap(spacing: 10, children: [
                for (final p in const [
                  (Priority.PRIORITY_NORMAL, 'priority_normal'),
                  (Priority.PRIORITY_HIGH, 'priority_high'),
                  (Priority.PRIORITY_CRITICAL, 'priority_critical'),
                ])
                  ChoiceChip(
                      label: Text(l.t(p.$2)),
                      selected: _priority == p.$1,
                      onSelected: (_) => setState(() => _priority = p.$1)),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _saving ? null : _create,
                icon: const Icon(Icons.local_shipping_rounded),
                label: Text(l.t('create_mission')),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
