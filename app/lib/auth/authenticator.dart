import 'default_authenticator_stub.dart'
    if (dart.library.io) 'default_authenticator_native.dart';

/// The outcome of an unlock attempt.
enum AuthOutcome {
  /// The device authenticated the user (biometric or device credential).
  approved,

  /// The user was prompted and failed/cancelled.
  denied,

  /// No biometric / device-credential hardware is available here. The caller
  /// must fall back to an explicit confirm + a plain-language warning that no
  /// biometric is available (web / unsupported devices).
  unavailable,
}

/// Abstraction over device unlock so the reveal gate can be driven by a fake in
/// tests. `local_auth` itself needs real hardware and platform channels and
/// cannot run headlessly, so the production implementation lives behind a
/// conditional import ([DefaultAuthenticator]) and the real biometric prompt is
/// marked "needs real device" in docs.
abstract class Authenticator {
  /// Whether this platform can prompt for a biometric / device credential.
  Future<bool> isBiometricAvailable();

  /// Attempt to unlock. [reason] is shown in the OS prompt where supported.
  Future<AuthOutcome> authenticate({required String reason});
}

/// A test/double authenticator whose behaviour is fully controlled by its
/// constructor arguments. Never touches a platform channel.
class FakeAuthenticator implements Authenticator {
  FakeAuthenticator({
    this.available = true,
    this.approve = true,
  });

  /// Whether [isBiometricAvailable] reports biometric hardware.
  bool available;

  /// Whether [authenticate] approves (true) or denies (false) when available.
  bool approve;

  /// Number of times [authenticate] was called (for assertions).
  int authenticateCalls = 0;

  @override
  Future<bool> isBiometricAvailable() async => available;

  @override
  Future<AuthOutcome> authenticate({required String reason}) async {
    authenticateCalls++;
    if (!available) return AuthOutcome.unavailable;
    return approve ? AuthOutcome.approved : AuthOutcome.denied;
  }
}

/// The platform-appropriate authenticator: `local_auth` on native, an honest
/// "unavailable" everywhere else (web/unsupported), so the caller shows the
/// confirm + no-biometric warning fallback.
Authenticator defaultAuthenticator() => makeDefaultAuthenticator();
