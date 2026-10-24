import 'package:flutter/painting.dart' show Color;

/// The layer names inside an offline map package. Packages built with the
/// Protomaps basemap tools use one set; packages built with Planetiler's
/// default (OpenMapTiles) use another. The app reads both.
enum OfflineMapSchema {
  protomaps,
  openMapTiles;

  /// Picks the schema from the layer names in the package's metadata.
  /// Unknown or missing names default to Protomaps, the likely source.
  static OfflineMapSchema of(Set<String> layers) =>
      layers.contains('transportation') && !layers.contains('roads')
          ? OfflineMapSchema.openMapTiles
          : OfflineMapSchema.protomaps;
}

/// The source name the offline style draws from.
const offlineMapSourceId = 'offline';

/// Flat colors for the offline street map, close to the online map's, so
/// switching between them doesn't change what the person is used to.
class _Palette {
  const _Palette({
    required this.earth,
    required this.water,
    required this.park,
    required this.building,
    required this.path,
    required this.minor,
    required this.major,
    required this.highway,
    required this.casing,
    required this.rail,
    required this.label,
    required this.halo,
  });

  final Color earth;
  final Color water;
  final Color park;
  final Color building;
  final Color path;
  final Color minor;
  final Color major;
  final Color highway;
  final Color casing;
  final Color rail;
  final Color label;
  final Color halo;

  static const light = _Palette(
    earth: Color(0xFFEEF0F3),
    water: Color(0xFFB7D0E8),
    park: Color(0xFFD3E8CC),
    building: Color(0xFFE0E3E8),
    path: Color(0xFFD2D6DD),
    minor: Color(0xFFFFFFFF),
    major: Color(0xFFFFFFFF),
    highway: Color(0xFFFBE2A8),
    casing: Color(0xFFCDD2DA),
    rail: Color(0xFFB8BEC8),
    label: Color(0xFF39404E),
    halo: Color(0xFFFFFFFF),
  );

