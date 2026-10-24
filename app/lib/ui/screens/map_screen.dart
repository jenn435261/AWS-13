import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../identity/identity_card.dart';
import '../../l10n/strings.dart';
import '../../location/location_providers.dart';
import '../../location/location_state.dart';
import '../../location/position_service.dart';
import '../../state/derived_state.dart';
import '../../sync/connectivity.dart';
import '../../sync/sync_providers.dart';
import '../components/toast.dart';
import '../components/trust_badges.dart';
import '../components/translate_panel.dart';
import '../map/map_view.dart';
import '../theme/app_theme.dart';
import 'help_flow_screen.dart';
import 'resource_detail_screen.dart';
import 'supply_editor_screen.dart';

/// The default screen: a real map with everything that has a location on it,
/// and the two large primary actions (I NEED HELP / OFFER HELP) at the bottom.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  Future<void> _locate(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    // Caches a successful read as the new last-good fix (so it persists and the
    // map can recentre on it later), and updates the live "you are here" dot.
    final r = await autoResolvePosition(ref);
    if (r.position != null) return;
    if (!context.mounted) return;
    Toast.show(
        context,
        switch (r.failure) {
          PositionFailure.serviceOff => l.t('loc_service_off'),
          PositionFailure.denied ||
          PositionFailure.deniedForever =>
            l.t('loc_denied'),
          PositionFailure.timeout => l.t('loc_timeout'),
          _ => l.t('loc_unknown'),
        },
        urgent: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final world = ref.watch(worldStateProvider);
    final me = ref.watch(myPositionProvider);
    final lastFix = ref.watch(lastKnownFixProvider).valueOrNull;
    // Centre: a live fix wins; otherwise the cached last-known fix.
    final centre = me ?? lastFix?.position;

    final markers = <MapMarker>[];
    var unplaced = 0;
    final w = world.valueOrNull;
    if (w != null) {
      // mapResources() already excludes withdrawn and expired supplies
      // (auto-hide past available_until_ms via the fold's injected clock).
      for (final r in w.mapResources()) {
        final pos = latLngOf(r.resource.hasLocation() ? r.resource.location : null);
        if (pos == null) {
          unplaced++;
          continue;
        }
        markers.add(MapMarker(
          id: r.resourceId,
          icon: iconForCategory(r.resource.category),
          color: r.trust.source.isVerifiedOrg
              ? AppTheme.verified
              : AppTheme.communityAccent,
          position: pos,
          label: r.resource.title,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ResourceDetailScreen(resourceId: r.resourceId),
          )),
        ));
      }
      for (final q in w.helpRequests) {
        if (q.closed) continue; // closed/cancelled requests leave the map
        final pos = latLngOf(q.body.hasLocation() ? q.body.location : null);
        if (pos == null) {
          unplaced++;
          continue;
        }
        markers.add(MapMarker(
          id: 'req-${q.requestId}',
          icon: Icons.sos_rounded,
          color: AppTheme.urgent,
          position: pos,
          label: q.body.freeform.isEmpty ? l.t('i_need_help') : q.body.freeform,
          onTap: () => _requestSheet(context, l, q),
        ));
      }
    }

    // People sharing their location WITH this device (decrypted locally).
    final incoming =
        ref.watch(incomingSharesProvider).valueOrNull ?? const <IncomingShare>[];
    final contacts = ref.watch(contactsProvider).valueOrNull;
    for (final s in incoming) {
      final pos = latLngOf(s.point);
      if (pos == null) {
        unplaced++;
        continue;
      }
      final name = _sharerName(contacts, s.sharerPubkey);
      markers.add(MapMarker(
        id: 'share-${s.shareId}',
        icon: Icons.person_pin_circle_rounded,
        color: AppTheme.sharing,
        position: pos,
        label: name,
        onTap: () => _shareSheet(context, l, s, name),
      ));
    }

    final alerts = w?.emergencyAlerts
            .where((a) =>
                a.body.expiresMs == 0 ||
                a.body.expiresMs.toInt() >
                    DateTime.now().millisecondsSinceEpoch)
            .toList() ??
        const <EmergencyAlertView>[];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _StatusBar(),
            if (w != null) _AiSummaryBar(world: w),
            for (final a in alerts) _AlertBanner(alert: a),
            Expanded(
              child: Stack(
                children: [
                  MapView(
                    markers: markers,
                    me: me,
                    center: centre,
                    onLocateMe: () => _locate(context, ref),
                    pmtilesUrl: ref.watch(nodePmtilesUrlProvider).valueOrNull,
                  ),
                  // Honest "last known, <age>" chip when we have no live fix but
                  // do have a cached one — never presented as a live GPS fix.
                  if (me == null && lastFix != null)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Chip(
                        avatar: const Icon(Icons.history_rounded, size: 18),
                        label: Text(
                            '${l.t('loc_last_known')}, ${lastFix.ageLabel(DateTime.now().toUtc().millisecondsSinceEpoch)}'),
                      ),
                    ),
                  if (unplaced > 0)
                    Positioned(
                      top: 8,
                      left: 12,
                      child: Chip(
                        avatar: const Icon(Icons.location_off_outlined, size: 18),
                        label: Text('$unplaced ${l.t('without_location')}'),
                      ),
                    ),
                  if (incoming.isNotEmpty)
                    Positioned(
                      top: unplaced > 0 ? 52 : 8,
                      left: 12,
                      child: ActionChip(
                        avatar: const Icon(Icons.person_pin_circle_rounded,
                            size: 18, color: AppTheme.sharing),
                        label: Text(
                            '${incoming.length} ${l.t('sharing_count')}'),
                        onPressed: () =>
                            _sharingListSheet(context, l, incoming, contacts),
                      ),
                    ),
                ],
              ),
            ),
            // Refresh row: re-fold + sync + recentre, with the real last sync
            // time. Kept above the big primary actions (bottom-anchored).
            const _RefreshBar(),
            // The primary actions — pinned at the bottom, big.
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
              child: _PrimaryMapAction(),
            ),
          ],
        ),
      ),
    );
  }

  /// A display name for a sharer: their saved contact name, else a short id.
  static String _sharerName(
      List<IdentityCard>? contacts, List<int> pubkey) {
    if (contacts != null) {
      for (final c in contacts) {
        if (_bytesEqual(c.signingPublicKey, pubkey)) return c.displayName;
      }
    }
    final hex = _hex(pubkey);
    return hex.length <= 10 ? hex : '${hex.substring(0, 10)}…';
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _hex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  void _shareSheet(
      BuildContext context, L10n l, IncomingShare s, String name) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.person_pin_circle_rounded,
                    color: AppTheme.sharing),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                '${l.t('expires_in')} ${_fmtRemaining(s.freshness)}',
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 16),
              ),
              if (s.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(s.note,
                    style:
                        const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _sharingListSheet(
      BuildContext context, L10n l, List<IncomingShare> shares,
      List<IdentityCard>? contacts) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.t('people_sharing_with_you'),
                  style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (shares.isEmpty)
                Text(l.t('no_one_sharing'),
                    style:
                        const TextStyle(fontFamily: 'Roboto', fontSize: 16))
              else
                for (final s in shares)
                  ListTile(
                    leading: const Icon(Icons.person_pin_circle_rounded,
                        color: AppTheme.sharing),
                    title: Text(_sharerName(contacts, s.sharerPubkey),
                        style: const TextStyle(
                            fontFamily: 'Roboto', fontSize: 16)),
                    subtitle: Text(
                        '${l.t('share_expires_label')} ${_fmtRemaining(s.freshness)}'
                        '${s.note.isEmpty ? '' : ' · ${s.note}'}',
                        style: const TextStyle(
                            fontFamily: 'Roboto', fontSize: 14)),
                    contentPadding: EdgeInsets.zero,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtRemaining(Duration left) {
    if (left.isNegative || left == Duration.zero) return '0m';
    final m = left.inMinutes;
    if (m >= 1440) return '${m ~/ 1440}d';
    return m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '${m}m';
  }

  void _requestSheet(BuildContext context, L10n l, HelpRequestView q) {
    final cats = q.body.categories.map((c) => categoryLabel(l, c)).join(', ');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.t('i_need_help'),
                  style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(cats.isEmpty ? '—' : cats,
                  style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
              if (q.body.freeform.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(q.body.freeform,
                    style:
                        const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
                TranslatePanel(text: q.body.freeform),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final EmergencyAlertView alert;
  const _AlertBanner({required this.alert});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.urgent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            alert.body.detail.isEmpty
                ? alert.body.title
                : '${alert.body.title} — ${alert.body.detail}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

/// Builds the plain-text lines that feed the AI summarizer: open requests,
/// available supplies, and active alerts, newest-relevant first. No names, no
/// exact coordinates — just the public titles/notes the fold already exposes.
List<String> worldSummaryItems(WorldState w, L10n l) {
  final items = <String>[];
  for (final a in w.emergencyAlerts) {
    final detail = a.body.detail.isEmpty ? '' : ': ${a.body.detail}';
    items.add('${l.t('alert_title')}: ${a.body.title}$detail');
  }
  for (final q in w.helpRequests) {
    if (q.closed) continue;
    final cats = q.body.categories.map((c) => categoryLabel(l, c)).join(', ');
    final text = q.body.freeform.isNotEmpty ? q.body.freeform : cats;
    if (text.isNotEmpty) items.add('${l.t('i_need_help')}: $text');
  }
  for (final r in w.mapResources()) {
    if (r.withdrawn) continue;
    items.add('${l.t('offer_help')}: ${r.resource.title}');
  }
  return items;
}

/// A tappable "AI summary" bar on the home map. Tapping it computes a short
/// summary of the current world state via the AI assist (cloud Bedrock, with
/// the deterministic rules fallback) and shows it in a sheet with an honest
/// degraded indicator.
class _AiSummaryBar extends ConsumerWidget {
  const _AiSummaryBar({required this.world});
  final WorldState world;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => _showSummary(context, ref, l),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.t('ai_summary'),
                    style: const TextStyle(fontSize: 16)),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSummary(
      BuildContext context, WidgetRef ref, L10n l) async {
    final items = worldSummaryItems(world, l);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SummarySheet(items: items),
    );
  }
}

/// Computes and displays the AI summary. Kept stateful so the spinner, result,
/// and degraded chip reflect the real response.
class _SummarySheet extends ConsumerStatefulWidget {
  const _SummarySheet({required this.items});
  final List<String> items;

  @override
  ConsumerState<_SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends ConsumerState<_SummarySheet> {
  String? _summary;
  bool _degraded = false;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    if (widget.items.isEmpty) {
      setState(() {
        _busy = false;
        _summary = '';
      });
      return;
    }
    final ai = ref.read(aiAssistProvider);
    // The result's degraded flag is authoritative: it is true when the rules
    // fallback produced the summary (offline or cloud unreachable), false only
    // for a live cloud answer. We never imply a live AI summary otherwise.
    final result = await ai.summarize(widget.items);
    if (!mounted) return;
    setState(() {
      _summary = result.text;
      _degraded = result.degraded;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Text(l.t('ai_summary'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (!_busy && _degraded && (_summary ?? '').isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l.t('ai_degraded'),
                        style: TextStyle(
                            fontSize: 16,
                            color: scheme.onTertiaryContainer)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_busy)
              Row(children: [
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text(l.t('summarizing'),
                    style: const TextStyle(fontSize: 16)),
              ])
            else
              Text(
                (_summary ?? '').isEmpty ? l.t('no_summary') : _summary!,
                style: const TextStyle(fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}

/// The live connectivity banner. Driven by [connectivityProvider] (real
/// reachability from the sync client plus browser online/offline events), so it
/// flips without a reload and never claims a connection that is not wired.
class _StatusBar extends ConsumerWidget {
  const _StatusBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final conn = ref.watch(connectivityProvider);
    final sync = ref.watch(syncStatusProvider);

    final (IconData icon, Color color) = switch (conn) {
      Connectivity.online => (Icons.cloud_done_rounded, AppTheme.verified),
      Connectivity.nodeConnected => (Icons.lan_rounded, AppTheme.verified),
      Connectivity.cloudUnreachable => (
          Icons.cloud_off_rounded,
          AppTheme.urgent
        ),
      Connectivity.offline => (Icons.cloud_off_rounded, scheme.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: scheme.surfaceContainerHigh,
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(l.t(connectivityLabelKey(conn)),
                style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
          if (sync.syncing) ...[
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
          ],
          if (sync.lastSyncedMs != null)
            Text(
              '${l.t('last_sync')} ${_syncAge(l, sync.lastSyncedMs!)}',
              style: TextStyle(
                  fontFamily: 'Roboto', fontSize: 16, color: scheme.outline),
            ),
        ],
      ),
    );
  }

  static String _syncAge(L10n l, int ms) {
    final d = DateTime.now().millisecondsSinceEpoch - ms;
    if (d < 60000) return l.t('time_just_now');
    final m = d ~/ 60000;
    if (m < 60) return l.t('time_minutes_ago').replaceAll('{n}', '$m');
    final h = m ~/ 60;
    if (h < 24) return l.t('time_hours_ago').replaceAll('{n}', '$h');
    return l.t('time_days_ago').replaceAll('{n}', '${h ~/ 24}');
  }
}

/// A full-width refresh control (>=48px) that re-folds local state, triggers a
/// sync when reachable, recentres on the last known position, and shows the
/// real last-refreshed time from the sync status.
class _RefreshBar extends ConsumerStatefulWidget {
  const _RefreshBar();
  @override
  ConsumerState<_RefreshBar> createState() => _RefreshBarState();
}

class _RefreshBarState extends ConsumerState<_RefreshBar> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      bumpWorld(ref);
      final conn = ref.read(connectivityProvider);
      if (conn != Connectivity.offline) {
        await ref.read(syncCoordinatorProvider).syncNow();
      }
      final me = ref.read(myPositionProvider);
      if (me == null) {
        final fix = await ref.read(lastKnownFixProvider.future);
        if (fix != null) {
          ref.read(myPositionProvider.notifier).state = fix.position;
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final sync = ref.watch(syncStatusProvider);
    final lastMs = sync.lastSyncedMs;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : _run,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh_rounded),
          label: Text(
            _busy
                ? l.t('map_refreshing')
                : lastMs == null
                    ? l.t('map_refresh')
                    : '${l.t('map_refresh')} · ${l.t('last_refreshed')} ${_ago(l, lastMs)}',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  static String _ago(L10n l, int ms) {
    final d = DateTime.now().millisecondsSinceEpoch - ms;
    if (d < 60000) return l.t('time_just_now');
    final m = d ~/ 60000;
    if (m < 60) return l.t('time_minutes_ago').replaceAll('{n}', '$m');
    final h = m ~/ 60;
    if (h < 24) return l.t('time_hours_ago').replaceAll('{n}', '$h');
    return l.t('time_days_ago').replaceAll('{n}', '${h ~/ 24}');
  }
}

class _PrimaryMapAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _BigAction(
              label: l.t('i_need_help'),
              icon: Icons.sos_rounded,
              urgent: true,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const HelpFlowScreen(isRequest: true),
              )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BigAction(
              label: l.t('offer_help'),
              icon: Icons.volunteer_activism_rounded,
              urgent: false,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SupplyEditorScreen(),
              )),
            ),
          ),
        ],
      ),
    );
  }
}

/// A large two-line-safe action button: icon on top, label below, centered.
/// Sized so the primary emergency actions are big, legible, and never clip.
class _BigAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool urgent;
  final VoidCallback onTap;
  const _BigAction({
    required this.label,
    required this.icon,
    required this.urgent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = urgent ? AppTheme.urgent : scheme.primary;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          child: Container(
            height: 92,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 30),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(fontFamily: 'Roboto',
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
