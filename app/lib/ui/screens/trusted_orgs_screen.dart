import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../components/common.dart';
import '../theme/app_theme.dart';

/// The organization roots this device trusts. Roots are never learned from the
/// event log (anyone could mint a badge that way); they are installed
/// out-of-band, e.g. from a readiness package. Until one is installed this
/// screen says so plainly instead of showing placeholder organizations.
class TrustedOrgsScreen extends ConsumerWidget {
  const TrustedOrgsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final roots = ref.watch(trustRootsProvider).roots;
    final outline = Theme.of(context).colorScheme.outline;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('trusted_organizations'))),
      body: SafeArea(
        child: roots.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_outlined, size: 48, color: outline),
                      const SizedBox(height: 12),
                      Text(l.t('no_trusted_orgs'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 18,
                              color: outline)),
                      const SizedBox(height: 6),
                      Text(l.t('no_trusted_hint'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              color: outline)),
                    ],
                  ),
                ),
              )
            : ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(l.t('trusted_roots'),
                        style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                  for (final r in roots)
                    ListTile(
                      leading: const Icon(Icons.verified_rounded,
                          color: AppTheme.verified),
                      title: CopyableText(
                        value: base64Url.encode(r).replaceAll('=', ''),
                        copiedMessage: l.t('copied'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
