import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/hold_button.dart';
import '../../ui/theme.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  /// Whether the phone has Face ID, a fingerprint or a passcode set up.
  bool _deviceSupportsLock = false;
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    AppScope.of(context).lock.deviceSupportsLock().then((ok) {
      if (mounted) setState(() => _deviceSupportsLock = ok);
    });
  }

  Future<void> _toggleLock(bool on) async {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    Haptics.tick();
    // Turning the lock on needs a successful unlock first, so nobody is
    // locked out of their own phone.
    if (on && !await scope.lock.unlock(l.unlockReason)) {
      scope.feedback.toast(l.unlockFailed, icon: Icons.error_outline);
      return;
    }
    scope.settings.lockOnOpen = on;
  }

  Future<void> _clear() async {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final count = await scope.repository.clearCache();
    scope.feedback.toast(l.cleared(count), icon: Icons.cleaning_services_outlined);
  }

  Future<void> _erase() async {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    await scope.repository.wipe();
    await scope.settings.reset();
    scope.requestDraft.reset();
    scope.offerDraft.reset();
    scope.auth.signOut();
    router.go('/map');
    scope.feedback.toast(l.erased, icon: Icons.delete_forever, strong: true);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final lock = scope.lock;
    final settings = scope.settings;

    final lockNote = !lock.deviceLockAvailable
        ? l.phoneLockWeb
        : !_deviceSupportsLock
            ? l.phoneLockUnavailable
            : l.phoneLockSub;

    return Scaffold(
      appBar: AppBar(title: Text(l.privacy)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: helpButtonClearance + 16),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: Text(l.phoneLock),
              subtitle: Text(lockNote),
              value: settings.lockOnOpen,
              onChanged: _deviceSupportsLock ? _toggleLock : null,
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(l.lockNow),
              subtitle: Text(l.lockNowSub),
              onTap: () {
                Haptics.success();
                lock.lock();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: Text(l.clearTemp),
              subtitle: Text(l.clearTempSub),
              onTap: _clear,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HoldButton(
                duration: const Duration(seconds: 3),
                semanticsLabel: l.eraseAll,
                semanticsHint: l.eraseAllSub,
                onHeld: _erase,
                builder: (context, progress) => Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(color: c.error, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: ColoredBox(
                            color: c.error.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.delete_forever, color: c.error),
                        title: Text(
                          l.eraseAll,
                          style: TextStyle(
                            color: c.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(l.eraseAllSub),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
