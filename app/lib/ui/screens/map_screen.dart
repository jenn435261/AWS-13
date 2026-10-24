import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../../location/position_service.dart';
import '../../state/derived_state.dart';
import '../components/toast.dart';
import '../components/trust_badges.dart';
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
    final r = await readPosition();
    if (r.position != null) {
      ref.read(myPositionProvider.notifier).state = r.position;
      return;
    }
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

    final markers = <MapMarker>[];
    var unplaced = 0;
    final w = world.valueOrNull;
    if (w != null) {
      for (final r in w.rankedResources()) {
        if (r.withdrawn) continue;
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
            for (final a in alerts) _AlertBanner(alert: a),
            Expanded(
              child: Stack(
                children: [
                  MapView(
                    markers: markers,
                    me: me,
                    onLocateMe: () => _locate(context, ref),
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
                ],
              ),
            ),
            // The primary actions — pinned at the bottom, big.
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
              child: _PrimaryMapAction(),
            ),
          ],
        ),
      ),
    );
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

class _StatusBar extends ConsumerWidget {
  const _StatusBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final online = ref.watch(cloudBaseUrlProvider).isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: scheme.surfaceContainerHigh,
      child: Row(
        children: [
          Icon(online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              size: 22,
              color: online ? AppTheme.verified : scheme.outline),
          const SizedBox(width: 8),
          Text(online ? l.t('online') : l.t('offline'),
              style:
                  const TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.check_circle_rounded,
              size: 20, color: AppTheme.verified),
          const SizedBox(width: 6),
          Text(l.t('ready'), style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
        ],
      ),
    );
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
