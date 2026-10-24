import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../gen/resilience/v1/event.pb.dart';
import '../../l10n/strings.dart';
import '../components/common.dart';
import '../components/toast.dart';
import '../components/translate_panel.dart';
import '../components/trust_badges.dart';

/// Resource detail: shows the three trust dimensions and lets the user
/// Confirm / Dispute / mark Useful (each emits a signed observation event).
class ResourceDetailScreen extends ConsumerWidget {
  final String resourceId;
  const ResourceDetailScreen({super.key, required this.resourceId});

  Future<void> _observe(
    BuildContext context,
    WidgetRef ref,
    ObservationBody_Kind kind,
    String confirmation,
  ) async {
    final id = await ref.read(identityProvider.future);
    final kp = await authorKeyPair(id);
    final store = ref.read(eventStoreProvider);
    final factory = ref.read(eventFactoryProvider);
    final body = ObservationBody(resourceId: resourceId, kind: kind);
    final event = await factory.buildFromMessage(
      keyPair: kp,
      clock: store.clock,
      type: EventType.EVENT_TYPE_RESOURCE_OBSERVED,
      body: body,
    );
    await store.apply(event);
    bumpWorld(ref);
    if (context.mounted) {
      HapticFeedback.mediumImpact();
      Toast.show(context, confirmation);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final world = ref.watch(worldStateProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.t('community_resource'))),
      body: world.when(
        loading: () => const SkeletonList(),
        error: (e, _) => Center(child: Text('$e')),
        data: (w) {
          final r = w.resources[resourceId];
          if (r == null) {
            return Center(child: Text(l.t('loading')));
          }
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Icon(iconForCategory(r.resource.category), size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(r.resource.title,
                          style: const TextStyle(fontFamily: 'Roboto', 
                              fontSize: 22, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                if (r.withdrawn)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('(withdrawn)',
                        style: TextStyle(fontFamily: 'Roboto', 
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 20),
                // The three trust dimensions, never a single score.
                TrustProfileView(profile: r.trust),
                if (r.inventory != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Available: ${r.availableQuantity ?? r.inventory!.quantity} ${r.inventory!.unit}',
                    style: const TextStyle(fontFamily: 'Roboto', 
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
                if (r.resource.notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(r.resource.notes,
                      style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
                  // Translate the free-text note (original stays visible).
                  TranslatePanel(text: r.resource.notes),
                ],
                const SizedBox(height: 28),
                // Community confirmation actions.
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _observe(
                            context,
                            ref,
                            ObservationBody_Kind.KIND_CONFIRMED,
                            l.t('confirm')),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: Text(l.t('confirm')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _observe(
                            context,
                            ref,
                            ObservationBody_Kind.KIND_DISPUTED,
                            l.t('dispute')),
                        icon: const Icon(Icons.report_problem_outlined),
                        label: Text(l.t('dispute')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _observe(context, ref,
                      ObservationBody_Kind.KIND_USEFUL, l.t('useful')),
                  icon: const Icon(Icons.thumb_up_outlined),
                  label: Text(l.t('useful')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
