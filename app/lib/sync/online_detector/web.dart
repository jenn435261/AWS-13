import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web implementation: observes `navigator.onLine` and the window
/// `online`/`offline` events so the connectivity banner can flip live without a
/// reload. Pure browser API, web-safe, no native plugin.
class OnlineDetector {
  OnlineDetector() {
    _online = _onOnline.toJS;
    _offline = _onOffline.toJS;
    web.window.addEventListener('online', _online);
    web.window.addEventListener('offline', _offline);
  }

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  late final JSFunction _online;
  late final JSFunction _offline;

  void _onOnline(web.Event _) => _controller.add(true);
  void _onOffline(web.Event _) => _controller.add(false);

  bool? get isOnline => web.window.navigator.onLine;

  Stream<bool> get changes => _controller.stream;

  void dispose() {
    web.window.removeEventListener('online', _online);
    web.window.removeEventListener('offline', _offline);
    unawaited(_controller.close());
  }
}
