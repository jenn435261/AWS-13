import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:latlong2/latlong.dart';

import '../../models/envelope.dart';
import '../../models/help.dart';
import '../../models/resource.dart';
import '../../state/identity.dart';
import 'proto.dart';

/// `resilience.v1.EventType` numbers (proto/resilience/v1/event.proto on
/// the feature/resilience-network branch).
abstract final class WireType {
  static const resourceCreated = 10;
  static const resourceUpdated = 11;
  static const resourceConfirmed = 13;
  static const resourceDisputed = 14;
  static const resourceUseful = 15;
  static const helpRequested = 20;
  static const helpOffered = 21;
  static const messageSent = 30;
  static const missionAccepted = 41;
  static const packagePickedUp = 43;
  static const packageTransferred = 44;
  static const deliveryCompleted = 45;
  static const emergencyAlert = 50;
  static const locationStop = 61;

  /// EVENT_TYPE_HELP_REQUEST_CLOSED. Body field 1 is the request id.
  static const helpCancelled = 24;

  // PROPOSED: the app needs these and event.proto has no number for them
  // yet. The Node stores them today (it checks signatures, not types).
  // See docs/app-backend-contract.md; change them here in one place.
  static const resourceVoteWithdrawn = 18;
  static const helpAccepted = 25;
  static const helpReleased = 26;
  static const offerWithdrawn = 27;
  static const missionReleased = 48;

  /// The names protojson uses, for reading the Node's JSON replies.
  static const byName = {
    'EVENT_TYPE_UNSPECIFIED': 0,
    'EVENT_TYPE_IDENTITY_CERTIFICATE': 1,
    'EVENT_TYPE_KEY_REVOKED': 2,
    'EVENT_TYPE_ORG_CERTIFICATE': 3,
    'EVENT_TYPE_RESOURCE_CREATED': 10,
    'EVENT_TYPE_RESOURCE_UPDATED': 11,
    'EVENT_TYPE_RESOURCE_OBSERVED': 12,
    'EVENT_TYPE_RESOURCE_CONFIRMED': 13,
    'EVENT_TYPE_RESOURCE_DISPUTED': 14,
    'EVENT_TYPE_RESOURCE_USEFUL': 15,
    'EVENT_TYPE_INVENTORY_SNAPSHOT': 16,
    'EVENT_TYPE_RESERVATION': 17,
    'EVENT_TYPE_HELP_REQUESTED': 20,
    'EVENT_TYPE_HELP_OFFERED': 21,
    'EVENT_TYPE_SHELTER_CREATED': 22,
    'EVENT_TYPE_TRANSPORT_OFFERED': 23,
    'EVENT_TYPE_HELP_REQUEST_CLOSED': 24,
    'EVENT_TYPE_MESSAGE_SENT': 30,
    'EVENT_TYPE_MESSAGE_DELIVERED': 31,
    'EVENT_TYPE_MESSAGE_READ': 32,
    'EVENT_TYPE_CHANNEL_CREATED': 33,
    'EVENT_TYPE_CHANNEL_MEMBERSHIP': 34,
    'EVENT_TYPE_PREKEY_BUNDLE': 35,
    'EVENT_TYPE_MISSION_CREATED': 40,
    'EVENT_TYPE_MISSION_ACCEPTED': 41,
    'EVENT_TYPE_MISSION_MATCHED': 42,
    'EVENT_TYPE_PACKAGE_PICKED_UP': 43,
    'EVENT_TYPE_PACKAGE_TRANSFERRED': 44,
    'EVENT_TYPE_DELIVERY_COMPLETED': 45,
    'EVENT_TYPE_CAPABILITY_GRANTED': 46,
    'EVENT_TYPE_CAPABILITY_REVOKED': 47,
    'EVENT_TYPE_EMERGENCY_ALERT': 50,
    'EVENT_TYPE_LOCATION_SHARE': 60,
    'EVENT_TYPE_LOCATION_STOP': 61,
  };
}

/// `resilience.v1.Priority`.
abstract final class WirePriority {
  static const low = 1;
  static const normal = 2;
  static const high = 3;
  static const critical = 4;
}

/// BLAKE2b with a 32-byte digest, the event id hash.
final _blake2b256 = DartBlake2b(hashLengthInBytes: 32);

