# mesh_app

Minimal Flutter front end for a LoRa mesh (Meshtastic-style), one codebase for
web, iOS and Android, with three roles: client, authorized manager, admin.

## Run it

```bash
cd mesh_app
flutter pub get
flutter run -d chrome --dart-define=AWS_MAP_KEY=your-key   # or a phone
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

## Street map (Amazon Location Service)

The street map comes from Amazon Location Service, Maps API v2
(`lib/data/map_tiles.dart`). It arrives as vector tiles plus a style, drawn by
`vector_map_tiles`; the app's own pins, radio coverage and links are drawn on
top. The app hides shop, restaurant, hotel and nightlife labels, and shows
street names in the app's language where the map has them. To set it up:

1. In the AWS console, open **Amazon Location Service**, then **API keys**, and
   create a key in your Region (the team uses `us-east-2`).
2. Allow only the map action the app uses: `geo-maps:GetTile`. (The style,
   icons and fonts load without a key.)
3. Restrict the key to your app: iOS bundle ID `org.resilience.meshApp`, the
   Android package, and your web address. Give it an expiry date.
4. Build with `--dart-define=AWS_MAP_KEY=your-key` (and
   `--dart-define=AWS_MAP_REGION=...` for a Region other than `us-east-2`).
   Never commit the key.

The data credit ("© AWS, HERE") shows at the bottom right, as the terms ask.
With no internet the map shows pins and radios only, and the street map comes
back on its own when the connection does. A real offline map (OpenStreetMap
data in a downloaded package, as the Spec describes) is the next step for that.

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
