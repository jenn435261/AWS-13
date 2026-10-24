import 'authenticator.dart';

/// Web / unsupported-platform authenticator: there is no biometric or
/// device-credential API here, so it honestly reports unavailable. The reveal
/// gate then uses the explicit confirm + "no biometric available" warning.
class _UnavailableAuthenticator implements Authenticator {
  const _UnavailableAuthenticator();

  @override
  Future<bool> isBiometricAvailable() async => false;

  @override
  Future<AuthOutcome> authenticate({required String reason}) async =>
      AuthOutcome.unavailable;
}

Authenticator makeDefaultAuthenticator() => const _UnavailableAuthenticator();
