import 'package:flutter/material.dart';

import 'app.dart';
import 'data/mock_mesh_repository.dart';
import 'state/auth_controller.dart';
import 'state/identity.dart';
import 'state/lock_controller.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The phone makes its own identity first: no server involved.
  final (identity, settings) = await (
    Identity.generate(),
    SettingsController().loadAndReturn(),
  ).wait;

  // Network data starts loading now, in the background; the first screen
  // shows skeletons until it arrives. Swap this for the real local-first
  // repository without touching any screen.
  final repository = MockMeshRepository(identity: identity);

  runApp(
    MeshApp(
      auth: AuthController(),
      repository: repository,
      settings: settings,
      lock: LockController(),
    ),
  );
}
