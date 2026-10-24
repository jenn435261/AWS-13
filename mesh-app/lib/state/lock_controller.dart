import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Locks the app behind Face ID, fingerprint or the phone's passcode.
/// The SOS button keeps working while locked.
class LockController extends ChangeNotifier {
  LockController({LocalAuthentication? auth, bool? deviceLockAvailable})
      : _auth = auth ?? LocalAuthentication(),
        deviceLockAvailable = deviceLockAvailable ?? !kIsWeb;

  final LocalAuthentication _auth;

  /// Phone unlock exists only in the iOS and Android apps. On the web the
  /// lock screen still works, but Unlock opens it without a check.
  final bool deviceLockAvailable;

  bool _locked = false;
  bool get locked => _locked;

  void lock() => _set(true);

  /// [reason] is shown by the phone's own unlock prompt. Not limited to
  /// biometrics, so the phone offers its passcode when Face ID fails.
  Future<bool> unlock(String reason) async {
    if (!deviceLockAvailable) {
      _set(false);
      return true;
    }
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
      if (ok) _set(false);
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Whether the phone has Face ID, a fingerprint or a passcode set up.
  Future<bool> deviceSupportsLock() async {
    if (!deviceLockAvailable) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  void _set(bool value) {
    if (_locked == value) return;
    _locked = value;
    notifyListeners();
  }
}
