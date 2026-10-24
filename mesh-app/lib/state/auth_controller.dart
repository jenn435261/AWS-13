import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/role.dart';

/// Signing in is optional: anyone can ask for help as a guest. Helpers,
/// managers and admins sign in.
class AuthController extends ChangeNotifier {
  static const guest = AppUser(id: 'me', name: 'Guest', role: Role.client);

  AppUser? _user;

  AppUser? get user => _user;
  bool get isSignedIn => _user != null;
  Role get role => _user?.role ?? Role.client;

  /// Who this phone acts as: the signed-in user, or a guest.
  AppUser get me => _user ?? guest;

  /// DEMO ONLY: lets you pick a role to try each layout.
  /// Replace with real sign-in (e.g. Amazon Cognito), where the role comes
  /// from the backend (a Cognito group or token claim), never from the client.
  Future<void> signIn({required String name, required Role role}) async {
    final trimmed = name.trim();
    _user = AppUser(
      id: 'me',
      name: trimmed.isEmpty ? 'Guest' : trimmed,
      role: role,
    );
    notifyListeners();
  }

  void signOut() {
    if (_user == null) return;
    _user = null;
    notifyListeners();
  }
}
