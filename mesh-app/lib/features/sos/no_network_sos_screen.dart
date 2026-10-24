import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../models/help.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/visuals.dart';
import '../shell/bottom_actions.dart';
import 'emergency_contacts_screen.dart';
import 'sos_text.dart';

/// Shown right after an SOS that reached no network: the SOS waits on this
/// phone, so offer the phone's own ways out. One main action: text the
/// emergency contacts (the phone's Messages app opens with everything filled
/// in), or call 911 when there are none.
class NoNetworkSosScreen extends StatefulWidget {
  const NoNetworkSosScreen({
    super.key,
    required this.requestId,
    this.onLockScreen = false,
  });

  final String requestId;

  /// Opened over the lock screen, on its own navigator instead of the app's.
  final bool onLockScreen;

  @override
  State<NoNetworkSosScreen> createState() => _NoNetworkSosScreenState();
}

class _NoNetworkSosScreenState extends State<NoNetworkSosScreen> {
  /// After texting, "Not now" becomes "Done".
  bool _texted = false;

  Future<void> _open(Uri uri) async {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    Haptics.strong();
    var opened = false;
    try {
      opened = await launchOnPhone(uri);
    } catch (_) {}
    if (!opened) {
      scope.feedback.toast(l.sosLaunchFailed, icon: Icons.error_outline, strong: true);
      return;
    }
    if (uri.scheme == 'sms' && mounted) setState(() => _texted = true);
  }

  void _addContacts() {
    if (widget.onLockScreen) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const EmergencyContactForm()),
      );
    } else {
      context.push(emergencyContactFormPath());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return ListenableBuilder(
      listenable: Listenable.merge([
        scope.settings,
        scope.repository.requests,
        scope.repository.location,
      ]),
      builder: (context, _) {
        final contacts = scope.settings.emergencyContacts;
        final request = scope.repository.requests.value
            .where((r) => r.id == widget.requestId)
            .firstOrNull;
        final fix = scope.repository.location.value;
        final body = sosTextBody(
          l,
          name: scope.auth.isSignedIn ? scope.auth.me.name : null,
          point: request?.location ?? fix?.point,
          place: fix?.source == LocationSource.manual ? fix!.label : '',
          at: request?.createdAt ?? DateTime.now(),
        );
        final close = Navigator.of(context).pop;

        final BottomActions actions;
        if (contacts.isEmpty) {
          actions = BottomActions(
            main: _SosButton(
              icon: Icons.call,
              label: l.sosCall911,
              onPressed: () => _open(emergencyCallUri),
            ),
            secondary: [
              OutlinedButton.icon(
                style: BottomActions.secondaryStyle,
                onPressed: _addContacts,
                icon: const Icon(Icons.person_add_alt),
                label: Text(l.sosAddContacts),
              ),
            ],
          );
        } else {
          actions = BottomActions(
            main: _SosButton(
              icon: Icons.sms_outlined,
              label: l.sosTextContacts(contacts.length),
              onPressed: () => _open(smsUri([for (final c in contacts) c.dialable], body)),
            ),
            secondary: [
              OutlinedButton.icon(
                style: BottomActions.secondaryStyle,
                onPressed: () => _open(emergencyCallUri),
                icon: const Icon(Icons.call),
                label: Text(l.sosCall911),
              ),
              TextButton(
                style: BottomActions.secondaryStyle,
                onPressed: close,
                child: Text(_texted ? l.sosDone : l.sosNotNow),
              ),
            ],
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: l.close,
              icon: const Icon(Icons.close),
              onPressed: close,
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Icon(Icons.signal_cellular_connected_no_internet_0_bar, size: 56, color: sosRed),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(l.sosNoNetworkTitle, style: theme.textTheme.headlineMedium),
              ),
              const SizedBox(height: 12),
              Text(
                contacts.isEmpty ? l.sosNoNetworkBodyNoContacts : l.sosNoNetworkBody,
                style: theme.textTheme.bodyLarge,
              ),
              if (contacts.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(l.sosMessageLabel, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(body, style: theme.textTheme.bodyLarge),
                ),
              ],
            ],
          ),
          bottomNavigationBar: actions,
        );
      },
    );
  }
}

/// The main action here may need two lines at large text sizes ("Enviar SMS
/// a 3 contactos de emergencia"), so it wraps instead of cutting the words.
class _SosButton extends StatelessWidget {
  const _SosButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: sosRed,
        foregroundColor: Colors.white,
        textStyle: Theme.of(context).textTheme.titleMedium,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, textAlign: TextAlign.center, maxLines: 2),
    );
  }
}
