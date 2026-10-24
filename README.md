# mesh_app

Flutter front end for a LoRa mesh help network (Meshtastic-style), one
codebase for iOS, Android and web. The phone is the primary computer:
everything is saved and signed on the phone first, then sent over whatever
route exists (internet, local Wi-Fi, Bluetooth, LoRa mesh).

Data comes from `MockMeshRepository`, which plays the other phones, the mesh
and the cloud, so every screen works before the radios and AWS side exist.

## First-time setup

```bash
cd /path/to/this/folder
bash tool/setup_platforms.sh com.yourname
```

The script runs `flutter create` (adds `ios/` and `android/`), then adds what
the app needs:

- iOS: camera (QR scanner), location and Face ID permission text, and a
  minimum iOS version the scanner supports.
- Android: location, camera and biometric permissions, the "Call 911" dialer
  query, and `FlutterFragmentActivity` for the app lock.

For your iPhone, open `ios/Runner.xcworkspace` in Xcode once and set
**Runner > Signing & Capabilities > Team** to your Personal Team.

## Run

```bash
flutter run -d chrome               # quickest look
flutter devices                     # find your phone's ID
flutter run -d <phone ID>           # debug: hot reload with r
flutter run --release -d <phone ID> # opens from the home screen afterwards
flutter test
```

Debug builds on iPhone only open from your Mac. Use `--release` to open the
app from the home screen. Builds made with a free Apple account stop opening
after 7 days; run again to refresh.

## What's in it

- **Map** (home): requests, resources and nodes on real OpenStreetMap
  streets, centered on your GPS. Offline, it falls back to a drawn demo
  neighborhood.
- **Help button** (center): tap for "I need help" / "I can help" step flows;
  hold 2 seconds to send an SOS with no questions.
- **Messages**: channels and direct chats, queued until a route exists.
  Hold a message to translate or copy it.
- **Contacts**: add people by QR code, typed ID, or phone number.
- **More**: deliveries, organizations, readiness downloads, display,
  language, privacy and data clearing, app lock, network status.
- **Roles**: client, manager, admin; Manage and Admin screens are gated.

Languages: English, Spanish, Vietnamese, Chinese (Simplified), and
Filipino (Tagalog). Translations live in `lib/l10n/app_*.arb`; Flutter
regenerates `lib/l10n/gen/` from them. Have native speakers review them.

## Manual fallbacks

- No GPS: the request flow asks people to describe where they are.
- No mesh in time: every open request of yours shows **Call 911**.
- No internet for translation: the original message stays.
- Face ID fails: the phone's passcode works; SOS still works while locked.

In the demo, translation needs "internet" on. Turn it on in
**More > Network** (a demo switch).

## Connecting the real backend

Everything goes through `lib/data/mesh_repository.dart`. Write a real
implementation (local SQLite store plus the transports) and pass it in
`lib/main.dart`; no screen changes. In particular:

- `translate()` is where Amazon Translate plugs in.
- `reportLocation()` already receives the phone's GPS
  (`lib/services/device_location.dart`).
- Roles must come from the server; the route guards only hide screens.
