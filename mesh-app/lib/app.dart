import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/mesh_repository.dart';
import 'features/lock/lock_screen.dart';
import 'l10n/labels.dart';
import 'router.dart';
import 'state/app_scope.dart';
import 'state/auth_controller.dart';
import 'state/drafts.dart';
import 'state/lock_controller.dart';
import 'state/settings_controller.dart';
import 'ui/feedback.dart';
import 'ui/theme.dart';

class MeshApp extends StatefulWidget {
  const MeshApp({
    super.key,
    required this.auth,
    required this.repository,
    required this.settings,
    required this.lock,
  });

  final AuthController auth;
  final MeshRepository repository;
  final SettingsController settings;
  final LockController lock;

  @override
  State<MeshApp> createState() => _MeshAppState();
}

class _MeshAppState extends State<MeshApp> {
  final _feedback = AppFeedback();
  final _requestDraft = RequestDraft();
  final _offerDraft = OfferDraft();
  late final GoRouter _router = buildRouter(
    auth: widget.auth,
    requestDraft: _requestDraft,
    offerDraft: _offerDraft,
  );
  late final StreamSubscription<MeshNotice> _notices;
  late final AppLifecycleListener _lifecycle;
  bool _offeredPackage = false;

  @override
  void initState() {
    super.initState();
    _notices = widget.repository.notices.listen(_showNotice);
    widget.repository.network.addListener(_offerPackage);
    // Locks when the app goes to the background, so the app switcher
    // never shows someone's requests.
    _lifecycle = AppLifecycleListener(onHide: () {
      if (widget.settings.lockOnOpen) widget.lock.lock();
    });
    if (widget.settings.lockOnOpen) widget.lock.lock();
  }

  void _showNotice(MeshNotice notice) {
    final context = _feedback.messengerKey.currentContext;
    if (context == null || widget.lock.locked) return;
    final l = AppLocalizations.of(context);
    final (message, path) = switch (notice) {
      NearbyRequestNotice(:final request) => (
          l.alertNearby(l.requestTitle(request)),
          requestPath(request.id),
        ),
      HelperFoundNotice(:final request) => (
          l.alertHelper(request.helperName ?? ''),
          requestPath(request.id),
        ),
      HandoffConfirmedNotice(:final mission) => (
          l.handoffConfirmed(mission.carrier ?? '', mission.packageId),
          missionPath(mission.id),
        ),
    };
    _feedback.alert(
      message,
      dismissLabel: l.dismiss,
      actionLabel: l.view,
      // Pushed, so Back returns to the screen the person was on.
      onAction: () => _router.push(path),
    );
  }

  /// Before an outage: once online, offer the newest offline package.
  void _offerPackage() {
    final repo = widget.repository;
    final package = repo.readiness.value;
    final context = _feedback.messengerKey.currentContext;
    if (_offeredPackage ||
        context == null ||
        !repo.network.value.internet ||
        !package.updateAvailable) {
      return;
    }
    _offeredPackage = true;
    final l = AppLocalizations.of(context);
    _feedback.alert(
      l.preparednessNotice(package.region, package.sizeMb),
      icon: Icons.download_for_offline_outlined,
      dismissLabel: l.dismiss,
      actionLabel: l.download,
      onAction: () {
        repo.downloadReadiness();
        _router.push(downloadsPath);
      },
    );
  }

  @override
  void dispose() {
    _notices.cancel();
    widget.repository.network.removeListener(_offerPackage);
    _lifecycle.dispose();
    _router.dispose();
    _feedback.dispose();
    _requestDraft.dispose();
    _offerDraft.dispose();
    widget.repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;

    return AppScope(
      auth: widget.auth,
      repository: widget.repository,
      settings: settings,
      lock: widget.lock,
      feedback: _feedback,
      requestDraft: _requestDraft,
      offerDraft: _offerDraft,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _feedback.messengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: settings.locale,
          theme: buildTheme(
            Brightness.light,
            highContrast: settings.highContrast,
          ),
          darkTheme: buildTheme(
            Brightness.dark,
            highContrast: settings.highContrast,
          ),
          themeMode: settings.themeMode,
          routerConfig: _router,
          // The in-app text size works on top of the phone's own setting.
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final phoneScale = media.textScaler.scale(minFontSize) / minFontSize;
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(phoneScale * settings.textScale),
              ),
              // The lock covers the app instead of replacing the route, so
              // unlocking returns to the exact screen and back stack.
              child: ListenableBuilder(
                listenable: widget.lock,
                builder: (context, _) => Stack(
                  children: [
                    Visibility(
                      visible: !widget.lock.locked,
                      maintainState: true,
                      child: child!,
                    ),
                    if (widget.lock.locked)
                      InheritedGoRouter(
                        goRouter: _router,
                        child: const _LockLayer(),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Hosts the lock screen above the router, on its own navigator: the step
/// after an SOS that reached no network opens on it, and so do the sheets
/// and toasts the lock screen may show.
class _LockLayer extends StatelessWidget {
  const _LockLayer();

  @override
  Widget build(BuildContext context) => Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const LockScreen()),
      );
}
