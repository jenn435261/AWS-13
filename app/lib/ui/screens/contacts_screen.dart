import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../components/common.dart';

/// Contacts: people / organizations / verified, swipeable tabs. Add contacts
/// by QR scan (with a manual-entry fallback), username, or phone (phone only
/// shown when online lookup exists). Shows and copies My Resilience ID.
class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final online = ref.watch(cloudBaseUrlProvider).isNotEmpty;
    final identity = ref.watch(identityProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.t('nav_contacts')),
          bottom: TabBar(
            tabs: [
              Tab(text: l.t('people')),
              Tab(text: l.t('organizations')),
              Tab(text: l.t('verified')),
            ],
          ),
        ),
        body: Column(
          children: [
            // My identity card — Resilience ID is copyable (tap or long-press).
            identity.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonBox(height: 72),
              ),
              error: (e, _) => const SizedBox.shrink(),
              data: (id) => Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('my_resilience_id'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      CopyableText(
                        value: id.resilienceId,
                        copiedMessage: l.t('copied'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Add-contact actions (primary = QR, with manual fallback).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: Text(l.t('scan_qr')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.qr_code_rounded),
                    label: Text(l.t('my_qr')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.alternate_email_rounded),
                    label: Text(l.t('add_by_username')),
                  ),
                  // Manual fallback is ALWAYS available.
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.keyboard_rounded),
                    label: Text(l.t('manual_entry')),
                  ),
                  if (online)
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.phone_rounded),
                      label: Text(l.t('add_by_phone')),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _emptyList(context, l, Icons.people_outline_rounded),
                  _emptyList(context, l, Icons.business_outlined),
                  _emptyList(context, l, Icons.verified_outlined),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyList(BuildContext context, L10n l, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(l.t('scan_qr'),
              style: TextStyle(
                  fontSize: 16, color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }
}
