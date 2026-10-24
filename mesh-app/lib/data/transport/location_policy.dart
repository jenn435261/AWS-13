import 'package:flutter/foundation.dart';

import '../../models/envelope.dart';

/// Product decision: this phone's location is shared only while it carries
/// a delivery. Every envelope passes through here on its way out, so no
/// screen or transport can get this wrong.
///
/// Coordinates leave the phone in exactly these cases:
///  * a help request or SOS carries the place the person chose to send
///    with it: that place is the request itself;
///  * a resource report carries the place the person put it on the map;
///  * while [sharing] is true, the carrier's live position on a delivery.
/// Everything else leaves without coordinates, and a live position that
/// was still waiting when the delivery ended is dropped, never sent late.
class LocationPolicy {
  const LocationPolicy(this.sharing);

  /// True only while this phone carries a delivery.
  final ValueListenable<bool> sharing;

  static bool carriesChosenPlace(EnvelopeKind kind) =>
      kind == EnvelopeKind.helpRequest ||
      kind == EnvelopeKind.sos ||
      kind == EnvelopeKind.resourceCreated;

  /// Field names that would smuggle a position past [Envelope.location].
  static final _positionKey = RegExp(
    r'^(lat|lon|lng|latitude|longitude|location|position|coords?|point|gps|accuracy)$',
    caseSensitive: false,
  );

  /// What may be queued: [envelope] as it is, a copy without coordinates,
  /// or null when it may not leave at all.
  Envelope? admit(Envelope envelope) {
    final e = _clean(envelope);
    if (e.kind == EnvelopeKind.liveLocation) {
      return sharing.value && e.location != null ? e : null;
    }
    if (e.location == null || carriesChosenPlace(e.kind)) return e;
    return e.withoutLocation();
  }

  /// Checked again just before a route takes it: sharing may have ended
  /// while it waited.
  bool maySend(Envelope envelope) =>
      envelope.kind != EnvelopeKind.liveLocation || sharing.value;

  static Envelope _clean(Envelope e) {
    if (!e.fields.keys.any(_positionKey.hasMatch)) return e;
    return Envelope(
      id: e.id,
      kind: e.kind,
      subject: e.subject,
      author: e.author,
      createdAt: e.createdAt,
      fields: {
        for (final f in e.fields.entries)
          if (!_positionKey.hasMatch(f.key)) f.key: f.value,
      },
      location: e.location,
    );
  }
}
