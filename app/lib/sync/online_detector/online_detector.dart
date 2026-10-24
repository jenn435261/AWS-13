// Platform-conditional "is the browser/device online?" seam.
//
// On web we can honestly observe `navigator.onLine` and the window
// `online`/`offline` events. On native there is no cheap equivalent without a
// native-only plugin (connectivity_plus), and we must NEVER import a native-only
// plugin into the web build, so native reports "unknown" (null) and the
// connectivity model falls back to the real reachability measured by the sync
// client. See docs/DECISIONS.md (Round 2 / FEAT-002).
export 'stub.dart' if (dart.library.js_interop) 'web.dart';