  static const dark = _Palette(
    earth: Color(0xFF142034),
    water: Color(0xFF0C2944),
    park: Color(0xFF16302A),
    building: Color(0xFF1C293E),
    path: Color(0xFF26344B),
    minor: Color(0xFF2B3A53),
    major: Color(0xFF364862),
    highway: Color(0xFF5B4B2B),
    casing: Color(0xFF0E1726),
    rail: Color(0xFF3A475C),
    label: Color(0xFFCAD3E4),
    halo: Color(0xFF111A2C),
  );
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Where each kind of thing lives in a schema, as a source layer and a
/// filter on that layer.
typedef _Pick = (String layer, List<Object?>? filter);

List<Object?> _kindIn(String field, List<String> values) =>
    ['match', ['get', field], values, true, false];

const _parkKinds = [
  'park', 'garden', 'grass', 'forest', 'wood', 'nature_reserve', 'cemetery',
  'golf_course', 'playground', 'recreation_ground', 'meadow', 'village_green',
];

Map<String, _Pick> _picks(OfflineMapSchema schema) => switch (schema) {
      OfflineMapSchema.protomaps => {
          'earth': ('earth', null),
          'park': ('landuse', _kindIn('kind', _parkKinds)),
          'water': ('water', null),
          'building': ('buildings', null),
          'path': ('roads', _kindIn('kind', ['path', 'other'])),
          'minor': ('roads', _kindIn('kind', ['minor_road'])),
          'major': ('roads', _kindIn('kind', ['major_road'])),
          'highway': ('roads', _kindIn('kind', ['highway'])),
          'rail': ('roads', _kindIn('kind', ['rail'])),
          'roadName': ('roads', null),
          'place': ('places', null),
        },
      OfflineMapSchema.openMapTiles => {
          'park': ('park', null),
          'green': ('landcover', _kindIn('class', ['wood', 'grass', 'farmland', 'wetland'])),
          'water': ('water', null),
          'building': ('building', null),
          'path': ('transportation', _kindIn('class', ['path', 'track'])),
          'minor': ('transportation', _kindIn('class', ['minor', 'service', 'tertiary'])),
          'major': ('transportation', _kindIn('class', ['primary', 'secondary', 'trunk'])),
          'highway': ('transportation', _kindIn('class', ['motorway'])),
          'rail': ('transportation', _kindIn('class', ['rail', 'transit'])),
          'roadName': ('transportation_name', null),
          'place': ('place', null),
        },
    };

/// Name fields to try for each app language, before the local name.
const _names = {
  'en': ['name:en'],
  'es': ['name:es'],
  'vi': ['name:vi'],
  'zh': ['name:zh-Hans', 'name:zh'],
  'tl': ['name:tl', 'name:fil'],
};

/// Grows a line with the zoom, from [at12] wide at zoom 12 to [at18] at 18.
List<Object?> _width(double at12, double at18) =>
    ['interpolate', ['exponential', 1.6], ['zoom'], 12, at12, 18, at18];

/// A simple style for an offline package: land, water, parks, buildings,
/// roads and their names, and place names. Labels are 16 px or larger, like
/// all text in the app.
Map<String, dynamic> offlineMapStyle({
  required OfflineMapSchema schema,
  required bool dark,
  required String languageCode,
}) {
  final p = dark ? _Palette.dark : _Palette.light;
  final picks = _picks(schema);
  final name = [
    'coalesce',
    for (final f in _names[languageCode] ?? const <String>[]) ['get', f],
    ['get', 'name'],
  ];
  const polygon = ['==', ['geometry-type'], 'Polygon'];
  const line = ['==', ['geometry-type'], 'LineString'];

  Map<String, dynamic> layer(
    String id,
    String type, {
    required Map<String, dynamic> paint,
    Map<String, dynamic>? layout,
    List<Object?>? also,
    int? minzoom,
  }) {
    final pick = picks[id.split('-').first];
    if (pick == null) return const {};
    final filters = [
      if (pick.$2 != null) pick.$2,
      if (also != null) also,
    ];
    return {
      'id': id,
      'type': type,
      'source': offlineMapSourceId,
      'source-layer': pick.$1,
      if (filters.length == 1) 'filter': filters.first,
      if (filters.length > 1) 'filter': ['all', ...filters],
      if (minzoom != null) 'minzoom': minzoom,
      if (layout != null) 'layout': layout,
      'paint': paint,
    };
  }

  Map<String, dynamic> road(String id, Color fill, double at12, double at18, {int? minzoom}) => layer(
        id,
        'line',
        minzoom: minzoom,
        layout: {'line-cap': 'round', 'line-join': 'round'},
        paint: {'line-color': _hex(fill), 'line-width': _width(at12, at18)},
      );

  Map<String, dynamic> casing(String id, double at12, double at18, {int? minzoom}) =>
      road('$id-casing', p.casing, at12 + 1, at18 + 2.5, minzoom: minzoom);

  final layers = [
    {
      'id': 'background',
      'type': 'background',
      'paint': {'background-color': _hex(p.earth)},
    },
    layer('earth', 'fill', paint: {'fill-color': _hex(p.earth)}, also: polygon),
    layer('green', 'fill', paint: {'fill-color': _hex(p.park)}, also: polygon),
    layer('park', 'fill', paint: {'fill-color': _hex(p.park)}, also: polygon),
    layer('water', 'fill', paint: {'fill-color': _hex(p.water)}, also: polygon),
    layer('water-line', 'line', also: line, paint: {
      'line-color': _hex(p.water),
      'line-width': _width(1, 6),
    }),
    layer('building', 'fill', minzoom: 14, also: polygon, paint: {
      'fill-color': _hex(p.building),
      'fill-outline-color': _hex(p.casing),
    }),
    road('path', p.path, 0.5, 3, minzoom: 14),
    road('rail', p.rail, 0.8, 2.5, minzoom: 12),
    casing('minor', 0.6, 9),
    casing('major', 1.4, 14),
    casing('highway', 2, 18),
    road('minor', p.minor, 0.6, 9),
    road('major', p.major, 1.4, 14),
    road('highway', p.highway, 2, 18),
    layer('roadName', 'symbol', minzoom: 15, also: line, layout: {
      'symbol-placement': 'line',
      'text-field': name,
      'text-size': 16,
    }, paint: {
      'text-color': _hex(p.label),
      'text-halo-color': _hex(p.halo),
      'text-halo-width': 1.5,
    }),
    layer('place', 'symbol', layout: {
      'text-field': name,
      'text-size': 18,
      'text-max-width': 8,
    }, paint: {
      'text-color': _hex(p.label),
      'text-halo-color': _hex(p.halo),
      'text-halo-width': 2,
    }),
  ];

  return {
    'version': 8,
    'name': 'Mesh offline',
    'sources': {
      offlineMapSourceId: {'type': 'vector'},
    },
    'layers': [
      for (final l in layers)
        if (l.isNotEmpty) l,
    ],
  };
}
