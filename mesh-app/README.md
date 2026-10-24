# mesh_app

Minimal Flutter front end for a LoRa mesh (Meshtastic-style), one codebase for
web, iOS and Android, with three roles: client, authorized manager, admin.

## Run it

```bash
cd mesh_app
flutter pub get
flutter run -d chrome --dart-define=GOOGLE_MAPS_KEY=your-key   # or a phone
flutter test
```

Without the key everything works, but the map shows pins and radios with no
streets under them. For Android, run `flutter create . --platforms=android`
once (it adds only the missing android/ folder; delete the sample
`test/widget_test.dart` it also adds).

The sign-in screen is a demo: pick a role to try each layout. Fake nodes check
in every ~12 seconds so the screens have live data.

## Web release build

```bash
flutter build web --wasm --release
```

The admin screen is a deferred import, so on web it is a separate chunk that
only admins download. `web/index.html` shows a CSS spinner until Flutter starts.

## iPhone build (needs a Mac)

Apple's build tools only run on macOS. On a Mac with Xcode, Flutter and
CocoaPods installed:

```bash
flutter doctor          # everything under "Xcode" should be green
flutter run             # picks the iPhone simulator, or a plugged-in iPhone
```

To install on your own iPhone, open `ios/Runner.xcworkspace` in Xcode, choose
your Apple ID under Signing & Capabilities, and change the bundle identifier
(`org.resilience.meshApp`) if Xcode says it is taken. `ios/Runner/Info.plist`
already explains why the app asks for Face ID and the camera.

## Street map (Google Maps)

The street map comes from Google's Map Tiles API (`lib/data/map_tiles.dart`);
the app's own pins, radio coverage and links are drawn on top. To set it up:

1. In Google Cloud Console, create a project and turn on billing (Google
   gives a free monthly allowance).
2. Turn on **Map Tiles API**, then create an API key under Credentials.
3. Restrict the key to the Map Tiles API, and to your web address or app.
4. Build with `--dart-define=GOOGLE_MAPS_KEY=your-key`. Never commit the key.

Google's terms require "Google Maps" at the bottom left (the app shows it as
text; swap in Google's official logo image when you have it) and the data
credit at the bottom right (fetched for the area on screen). The terms do not
allow keeping tiles for offline use, so with no internet the map shows pins and
radios only. A real offline map (OpenStreetMap data in a downloaded package,
as the Spec describes) is the next step for that.

## Look and feel

All colors, the bundled font (Plus Jakarta Sans, in `assets/fonts`), and the
shared panels live in `lib/ui/theme.dart` and `lib/ui/surfaces.dart`; each
kind of need has its own color in `lib/ui/visuals.dart`. Colors are flat, with
plain grey shadows only where something floats. The only repeating motion
marks something real: urgent requests, your location, and the request step
that is still waiting. It stops when the phone's "reduce motion" setting is
on, and high contrast turns the floating panels solid.

## Layout

```
lib/
  main.dart                 picks the MeshRepository implementation
  app.dart                  theme + MaterialApp.router
  router.dart               routes, role per route, redirect guard
  models/                   Role, AppUser, MeshNode, MeshMessage
  data/
    mesh_repository.dart    interface every screen uses
    mock_mesh_repository.dart
  state/                    AuthController, SettingsController, AppScope
  features/
    shell/                  bottom bar (phone) / side rail (wide)
    login/ messages/ nodes/ manage/ admin/ settings/
```

| Screen   | Client | Manager | Admin |
|----------|:------:|:-------:|:-----:|
| Messages | ✓ | ✓ | ✓ |
| Nodes    | ✓ (enabled nodes only) | ✓ | ✓ |
| Manage   |   | ✓ | ✓ |
| Admin    |   |   | ✓ |
| Settings | ✓ | ✓ | ✓ |

## Connecting the real backend

1. Write `AwsMeshRepository implements MeshRepository` (or `BleMeshRepository`
   if phones will talk to radios directly) and pass it in `main.dart`.
   Push incoming packets into its `ValueNotifier`s; no screen changes needed.
2. Replace `AuthController.signIn` with real auth (e.g. Amazon Cognito) and read
   the role from the token / Cognito group.
3. Enforce roles on the backend too (IoT policies, API authorizers). The route
   guard in `router.dart` only hides screens; it is not security.

Messages are capped at 200 characters (`maxMessageLength`) to fit LoRa packets.
