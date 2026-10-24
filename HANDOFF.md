# Handoff: Mesh app front end

Read this first. It says what is built, what is half-built, where each piece
of work was going, and how to finish it.

Last updated: 2026-10-24.

## 1. The short version

- **What this is.** "Mesh", a disaster-resilience phone app (Flutter, iPhone
  first). People ask for help, offer help, find resources and message each
  other over a radio mesh, with or without internet. Everything runs on demo
  data around San Jose State University.
- **Scope: front end only.** The owner's job in this hackathon is the front
  end. A teammate builds the backend. Never build a server, cloud service or
  infrastructure here. Where the app needs a server, build the app side,
  simulate the other side, and write down what the app expects.
- **Code.** The app is in `mesh-app/`. Helper scripts are in `tools/`.
- **Branches.** `claude/focused-keller-xt0gby` holds the finished,
  tested work (rename it when you push; the name is auto-generated and means
  nothing). Three `wip/...` branches hold unfinished work, one per area
  (section 7).
- **State.** The main branch passes `flutter analyze` with no issues, and all
  119 tests pass. The `wip/` branches compile cleanly but are not finished.

## 2. Setup and commands

Toolchain: Flutter 3.47.8, Dart 3.13.7 (pubspec allows Dart ^3.7).

```bash
cd mesh-app
flutter pub get
flutter gen-l10n           # after changing any .arb file
flutter analyze            # must say "No issues found!"
flutter test               # must all pass
flutter run --dart-define=AWS_MAP_KEY=your-key
```

Build options (`--dart-define=...`):

| Name | What it does |
|---|---|
| `AWS_MAP_KEY` | Amazon Location Service API key for the street map. Never commit it. |
| `AWS_MAP_REGION` | Region of that key. Default `us-east-2`. |
| `NODE_URL` | Resilience Node address. Default `http://192.168.4.1:8090` (`lib/data/endpoints.dart`). |
| `OFFLINE_MAP_URL` | (wip/map-offline) Download the offline map from here instead of the Node. |
| `REAL_GPS` | (wip/device-transports) `true` uses the phone's GPS; otherwise the demo point. |

Translations: every string lives in `lib/l10n/app_{en,es,vi,zh,tl}.arb`. Add
new strings to all five with
`python3 -I ../tools/l10n_merge.py lib/l10n/app_xx.arb strings.json`, then run
`flutter gen-l10n`. Write real translations, not English copies.

iPhone builds need a Mac with Xcode and CocoaPods. Bundle ID
`org.resilience.meshApp`; the app is named "Mesh" on the phone.

## 3. The owner's rules

How to work with the owner:
- Plain, short English. The direct answer first. Define technical terms.
- No emojis anywhere, in the UI or in replies.
- Never ask for AWS access keys or secret keys.
- No AI model names or IDs in commits, pull requests or files that get pushed.
- Do not commit `CLAUDE.md`.
- Front end only (see section 1).

UI rules (every change):
1. Forward and back navigation 100% consistent; every flow step is its own
   route. Reaching a screen in another tab: `context.push`, so Back returns
   to where the person was.
2. Bottom bar with a main action (the Help button) in the center. Always 1 or
   2 main actions, anchored at the bottom of a screen.
3. Always a manual fallback (for example, set the location by hand with no GPS).
4. Never show extra options. Hide them under an "Advanced" expander or a
   settings row with an icon and a line of subtext.
5. Five languages: English, Spanish, Vietnamese, Chinese, Filipino (Tagalog).
6. Simple UI with the map in front. Load in parallel or in the background.
7. Nothing under 16px, text or icons. A test enforces this.
8. Swipe between tabs or cards; tap, and tap-and-hold.
9. Accessible at all times, offline too: screen-reader labels, 48px tap
   targets, contrast, works at 150% text size.
10. Skeleton loaders, haptics, loading states for slow work.
11. Toasts at top and bottom, with haptics, for Undo and Redo.
12. Centralize calls; never re-create functions. Shared widgets live in `lib/ui/`.
13. Biometric lock on the device.
14. No glowing or "vibecoded" look: flat colors, a plain grey shadow only
    where something floats, no gradients, no blur.