Uint8List blake2b256(List<int> data) =>
    Uint8List.fromList(_blake2b256.hashSync(data).bytes);

String hexOf(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// One `resilience.v1.SignedEvent`, the unit every route carries.
///
/// The recipe, matching node/internal/events/verify.go:
///  * event_id  = BLAKE2b-256(canonical header without event_id || body)
///  * signature = Ed25519(canonical header with event_id || body)
class WireEvent {
  WireEvent({
    required this.type,
    required this.author,
    required this.lamport,
    required this.createdAtMs,
    required this.body,
    Uint8List? prev,
    this.dependsOn = const [],
    this.schemaVersion = 1,
    this.h3Cell = 0,
    Uint8List? eventId,
    Uint8List? signature,
  })  : prev = prev ?? Uint8List(0),
        eventId = eventId ?? Uint8List(0),
        signature = signature ?? Uint8List(0);

  final int type;

  /// The author's 32-byte Ed25519 public key.
  final Uint8List author;
  final int lamport;
  final Uint8List prev;
  final List<Uint8List> dependsOn;
  final int createdAtMs;
  final int schemaVersion;
  final int h3Cell;
  final Uint8List body;
  Uint8List eventId;
  Uint8List signature;

  String get idHex => hexOf(eventId);

  /// `EventHeader`, canonical: fields in number order, defaults left out.
  Uint8List header({required bool includeId}) => (ProtoWriter()
        ..bytes(1, includeId ? eventId : const [])
        ..uint(2, type)
        ..bytes(3, author)
        ..uint(4, lamport)
        ..bytes(5, prev)
        ..repeated(6, dependsOn)
        ..uint(7, createdAtMs)
        ..uint(8, schemaVersion)
        ..uint(9, h3Cell))
      .done();

  Uint8List _preimage({required bool includeId}) =>
      Uint8List.fromList([...header(includeId: includeId), ...body]);

  Uint8List computeId() => blake2b256(_preimage(includeId: false));

  /// Bytes the signature covers.
  Uint8List signedBytes() => _preimage(includeId: true);

  /// `SignedEvent` as protobuf bytes.
  Uint8List toBytes() => (ProtoWriter()
        ..message(1, header(includeId: true))
        ..bytes(2, body)
        ..bytes(3, signature))
      .done();

  static WireEvent fromBytes(List<int> bytes) {
    final event = ProtoReader(bytes);
    final h = event.message(1) ?? ProtoReader(const []);
    return WireEvent(
      eventId: h.bytes(1),
      type: h.uint(2),
      author: h.bytes(3),
      lamport: h.uint(4),
      prev: h.bytes(5),
      dependsOn: h.repeated(6),
      createdAtMs: h.uint(7),
      schemaVersion: h.uint(8),
      h3Cell: h.uint(9),
      body: event.bytes(2),
      signature: event.bytes(3),
    );
  }

  /// `SignedEvent` in protojson form, as the Node reads and writes it.
  Map<String, Object?> toJson() => {
        'header': {
          'eventId': base64.encode(eventId),
          'type': type,
          'authorPubkey': base64.encode(author),
          if (lamport != 0) 'lamport': '$lamport',
          if (prev.isNotEmpty) 'prevEventId': base64.encode(prev),
          if (dependsOn.isNotEmpty) 'dependsOn': [for (final d in dependsOn) base64.encode(d)],
          if (createdAtMs != 0) 'createdAtMs': '$createdAtMs',
          if (schemaVersion != 0) 'schemaVersion': schemaVersion,
          if (h3Cell != 0) 'h3Cell': '$h3Cell',
        },
        'body': base64.encode(body),
        'signature': base64.encode(signature),
      };

  static WireEvent fromJson(Map<String, Object?> json) {
    final h = (json['header'] as Map?)?.cast<String, Object?>() ?? const {};
    Uint8List b64(Object? v) =>
        v is String ? base64.decode(base64.normalize(v)) : Uint8List(0);
    int number(Object? v) => switch (v) {
          int n => n,
          String s => int.tryParse(s) ?? WireType.byName[s] ?? 0,
          _ => 0,
        };
    return WireEvent(
      eventId: b64(h['eventId'] ?? h['event_id']),
      type: number(h['type']),
      author: b64(h['authorPubkey'] ?? h['author_pubkey']),
      lamport: number(h['lamport']),
      prev: b64(h['prevEventId'] ?? h['prev_event_id']),
      dependsOn: [
        for (final d in (h['dependsOn'] ?? h['depends_on'] ?? const []) as List) b64(d),
      ],
      createdAtMs: number(h['createdAtMs'] ?? h['created_at_ms']),
      schemaVersion: number(h['schemaVersion'] ?? h['schema_version']),
      h3Cell: number(h['h3Cell'] ?? h['h3_cell']),
      body: b64(json['body']),
      signature: b64(json['signature']),
    );
  }

  /// The checks the Node runs before it stores an event: the id is the
  /// content hash, and the author's key signed it. Never throws.
  Future<bool> verify() async {
    try {
      if (type == 0 || author.length != 32 || signature.length != 64) return false;
      if (eventId.length != 32 || !_same(computeId(), eventId)) return false;
      return await Ed25519().verify(
        signedBytes(),
        signature: Signature(
          signature,
          publicKey: SimplePublicKey(author, type: KeyPairType.ed25519),
        ),
      );
    } on Object {
      return false;
    }
  }
}

/// Turns the app's [Envelope]s into signed `resilience.v1` events and back.
///
/// The same envelope always becomes the same event (same id), whichever
/// route carries it and however often it is retried, so every receiver can
/// drop duplicates by event id.
class EventCodec {
  EventCodec(this.identity);

  final Identity identity;

  int _lamport = 0;
  Uint8List _prev = Uint8List(0);
  final _cache = <String, Future<WireEvent>>{};
  static const _cacheSize = 2000;

  late final Uint8List _author = Uint8List.fromList(identity.publicKey);

  /// Live positions are never encoded: the wire format needs them
  /// end-to-end encrypted, which the app can't do yet.
  bool canEncode(Envelope e) => e.kind != EnvelopeKind.liveLocation;

  Future<WireEvent> encode(Envelope e) {
    final cached = _cache[e.id];
    if (cached != null) return cached;
    if (_cache.length >= _cacheSize) _cache.remove(_cache.keys.first);
    return _cache[e.id] = _build(e);
  }

  Future<WireEvent> _build(Envelope e) async {
    if (!canEncode(e)) throw ArgumentError('cannot put ${e.kind.name} on the wire');
    final (type, body) = _body(e);
    // Ordering and the hash chain are fixed now, before any await, so
    // events keep the order they were first encoded in.
    final event = WireEvent(
      type: type,
      author: _author,
      lamport: ++_lamport,
      prev: _prev,
      createdAtMs: e.createdAt.millisecondsSinceEpoch,
      body: body,
    );
    event.eventId = event.computeId();
    _prev = event.eventId;
    event.signature = Uint8List.fromList(await identity.signBytes(event.signedBytes()));
    return event;
  }

  /// The wire id of the thing an envelope is about.
  static String ref(Envelope e) => (e.fields['ref'] as String?) ?? e.subject;

  (int, Uint8List) _body(Envelope e) {
    final f = e.fields;
    final w = ProtoWriter();
    final id = ref(e);
    switch (e.kind) {
      case EnvelopeKind.helpRequest || EnvelopeKind.sos:
        final sos = e.kind == EnvelopeKind.sos;
        final kind = sos ? HelpKind.medical : _byName(HelpKind.values, f['kind']) ?? HelpKind.other;
        final urgency = _byName(Urgency.values, f['urgency']) ?? Urgency.now;
        w
          ..string(1, id)
          ..packed(2, [_helpCategory(kind)])
          ..string(3, (f['note'] as String?) ?? '')
          ..uint(4, sos ? WirePriority.critical : _priority(urgency))
          ..message(5, _geoPoint(e.location, address: (f['locationNote'] as String?) ?? ''));
        return (WireType.helpRequested, w.done());
      case EnvelopeKind.helpCancelled:
        return (WireType.helpCancelled, (w..string(1, id)).done());
      case EnvelopeKind.helpAccepted:
        return (WireType.helpAccepted, (w..string(1, id)).done());
      case EnvelopeKind.helpReleased:
        return (WireType.helpReleased, (w..string(1, id)).done());
      case EnvelopeKind.offer:
        final kinds = [for (final k in (f['kinds'] as List?) ?? const []) _byName(SupplyKind.values, k)];
        w
          ..string(1, id)
          ..packed(2, [for (final k in kinds.whereType<SupplyKind>()) _supplyCategory(k)])
          ..uint(3, (_byName(Amount.values, f['amount'])?.index ?? -1) + 1)
          ..uint(4, (_byName(Availability.values, f['availability'])?.index ?? -1) + 1)
          ..string(5, [f['note'], f['availabilityNote']].whereType<String>().where((s) => s.isNotEmpty).join(' / '));
        return (WireType.helpOffered, w.done());
      case EnvelopeKind.offerWithdrawn:
        return (WireType.offerWithdrawn, (w..string(1, id)).done());
      case EnvelopeKind.resourceCreated:
        final kind = _byName(ResourceKind.values, f['kind']) ?? ResourceKind.water;
        final name = (f['name'] as String?) ?? '';
        w
          ..string(1, id)
          ..uint(2, _resourceCategory(kind))
          ..string(3, name.isEmpty ? kind.name : name)
          ..string(4, (f['note'] as String?) ?? '')
          ..message(8, _geoPoint(e.location))
          ..uint(9, 1) // PROVENANCE_KIND_COMMUNITY
          ..boolean(10, kind == ResourceKind.shelter);
        return (WireType.resourceCreated, w.done());
      case EnvelopeKind.resourceRemoved:
        w
          ..string(1, id)
          ..boolean(5, true); // ResourceUpdateBody.withdrawn
        return (WireType.resourceUpdated, w.done());
      case EnvelopeKind.vote:
        final vote = _byName(Vote.values, f['vote']);
        w.string(1, id);
        return switch (vote) {
          Vote.confirm => (WireType.resourceConfirmed, (w..uint(2, 2)).done()),
          Vote.dispute => (WireType.resourceDisputed, (w..uint(2, 3)).done()),
          Vote.useful => (WireType.resourceUseful, (w..uint(2, 4)).done()),
          null => (WireType.resourceVoteWithdrawn, w.done()),
        };
      case EnvelopeKind.message:
        // Public and community channels only (see Envelope.needsEndToEnd):
        // their text is readable by everyone, so it travels as is.
        w
          ..string(1, id)
          ..string(2, (f['channelId'] as String?) ?? e.subject)
          ..bytes(4, utf8.encode((f['text'] as String?) ?? ''))
          ..uint(6, WirePriority.normal);
        return (WireType.messageSent, w.done());
      case EnvelopeKind.missionAccepted:
        return (WireType.missionAccepted, (w..string(1, id)..bytes(2, _author)).done());
      case EnvelopeKind.missionReleased:
        return (WireType.missionReleased, (w..string(1, id)..bytes(2, _author)).done());
      case EnvelopeKind.packagePickedUp ||
            EnvelopeKind.packageTransferred ||
            EnvelopeKind.deliveryCompleted:
        final (type, stage) = switch (e.kind) {
          EnvelopeKind.packagePickedUp => (WireType.packagePickedUp, 1),
          EnvelopeKind.packageTransferred => (WireType.packageTransferred, 2),
          _ => (WireType.deliveryCompleted, 3),
        };
        w
          ..string(1, (f['packageId'] as String?) ?? '')
          ..string(2, id)
          ..bytes(3, _author)
          ..uint(5, stage)
          ..uint(6, e.createdAt.millisecondsSinceEpoch);
        return (type, w.done());
      case EnvelopeKind.locationStopped:
        w
          ..string(1, '${identity.resilienceId}-live-$id')
          ..uint(2, e.createdAt.millisecondsSinceEpoch);
        return (WireType.locationStop, w.done());
      case EnvelopeKind.liveLocation:
        throw ArgumentError('live positions need end-to-end encryption');
    }
  }

  /// Reads what another phone sent, for the kinds the app can show.
  /// Returns null for anything else.
  static Envelope? decode(WireEvent event) {
    final author = hexOf(event.author);
    final at = DateTime.fromMillisecondsSinceEpoch(event.createdAtMs);
    final id = 'w${event.idHex.substring(0, 16)}';
    try {
      final b = ProtoReader(event.body);
      switch (event.type) {
        case WireType.helpRequested:
          final sos = b.uint(4) == WirePriority.critical;
          final category = b.packed(2).firstOrNull ?? 99;
          final geo = b.message(5);
          return Envelope(
            id: id,
            kind: sos ? EnvelopeKind.sos : EnvelopeKind.helpRequest,
            subject: b.string(1),
            author: author,
            createdAt: at,
            fields: {
              'kind': _helpKindOf(category).name,
              'urgency': _urgencyOf(b.uint(4)).name,
              'note': b.string(3),
              if (geo != null && geo.string(7).isNotEmpty) 'locationNote': geo.string(7),
            },
            location: _point(geo),
          );
        case WireType.messageSent:
          return Envelope(
            id: id,
            kind: EnvelopeKind.message,
            subject: b.string(2),
            author: author,
            createdAt: at,
            fields: {
              'ref': b.string(1),
              'channelId': b.string(2),
              'text': utf8.decode(b.bytes(4), allowMalformed: true),
            },
          );
        case WireType.resourceCreated:
          return Envelope(
            id: id,
            kind: EnvelopeKind.resourceCreated,
            subject: b.string(1),
            author: author,
            createdAt: at,
            fields: {'name': b.string(3), 'note': b.string(4)},
            location: _point(b.message(8)),
          );
      }
    } on ProtoFormatException {
      return null;
    }
    return null;
  }

  // --- value mappings -----------------------------------------------------

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static int _priority(Urgency u) => switch (u) {
        Urgency.now => WirePriority.high,
        Urgency.soon => WirePriority.normal,
        Urgency.later => WirePriority.low,
      };

  static Urgency _urgencyOf(int p) => p >= WirePriority.high
      ? Urgency.now
      : p == WirePriority.normal
          ? Urgency.soon
          : Urgency.later;

  static const _helpCategories = {
    HelpKind.water: 1,
    HelpKind.food: 2,
    HelpKind.medicine: 3,
    HelpKind.shelter: 4,
    HelpKind.power: 5,
    HelpKind.transportation: 6,
    HelpKind.medical: 7,
    HelpKind.communication: 8,
    HelpKind.other: 99,
  };

  static int _helpCategory(HelpKind k) => _helpCategories[k]!;

  static HelpKind _helpKindOf(int category) => _helpCategories.entries
      .firstWhere((e) => e.value == category, orElse: () => const MapEntry(HelpKind.other, 99))
      .key;

  static int _supplyCategory(SupplyKind k) => switch (k) {
        SupplyKind.water => 1,
        SupplyKind.food => 2,
        SupplyKind.medicine => 3,
        SupplyKind.shelter => 4,
        SupplyKind.transportation => 6,
        SupplyKind.blankets => 9,
        SupplyKind.batteries => 10,
        SupplyKind.charging => 11,
        SupplyKind.tools => 12,
        SupplyKind.other => 99,
      };

  static int _resourceCategory(ResourceKind k) => switch (k) {
        ResourceKind.water => 1,
        ResourceKind.food => 2,
        ResourceKind.pharmacy => 3,
        ResourceKind.shelter => 4,
        ResourceKind.transportation => 6,
        ResourceKind.hospital => 7,
        ResourceKind.charging => 11,
        ResourceKind.police || ResourceKind.fire || ResourceKind.roadProblem => 99,
      };

  /// `GeoPoint`: a rounded point anyone may see, plus the exact one the
  /// person chose to send with this request or report.
  static Uint8List? _geoPoint(LatLng? p, {String address = ''}) {
    if (p == null && address.isEmpty) return null;
    final w = ProtoWriter();
    if (p != null) {
      double round(double v) => (v * 1000).roundToDouble() / 1000;
      w
        ..float64(2, round(p.latitude))
        ..float64(3, round(p.longitude))
        ..float64(4, p.latitude)
        ..float64(5, p.longitude)
        ..boolean(6, true);
    }
    return (w..string(7, address)).done();
  }

  static LatLng? _point(ProtoReader? geo) {
    if (geo == null) return null;
    final exact = geo.boolean(6);
    final lat = geo.float64(exact ? 4 : 2);
    final lon = geo.float64(exact ? 5 : 3);
    if (lat == 0 && lon == 0) return null;
    return LatLng(lat, lon);
  }
}
