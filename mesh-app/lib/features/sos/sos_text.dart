import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/labels.dart';

/// Opens another app on this phone (Messages, the dialer) for [uri]. Tests
/// swap it to check the exact URI without launching anything.
Future<bool> Function(Uri uri) launchOnPhone =
    (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// The phone's dialer, ready to call emergency services.
final emergencyCallUri = Uri(scheme: 'tel', path: '911');

/// A text to [numbers] with [body] filled in, in the form each phone's
/// Messages app reads. iPhones can't send texts silently, so the person sees
/// it and taps Send. iOS takes several recipients only as
/// `sms:/open?addresses=a,b&body=...`; Android takes `sms:a,b?body=...`.
Uri smsUri(List<String> numbers, String body, {TargetPlatform? platform}) {
  final text = Uri.encodeComponent(body);
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      final to = numbers.map(Uri.encodeComponent).join(',');
      return Uri.parse('sms:/open?addresses=$to&body=$text');
    default:
      return Uri.parse('sms:${numbers.join(',')}?body=$text');
  }
}

/// The SOS text: who, where and when. [place] is what the person typed when
/// GPS couldn't help; [point] the coordinates, when known.
String sosTextBody(
  AppLocalizations l, {
  required String? name,
  required LatLng? point,
  required String place,
  required DateTime at,
}) {
  final coordinates = point == null
      ? null
      : '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  final location = switch ((place.trim(), coordinates)) {
    ('', null) => l.sosLocationUnknown,
    ('', final c?) => c,
    (final p, null) => p,
    (final p, final c?) => '$p ($c)',
  };
  // Numbers only, so it reads the same in every language.
  final time = DateFormat('yyyy-MM-dd HH:mm').format(at);
  return name == null || name.trim().isEmpty
      ? l.sosTextBodyGuest(location, time)
      : l.sosTextBody(name.trim(), location, time);
}
