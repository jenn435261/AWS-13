import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/labels.dart';
import '../../models/mission.dart';
import '../../state/app_scope.dart';
import '../../state/identity.dart';
import '../../ui/feedback.dart';

/// Tests turn the camera off; there is no camera to start.
bool scannerCameraEnabled = true;

/// Scans a contact's QR code, or a package code when [missionId] is set.
/// Typing it in is always offered as the manual fallback.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.missionId});

  final String? missionId;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _id = TextEditingController();
  final _name = TextEditingController();
  bool _done = false;
  String? _error;

  bool get _forPackage => widget.missionId != null;

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    super.dispose();
  }

  Mission? get _mission => AppScope.of(context)
      .repository
      .missions
      .value
      .where((m) => m.id == widget.missionId)
      .firstOrNull;

  void _onScan(BarcodeCapture capture) {
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null || _done) return;
    if (_forPackage) {
      final uri = Uri.tryParse(raw);
      _checkPackage(uri?.host == 'package' ? uri!.queryParameters['id'] ?? '' : raw);
    } else {
      final contact = parseContactQr(raw);
      if (contact == null) {
        setState(() => _error = AppLocalizations.of(context).invalidId);
      } else {
        _addContact(contact.id, contact.name);
      }
    }
  }

  Future<void> _addContact(String id, String name) async {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    _done = true;
    final contact = await scope.repository.addContact(id, name);
    scope.feedback.toast(l.contactAdded(contact.name), icon: Icons.person_add_alt);
    if (mounted) context.pop();
  }

  Future<void> _checkPackage(String packageId) async {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final mission = _mission;
    if (mission == null) return;
    if (packageId.trim() != mission.packageId) {
      Haptics.strong();
      setState(() => _error = l.wrongPackage(mission.packageId));
      return;
    }
    _done = true;
    final wasPickup = mission.stage == MissionStage.assigned;
    await scope.repository.advanceMission(mission.id);
    scope.feedback.toast(wasPickup ? l.pickedUp : l.deliveredToast, icon: Icons.task_alt);
    if (mounted) context.pop();
  }

  void _submitTyped() {
    final l = AppLocalizations.of(context);
    if (_forPackage) {
      _checkPackage(_id.text);
      return;
    }
    final id = normalizeResilienceId(_id.text);
    if (id == null || _name.text.trim().isEmpty) {
      Haptics.strong();
      setState(() => _error = l.invalidId);
      return;
    }
    _addContact(id, _name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    final manual = Text(l.scanUnavailable, style: TextStyle(color: c.onSurfaceVariant));

    return Scaffold(
      appBar: AppBar(title: Text(_forPackage ? l.scanPackage : l.scanTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1,
              child: ColoredBox(
                color: Colors.black,
                child: scannerCameraEnabled
                    ? MobileScanner(
                        onDetect: _onScan,
                        errorBuilder: (context, error) => _NoCamera(text: l.scanUnavailable),
                      )
                    : _NoCamera(text: l.scanUnavailable),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(l.scanHint, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          manual,
          const SizedBox(height: 16),
          TextField(
            controller: _id,
            textInputAction: _forPackage ? TextInputAction.done : TextInputAction.next,
            keyboardType: _forPackage ? TextInputType.number : TextInputType.text,
            onSubmitted: (_) => _forPackage ? _submitTyped() : null,
            decoration: InputDecoration(
              labelText: _forPackage ? l.enterPackageId : l.typeIdLabel,
              hintText: _forPackage ? null : l.typeIdHint,
              prefixIcon: Icon(_forPackage ? Icons.inventory_2_outlined : Icons.key),
            ),
          ),
          if (!_forPackage) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitTyped(),
              decoration: InputDecoration(
                labelText: l.theirName,
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
          ],
          if (_error != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.error_outline, color: c.error),
              title: Text(_error!, style: TextStyle(color: c.error)),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitTyped,
            icon: Icon(_forPackage ? Icons.task_alt : Icons.person_add_alt),
            label: Text(
              _forPackage
                  ? (_mission?.stage == MissionStage.assigned ? l.confirmPickup : l.confirmDelivery)
                  : l.addContact,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoCamera extends StatelessWidget {
  const _NoCamera({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
