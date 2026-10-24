import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../../state/derived_state.dart';
import '../components/trust_badges.dart';
import '../map/map_view.dart';
import '../theme/app_theme.dart';
import 'help_flow_screen.dart';
import 'resource_detail_screen.dart';

/// The default screen: map-first, with the single large primary action
/// (I NEED HELP / OFFER HELP) pinned at the bottom center.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resourcesAsync = ref.watch(rankedResourcesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _StatusBar(),
            Expanded(
              child: resourcesAsync.when(
                loading: () => const MapView(),
                error: (e, _) => const MapView(),
                data: (resources) => MapView(
                  markers: _markersFor(context, resources, ref),
                ),
              ),
            ),
            // The primary actions — map-first, pinned at the bottom, big.
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
              child: _PrimaryMapAction(),
            ),
          ],
        ),
      ),
    );
  }

  List<MapMarker> _markersFor(
      BuildContext context, List<ResourceView> resources, WidgetRef ref) {
    // Place markers schematically around the center for the fallback map.
    final markers = <MapMarker>[];
    for (var i = 0; i < resources.length && i < 12; i++) {
      final r = resources[i];
      final angle = (i / 12) * 6.28318;
      final radius = 0.18 + (i % 3) * 0.1;
      markers.add(MapMarker(
        id: r.resourceId,
        icon: iconForCategory(r.resource.category),
        color: r.trust.source.isVerifiedOrg
            ? AppTheme.verified
            : AppTheme.communityAccent,
        x: 0.5 + radius * _cos(angle) - 0.05,
        y: 0.5 + radius * _sin(angle) - 0.05,
        label: r.resource.title,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ResourceDetailScreen(resourceId: r.resourceId),
        )),
      ));
    }
    return markers;
  }
}

double _cos(double x) => _taylorCos(x);
double _sin(double x) => _taylorCos(x - 1.5707963);
double _taylorCos(double x) {
  // Normalize to [-pi, pi]
  while (x > 3.14159265) {
    x -= 6.28318530;
  }
  while (x < -3.14159265) {
    x += 6.28318530;
  }
  final x2 = x * x;
  return 1 - x2 / 2 + x2 * x2 / 24 - x2 * x2 * x2 / 720;
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
                builder: (_) => const HelpFlowScreen(isRequest: false),
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
