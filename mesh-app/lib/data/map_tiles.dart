import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// The Google Maps Platform key, set when building:
/// `flutter run --dart-define=GOOGLE_MAPS_KEY=...`. It needs the Map Tiles
/// API turned on. Without it the map shows pins with no street map.
const googleMapsKey = String.fromEnvironment('GOOGLE_MAPS_KEY');

enum MapTilesStatus {
  /// No key in this build.
  notSetUp,
  loading,
  ready,

  /// No internet, or the key was refused.
  unavailable,
}

/// Street map tiles from Google Maps (the Map Tiles API), drawn under the
/// app's own pins and radio links. One session per look and language, as the
/// API asks. Google's terms limit storing tiles, so the app keeps no offline
/// copy; with no internet the map shows pins without streets.
class MapTiles extends ChangeNotifier {
  MapTiles({this.key = googleMapsKey, http.Client? client})
      : _client = client ?? http.Client();

  final String key;
  final http.Client _client;

  static const _base = 'https://tile.googleapis.com';

  MapTilesStatus _status = MapTilesStatus.notSetUp;
  String? _session;
  String? _copyright;
  (bool, String)? _look;
  Timer? _attributionTimer;
  bool _disposed = false;

  MapTilesStatus get status => key.isEmpty ? MapTilesStatus.notSetUp : _status;

  /// The tile address for the map layer, once a session is open.
  String? get urlTemplate => _session == null
      ? null
      : '$_base/v1/2dtiles/{z}/{x}/{y}?session=$_session&key=$key';

  /// Google's data credit for the area on screen, shown on the map.
  String? get copyright => _copyright;

  /// Opens a session for this look and language, unless one is open already.
  Future<void> open({required bool dark, required String languageCode}) async {
    if (key.isEmpty) return;
    final look = (dark, languageCode);
    if (look == _look && _status != MapTilesStatus.unavailable) return;
    _look = look;
    _set(MapTilesStatus.loading);
    final basic = {
      'mapType': 'roadmap',
      'language': _googleLanguage(languageCode),
      'region': 'US',
    };
    try {
      var response = await _createSession({
        ...basic,
        // Sharp on high-density screens; drawn at 256 points per tile.
        'scale': 'scaleFactor2x',
        'highDpi': true,
        'styles': dark ? _darkStyle : _lightStyle,
      });
      // If Google turns down the extra options, the standard map still beats
      // no map.
      if (response.statusCode == 400) response = await _createSession(basic);
      if (_disposed || look != _look) return;
      if (response.statusCode != 200) {
        _set(MapTilesStatus.unavailable);
        return;
      }
      _session = (jsonDecode(response.body) as Map<String, dynamic>)['session'] as String;
      _set(MapTilesStatus.ready);
    } catch (_) {
      if (!_disposed && look == _look) _set(MapTilesStatus.unavailable);
    }
  }

  Future<http.Response> _createSession(Map<String, Object> body) => _client.post(
        Uri.parse('$_base/v1/createSession?key=$key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

  /// Asks for the data credit once the map stops moving.
  void viewChanged(LatLng north, LatLng south, LatLng east, LatLng west, int zoom) {
    if (_session == null) return;
    _attributionTimer?.cancel();
    _attributionTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        final response = await _client.get(Uri.parse(
          '$_base/tile/v1/viewport?session=$_session&key=$key&zoom=$zoom'
          '&north=${north.latitude}&south=${south.latitude}'
          '&east=${east.longitude}&west=${west.longitude}',
        ));
        if (_disposed || response.statusCode != 200) return;
        final copyright =
            (jsonDecode(response.body) as Map<String, dynamic>)['copyright'] as String?;
        if (copyright != _copyright) {
          _copyright = copyright;
          notifyListeners();
        }
      } catch (_) {
        // The credit stays as it was; the map itself is unaffected.
      }
    });
  }

  /// A tile failed to load, so the connection is likely gone.
  void tileFailed() {
    if (_status == MapTilesStatus.ready) _set(MapTilesStatus.unavailable);
  }

  void _set(MapTilesStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _attributionTimer?.cancel();
    _client.close();
    super.dispose();
  }

  static String _googleLanguage(String code) => switch (code) {
        'zh' => 'zh-CN',
        'tl' => 'fil',
        'en' => 'en-US',
        _ => code,
      };

  // Shops and restaurants are hidden so help pins stand out; everything else
  // is Google's standard map.
  static const _lightStyle = [
    {
      'featureType': 'poi.business',
      'stylers': [
        {'visibility': 'off'},
      ],
    },
  ];

  // Google's map in the app's dark colors.
  static const _darkStyle = [
    {
      'elementType': 'geometry',
      'stylers': [
        {'color': '#111a2c'},
      ],
    },
    {
      'elementType': 'labels.text.fill',
      'stylers': [
        {'color': '#a3aec4'},
      ],
    },
    {
      'elementType': 'labels.text.stroke',
      'stylers': [
        {'color': '#0b1220'},
      ],
    },
    {
      'featureType': 'road',
      'elementType': 'geometry',
      'stylers': [
        {'color': '#1e2944'},
      ],
    },
    {
      'featureType': 'road.highway',
      'elementType': 'geometry',
      'stylers': [
        {'color': '#2b3a5c'},
      ],
    },
    {
      'featureType': 'water',
      'elementType': 'geometry',
      'stylers': [
        {'color': '#0c2a47'},
      ],
    },
    {
      'featureType': 'poi.park',
      'elementType': 'geometry',
      'stylers': [
        {'color': '#10302a'},
      ],
    },
    {
      'featureType': 'poi.business',
      'stylers': [
        {'visibility': 'off'},
      ],
    },
    {
      'featureType': 'transit',
      'elementType': 'geometry',
      'stylers': [
        {'color': '#1b263d'},
      ],
    },
  ];
}
