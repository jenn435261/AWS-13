import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../alerts/alert_providers.dart';
import '../../l10n/strings.dart';
import '../screens/prepare_now_screen.dart';

/// A dismissible in-app banner that appears when the alert poller detects a new
/// SEVERE official-feed alert. It offers a "Prepare now" button that opens the
/// region-download flow. It is HONEST: it only shows for an alert the server
/// actually returned (verified feed event), and it never implies an OS
/// notification was shown when it was not (the OS notification is a separate,
/// best-effort path; the banner always covers the open-app case).
class AlertBanner extends ConsumerWidget {
  const AlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alertStateProvider);
    final alert = state.pendingSevere;
    if (alert == null) return const SizedBox.shrink();
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l.t('severe_alert')}: ${alert.title}',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    if (alert.detail.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _plainDetail(alert.detail),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => PrepareNowScreen(alert: alert),
                            ));
                          },
                          icon: const Icon(Icons.download_for_offline_rounded),
                          label: Text(l.t('prepare_now')),
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.read(alertPollerProvider)?.dismissPending(),
                          child: Text(l.t('dismiss')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Strips the leading `[official_feed:...]` marker line from the detail for
  /// display (the marker is machine metadata, not user-facing text).
  static String _plainDetail(String detail) {
    if (detail.startsWith('[official_feed:')) {
      final nl = detail.indexOf('\n');
      return nl >= 0 ? detail.substring(nl + 1).trim() : '';
    }
    return detail;
  }
}
