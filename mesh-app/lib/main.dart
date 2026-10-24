import 'package:flutter/material.dart';

import 'app.dart';
import 'data/mock_mesh_repository.dart';
import 'data/node_client.dart';
import 'data/transport/lora_transport.dart';
import 'data/transport/nearby_transport.dart';
import 'data/transport/node_transport.dart';
import 'data/transport/radio_link.dart';
import 'data/wire/event_codec.dart';
import 'models/network.dart';
import 'services/location_service.dart';
import 'state/auth_controller.dart';
import 'state/identity.dart';
import 'state/lock_controller.dart';
import 'state/settings_controller.dart';

// Build flags (docs/device-setup.md). Without them the app is the demo:
// every link simulated, and the demo point near SJSU as the location.

/// The phone's own GPS instead of the demo point.
const realGps = bool.fromEnvironment('REAL_GPS');

/// Sync with the Resilience Node at NODE_URL (data/endpoints.dart).
const nodeSync = bool.fromEnvironment('NODE_SYNC');

/// A Meshtastic LoRa radio, once the native side exists.
const loraRadio = bool.fromEnvironment('LORA_RADIO');

/// Nearby phones over Bluetooth and Wi-Fi, once the native side exists.
const nearbyPhones = bool.fromEnvironment('NEARBY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The phone makes its own identity first: no server involved.
  final (identity, settings) = await (
    Identity.generate(),
    SettingsController().loadAndReturn(),
  ).wait;

  // One codec, so an event keeps the same id on every route.
  final codec = EventCodec(identity);

  // Network data starts loading now, in the background; the first screen
  // shows skeletons until it arrives. Real links replace the simulated
  // ones of the same kind; swap in the real local-first repository later
  // without touching any screen.
  final repository = MockMeshRepository(
    identity: identity,
    locationProvider: realGps ? DeviceLocationProvider() : null,
    transports: [
      if (nodeSync) NodeTransport(client: NodeClient(), codec: codec),
      if (loraRadio) LoraTransport(radio: PlatformRadioLink.lora(), codec: codec),
      if (nearbyPhones) ...[
        NearbyTransport(
          kind: LinkKind.bluetooth,
          link: PlatformRadioLink.bluetooth(),
          codec: codec,
        ),
        NearbyTransport(
          kind: LinkKind.wifi,
          link: PlatformRadioLink.wifi(),
          codec: codec,
        ),
      ],
    ],
  );

  runApp(
    MeshApp(
      auth: AuthController(),
      repository: repository,
      settings: settings,
      lock: LockController(),
    ),
  );
}