15. The map is a real map (Amazon Location), never one drawn by hand.

Also: asking for help takes the fewest steps and has a large UI. People can
offer and host help, not only ask for it.

## 4. Product decisions already made

| Topic | Decision |
|---|---|
| Who opens the map first | A neighbor or bystander. The map leads with nearby open requests from other people, then resources. |
| SOS with no network at all | iPhones can't text silently. After the SOS, a full screen offers one tap: open Messages pre-filled to the person's emergency contacts. Second choice: Call 911. No contacts saved: main action is Call 911. |
| Location sharing | Only while the phone is carrying a delivery. A request or SOS still carries the location the person chose to send. |
| Street map | Amazon Location Service (Maps API v2, vector tiles), replacing Google. Labels for shops, restaurants, hotels and nightlife are hidden. |
| Offline map | A PMTiles package downloaded ahead of time from the Resilience Node (`/node/v1/map/{region}.pmtiles`). Amazon's terms don't allow storing its tiles. |
| Radios and the Resilience Node | Build the real app-side code paths, with simulated hardware for tests. Real devices are tested later. |
| Messaging | App side only, "ready for AWS IoT Core" (MQTT). The backend teammate decides the real setup. |
| Backend | Not ours. Document what the app expects instead. |

## 5. Branches and history

| Branch | State |
|---|---|
| `claude/focused-keller-xt0gby` | Finished and tested. Build on this. |
| `wip/nav-flows-sos` | Unfinished: navigation, request flow, bottom actions, offline SOS. |
| `wip/map-offline` | Unfinished: neighbor-first map, set my location, offline map. |
| `wip/device-transports` | Unfinished: GPS, delivery-only location, simulated links. |

All three `wip/` branches start from commit `0265ace` on the main branch and
do not include the merged "look" work (see section 6), so expect merge
conflicts (section 8).

Commits on the main branch, oldest first:
1. Add the Mesh phone app (Flutter) and its helper scripts.
2. Fix 9 bugs found in review and add tests that catch them.
3. Show a real street map from Amazon Location.
4. Add shared contracts and reusable review agents.
5. Add the Resilience Node address the app uses.
6. Make panels flat and share the timeline, empty state and action bar (merged).

## 6. Done and on the main branch

- **The phone app** on demo data: map, Help button (tap for a menu, hold 2
  seconds for SOS), two-step request flow, offers, requests, deliveries,
  messages, contacts, More screens, five languages, signed events, the trust
  model, biometric lock and erase.
- **Nine bugs fixed**, each with a test: second SOS hold, signature checks,
  three Undo bugs, unlock losing your place (the lock is now a layer over
  the app), a stale Undo overwriting a new request, the street map never
  retrying, and Clear cache deleting unsent messages.
- **Real street map** from Amazon Location (`lib/data/map_tiles.dart`), drawn
  by `vector_map_tiles` 9.0.0-beta.13 (pinned: the stable release doesn't
  support flutter_map 8). `tailorStyle` rewrites style rules the renderer
  can't read; without that, every cafe and ATM showed. Credit "© AWS, HERE"
  at the bottom right.
- **Shared contracts** for the parallel work:
  - `LocationFix.source` (GPS, typed by the person, or demo) and `label`.
  - `MeshRepository.setManualLocation`.
  - `MeshRepository.sharingLocation`: true only while carrying a delivery.
  - `NetworkStatus.hasRoute`.
  - "Not found" strings for deliveries and places.
  - `lib/data/endpoints.dart` for the Node address.
- **Flat look and shared widgets** (merged):
  - No blur and no glow. Panels are solid with a 1px border and one grey shadow.
  - New in `lib/ui/`: `StageList`, `EmptyState`/`NotFoundScaffold`,
    `ActionBar`, `InfoChip`, `ResourceBadge`, `AdvancedSection`,
    `FlatSkeletons`.
  - Correct "not found" messages.
  - Request details use plain stage words, with technical details under Advanced.
  - A "Sharing your location until you deliver" notice on the delivery screen.
