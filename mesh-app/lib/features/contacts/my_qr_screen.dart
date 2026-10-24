import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/labels.dart';
import '../../models/mission.dart';
import '../../state/app_scope.dart';

/// A large QR code on a white card, readable in any theme or light.
class QrCard extends StatelessWidget {
  const QrCard({super.key, required this.data, required this.label});

  final String data;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
        ),
        child: QrImageView(
          data: data,
          size: 260,
          backgroundColor: Colors.white,
          semanticsLabel: label,
        ),
      ),
    );
  }
}

/// This phone's Resilience ID, to show to someone in person (Spec 12).
class MyQrScreen extends StatelessWidget {
  const MyQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final identity = scope.repository.identity;

    return Scaffold(
      appBar: AppBar(title: Text(l.myQrTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            scope.auth.me.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          QrCard(data: identity.qrPayload(scope.auth.me.name), label: l.myQrTitle),
          const SizedBox(height: 20),
          Text(l.resilienceId, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          SelectableText(
            identity.displayId,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(l.myQrHint, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// The package QR for pickup, handoff and delivery (Spec sections 24 to 27).
/// It carries identifiers and a signature, never addresses or contents.
class PackageCodeScreen extends StatelessWidget {
  const PackageCodeScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ValueListenableBuilder<List<Mission>>(
      valueListenable: scope.repository.missions,
      builder: (context, missions, _) {
        final m = missions.where((m) => m.id == id).firstOrNull;
        if (m == null) {
          return Scaffold(appBar: AppBar(), body: Center(child: Text(l.requestNotFound)));
        }
        final signature = scope.repository.events.value
            .where((e) => e.subject == id)
            .map((e) => e.signature)
            .firstOrNull;
        final payload = Uri(
          scheme: 'resilience',
          host: 'package',
          queryParameters: {
            'id': m.packageId,
            'mission': m.id,
            'by': scope.repository.identity.resilienceId,
            if (signature != null) 'sig': signature.substring(0, 32),
          },
        ).toString();

        return Scaffold(
          appBar: AppBar(title: Text(l.packageLabel(m.packageId))),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(l.missionTitle(m.id), textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              QrCard(data: payload, label: l.packageCode),
              const SizedBox(height: 20),
              Text(l.packageQrHint, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => context.pop(), child: Text(l.close)),
            ],
          ),
        );
      },
    );
  }
}
