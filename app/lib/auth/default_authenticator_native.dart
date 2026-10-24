import 'package:local_auth/local_auth.dart';

import 'authenticator.dart';

/// Native authenticator backed by `local_auth` (Android BiometricPrompt / iOS
/// Face ID / Touch ID / device credential).
///
/// This code path requires real hardware and platform channels; it cannot run
/// in the headless `flutter test` VM, so it is covered only on a real device.
/// Tests inject a [FakeAuthenticator] instead. See docs/DECISIONS.md
/// (Round 2 / FEAT-003): "needs real device".
class DefaultAuthenticator implements Authenticator {
  DefaultAuthenticator([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isBiometricAvailable() async {
    try {
      // Either biometrics OR a device passcode/PIN/pattern counts as a usable
      // unlock. isDeviceSupported() is true when a device credential exists.
      final supported = await _auth.isDeviceSupported();
      if (supported) return true;
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AuthOutcome> authenticate({required String reason}) async {
    try {
      if (!await isBiometricAvailable()) return AuthOutcome.unavailable;
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return ok ? AuthOutcome.approved : AuthOutcome.denied;
    } catch (_) {
      // Any platform error => treat as denied (never silently reveal).
      return AuthOutcome.denied;
    }
  }
}

Authenticator makeDefaultAuthenticator() => DefaultAuthenticator();