- **Reusable agent prompts** in `.claude/agents/`. Any AI coding assistant
  can use them as task briefs or checklists:
  - `mesh-builder.md`: how to build here, with all the rules.
  - `mesh-ui-reviewer.md`: reviews screens against the 15 UI rules.
  - `mesh-bug-hunter.md`: proves each bug with a failing test.
  - `mesh-test-mutator.md`: plants small bugs to see if the tests catch them.

## 7. Unfinished work, one branch per area

Each area was a parallel worker that owned a fixed set of files, so the
branches mostly touch different files. Work stopped mid-task. Each `wip/`
commit message lists what was done and what was left.

### 7a. `wip/nav-flows-sos`: navigation, flows and offline SOS

Goal: fix rules 1, 2, 4, 7, 8, 9, 11 and 13 in navigation and flows, and build
the offline SOS text.

Files it owns: `lib/router.dart`, `lib/app.dart`, `lib/features/shell/*`,
`lib/features/help/*`, `messages_screen.dart`, `lib/features/contacts/*`,
`requests_screen.dart`, `display_screen.dart`, `more_screen.dart`,
`lib/state/drafts.dart`, `lib/state/settings_controller.dart`,
`lib/features/sos/*` (new). It deleted `lib/features/settings/`.

Done (in code, mostly untested):
- Cross-tab links use `push`, so Back returns where you were.
- Request step 2 asks only "How urgent is it?". The location field shows only
  without GPS. Note and people count sit behind an "Add details" expander.
- Request discard and send use `scope.undoable` (Undo and Redo).
- Main actions anchored at the bottom with a new `BottomActions` widget
  (`lib/features/shell/bottom_actions.dart`; consider moving it to `lib/ui/`):
  - Contacts: Scan QR.
  - Messages: a new "New message" action.
  - My requests: one main action; per-card buttons removed.
- Contact key codes moved out of the list rows.
- Bottom bar labels sized for 150% text. Swipe between the non-map tabs.
- Spanish word break fixed on the Display screen.
- Offline SOS:
  - `lib/features/sos/emergency_contacts_screen.dart`: up to 5 contacts, name
    and phone number, stored in `SettingsController`.
  - `no_network_sos_screen.dart`: route `/sos/:id`.
  - `sos_text.dart`: builds the `sms:` and `tel:911` links. `launchOnPhone`
    can be swapped in tests.
  - Uses `url_launcher`.

Left:
- Write tests for every change above. The brief asked for tests named
  `test/nav_*.dart`.
- Delete `test/nav_debug_test.dart` (a debugging leftover).
- Check that SOS from the lock screen also opens the no-network screen.
- Status: analyze clean; all 69 existing tests pass.

### 7b. `wip/map-offline`: the map

Goal: neighbor-first map, manual location, "Add here", large text, Back
fixes, offline street map.

Files it owns: `lib/features/map/*`, `lib/data/map_tiles.dart`,
`lib/data/offline_map*.dart` (new), `downloads_screen.dart`,
`add_resource_sheet.dart`.

Done:
- `lib/features/map/nearby.dart`: open requests from other people first (SOS,
  then urgency), then resources.
- `lib/features/map/set_location_screen.dart`: its own route. Drag the map
  under a fixed pin, add an optional label, then call `setManualLocation`.
- An "Add here" action, and map links use `push`.
- `lib/features/map/street_map.dart`: picks the online Amazon map or the
  offline package.
- Offline map:
  - `offline_map.dart`: download from `NODE_URL/node/v1/map/{region}.pmtiles`
    or `OFFLINE_MAP_URL`.
  - `offline_map_store*.dart`: a file store on phones, a memory store on web.
  - `offline_map_pmtiles.dart`: a small PMTiles reader.
  - `offline_map_theme.dart`: reads both Protomaps and OpenMapTiles layer names.
  - Uses `path_provider`.
- The Offline downloads screen shows size, progress, update and delete.
- Tests written: `map_offline_test.dart`, `map_pmtiles_test.dart` (with a
  generated fixture in `map_pmtiles_fixture.dart`), `map_screen_test.dart`,
  and a helper `map_test_app.dart`.

Left:
- The map screen rewrite stopped halfway. About 10 tests in
  `map_screen_test.dart` fail: "Add here", the empty card opening the add
  flow, large text at 100/125/150%, the set-location flow, and the 16px sweep
  on new screens. The test run also stopped early. Finish `map_screen.dart`
  until these pass.
- The status pill and card strip must not cut off at 150% text.
- Show the "© OpenStreetMap" credit when the offline map is showing.
- Status: analyze clean; 110 pass, 10 fail (all in `map_screen_test.dart`).

### 7c. `wip/device-transports`: device and data

Goal: real GPS, delivery-only location in the data layer, simulated radios
and Node, network screen under Advanced, the backend contract document,
Android folder, iOS permission texts.

Files it owns: `lib/data/mock_mesh_repository.dart`,
`lib/data/mesh_repository.dart` (additions only), `lib/data/transport/*`,
`lib/data/wire/*`, `lib/data/node_client.dart`, `lib/models/*`,
`lib/services/*`, `lib/main.dart`, `network_screen.dart`, `privacy_screen.dart`,
`android/`, `ios/`, `docs/`.

Done:
- `lib/services/location_service.dart`: the `LocationProvider` interface,
  with GPS through `geolocator`.
- `lib/data/transport/`:
  - `outbox.dart`: store and forward. Holds each item until a route
    confirms it, never sends twice, and retries.
  - `router.dart`: picks a route (AWS, then the Node, then LoRa, then nearby
    phones).
  - `location_policy.dart`: blocks location from leaving the phone unless it
    is carrying a delivery.
  - `simulated_transport.dart`, `nearby_transport.dart`, `lora_transport.dart`
    (with `radio_link.dart`, the interface the native Meshtastic side will
    implement), `cloud_transport.dart` (the MQTT client interface, ready for
    AWS IoT Core), and `node_transport.dart`.
- `lib/data/node_client.dart` and `lib/data/wire/*` speak the team's
  `resilience.v1` protobuf messages to the Node's `/node/v1/push`, `/pull`,
  `/have`, `/state` and `/healthz` (see the `feature/resilience-network`
  branch: `proto/` and `node/`). `test/device_node_live_test.dart` runs
  against a real Node when `NODE_LIVE_URL` is set; it is skipped otherwise.
- `lib/models/envelope.dart`: what leaves the phone, with priority. An SOS
  never waits.
- The demo repository now sends through the outbox and router.
- The network and privacy screens were changed (simple status, details under
  Advanced, the privacy explanation).

Left:
- Two tests fail:
  - "erasing clears this phone and resets settings" (app_test).
  - "cancel then restore reaches helper found only once" (expected 1, got 0).
    The repository's action methods were being rewired through the outbox
    when work stopped.
- Tests for the outbox, router, location policy, codecs and GPS fallback: no
  loss, no duplicates, ordering, and random up/down sequences.
- The Android folder. Run
  `flutter create . --platforms=android --org org.resilience --project-name mesh_app`,
  then delete the sample `test/widget_test.dart` it adds. Configure:
  - App label "Mesh"; `MainActivity` extends `FlutterFragmentActivity`.
  - Permissions: INTERNET, CAMERA, USE_BIOMETRIC, fine and coarse location,
    and Bluetooth and Wi-Fi as the links need.
  - `<queries>` for the `sms`, `smsto` and `tel` intents (needed by the
    offline SOS).
- iOS `ios/Runner/Info.plist`: `NSLocationWhenInUseUsageDescription`,
  Bluetooth usage text, and `LSApplicationQueriesSchemes` with `sms` and `tel`.
- `docs/app-backend-contract.md`: a short proposal for the backend teammate:
  - the envelope and event fields, signatures and acknowledgements;
  - the Node endpoints the app calls;
  - a suggested AWS IoT Core topic layout, marked as a suggestion.
- Status: analyze clean; 66 pass, 1 skipped, 2 fail.

## 8. How to finish and merge

1. Finish each `wip/` branch on its own, until `flutter analyze` is clean and
   `flutter test` passes there.
2. Merge them into the main branch one at a time:
   `git merge --no-ff wip/device-transports`, then `wip/map-offline`, then
   `wip/nav-flows-sos`.
3. Expect conflicts in:
   - The five `.arb` files. Keep the keys from both sides (they are new keys
     with different names), then run `flutter gen-l10n`. Never hand-merge
     `lib/l10n/gen/`.
   - `pubspec.yaml`/`pubspec.lock`. Keep both sides' new dependencies, then
     run `flutter pub get`.
   - Files the merged "look" work also touched (e.g. `request_actions.dart`,
     `test/app_test.dart`).
4. After each merge: `flutter pub get`, `flutter gen-l10n`, `flutter analyze`,
   `flutter test`.
5. Wiring left between areas once all are merged:
   - `lib/app.dart`: wrap the router's builder in `FlatSkeletons` (from
     `lib/ui/skeletons.dart`) so loading placeholders fade flat instead of
     shimmering.
   - `map_screen.dart`: replace `_MapChip` with `InfoChip(..., onMap: true,
     maxLines: 1)`. Glass `tint: urgent ? c.errorContainer : null` is enough now.
   - The requests list and map cards: show stages with `plainStageTitle(l,
     stage, mine:)` from `request_screen.dart`. Consider moving it into
     `lib/l10n/labels.dart`.
   - Remove the `_ignoringMapOverflow` helper in the look tests once the map's
     card strip fits at 150%.
   - Move `TrustMark` from `map_pins.dart` into `lib/ui/resource_badge.dart`
     (optional).
   - Show `SharingLocationNotice` on the map while carrying (optional).
   - Move `BottomActions` into `lib/ui/` (rule 12).
   - Add the Android `<queries>` and iOS `LSApplicationQueriesSchemes`
     entries the offline SOS needs (section 7c).

## 9. After merging: the review loop

Repeat until a round finds nothing serious:
1. Review with the prompts in `.claude/agents/`, in parallel: UI rules
   (`mesh-ui-reviewer`), bugs proved by tests (`mesh-bug-hunter`) and test
   strength (`mesh-test-mutator`).
2. Fix what they find, each fix with a test.
3. Run analyze and the full test suite.

Earlier rounds also listed these, still open after the work above:
- Erase must also clear an unfinished request draft (test it).
- Deep link to an unknown route: there is no `errorBuilder` yet.
- Lock when the app opens and when it goes to the background (test it).
- On a real phone, check that swiping the bottom cards on the map works.

## 10. Things only the owner can do

- **GitHub access.** Pushing from the cloud sessions failed with 403. Reconnect
  GitHub and install the GitHub app on `jenn435261/AWS-13`, or push from a
  computer (section 11).
- **Limit the map key** in the AWS console (Amazon Location, API keys):
  - Allowed action: `geo-maps:GetTile` only.
  - Allowed apps: iOS bundle ID `org.resilience.meshApp`, plus the website
    address if the web build is used.
  - Set an expiry date.
- **iPhone build** on a Mac.
- **Offline map data.** The Resilience Node must serve a real PMTiles file
  for the area at `/node/v1/map/{region}.pmtiles`. That is the backend
  teammate's side.

## 11. Getting this onto GitHub from a computer

```bash
git clone https://github.com/jenn435261/AWS-13.git && cd AWS-13
git fetch /path/to/aws-13-mesh-app.bundle \
  claude/focused-keller-xt0gby:mesh-app-frontend \
  wip/nav-flows-sos:wip/nav-flows-sos \
  wip/map-offline:wip/map-offline \
  wip/device-transports:wip/device-transports
git push -u origin mesh-app-frontend wip/nav-flows-sos wip/map-offline wip/device-transports
```

Then open a pull request from `mesh-app-frontend` into `main`.
