import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';

import '../core/event_factory.dart';
import '../core/lamport_clock.dart';
import '../core/signing.dart';
import '../gen/resilience/v1/event.pb.dart';

/// Capability-based authorization for the logistics subsystem.
///
/// ## Authority model (spec §23)
///
/// Authorization in the Resilience Network is **capability-based, not
/// role/trust-based**. A right to act is a signed [CapabilityBody] granted by
/// an authorized *issuer* to a *subject* (an Ed25519 pubkey), scoped to a
/// resource and listing the exact [actions] it confers.
///
/// Who may issue a capability for a scope `mission:X`?
///
///  * the **mission creator** — the author of the `MISSION_CREATED` event for
///    mission `X` is the root authority for `mission:X`; they may grant any
///    capability scoped to it;
///  * an **authority delegate** — a subject that itself holds a capability for
///    the same scope whose [actions] include `grant` (so authority can be
///    delegated one hop at a time while remaining cryptographically
///    accountable).
///
/// "Chris has `MISSION_2193_DRIVER`" therefore means: a capability granted by
/// mission 2193's creator (or a `grant`-holder for `mission:2193`) to Chris'
/// pubkey, scoped `mission:2193`, listing the driver actions
/// (`see_mission`, `see_exact_pickup`, `see_exact_destination`,
/// `message_participants`, `confirm_pickup`, `confirm_delivery`). It lets Chris
/// act on mission 2193 only — never mission 2194, which is a different scope.
///
/// ## Revocation & expiry
///
/// A capability is withdrawn by a `CAPABILITY_REVOKED` event (carrying a
/// [CapabilityBody] whose `capabilityId` matches) authored by an issuer
/// authorized for the scope. A capability with a non-zero `validUntilMs` in the
/// past is expired and never honored.

/// The canonical driver actions conferred by a `MISSION_x_DRIVER` capability.
///
/// A mission creator issues exactly these to the assigned courier so the
/// courier can see and operate on that one mission.
const List<String> kMissionDriverActions = <String>[
  'see_mission',
  'see_exact_pickup',
  'see_exact_destination',
  'message_participants',
  'confirm_pickup',
  'confirm_delivery',
];

/// The action that lets a capability holder issue further capabilities for the
/// same scope (one-hop authority delegation).
const String kGrantAction = 'grant';

/// Builds the scope string for a mission id, e.g. `mission:2193`.
String missionScope(String missionId) => 'mission:$missionId';

/// An immutable, verified-at-construction view of a single capability grant.
class Capability {
  Capability({
    required this.capabilityId,
    required List<int> subjectPubkey,
    required List<int> issuerPubkey,
    required this.scope,
    required List<String> actions,
    required this.validUntilMs,
  })  : subjectPubkey = Uint8List.fromList(subjectPubkey),
        issuerPubkey = Uint8List.fromList(issuerPubkey),
        actions = List<String>.unmodifiable(actions);

  /// Lift a [CapabilityBody] into a [Capability] value.
  factory Capability.fromBody(CapabilityBody body) => Capability(
        capabilityId: body.capabilityId,
        subjectPubkey: body.subjectPubkey,
        issuerPubkey: body.issuerPubkey,
        scope: body.scope,
        actions: body.actions,
        validUntilMs: body.validUntilMs.toInt(),
      );

  final String capabilityId;
  final Uint8List subjectPubkey;
  final Uint8List issuerPubkey;
  final String scope;
  final List<String> actions;

  /// Unix millis after which this capability is expired; `0` means no expiry.
  final int validUntilMs;

  /// Whether this capability is still within its validity window at [nowMs].
  bool isLive(int nowMs) => validUntilMs == 0 || nowMs < validUntilMs;

  /// Whether this capability confers [action] (either directly, or because it
  /// holds the all-powerful [kGrantAction]).
  bool grants(String action) =>
      actions.contains(action) || actions.contains(kGrantAction);
}

/// The set of live capabilities held by a single subject, folded from
/// `CAPABILITY_GRANTED` / `CAPABILITY_REVOKED` events.
///
/// Query it with [can]: does the subject hold a *live* capability for [scope]
/// that confers [action]?
class CapabilitySet {
  CapabilitySet(this._byId);

  /// capabilityId -> Capability for every live (non-revoked) capability held.
  final Map<String, Capability> _byId;

  /// All live capabilities, in no particular order.
  Iterable<Capability> get all => _byId.values;

  bool get isEmpty => _byId.isEmpty;

  /// Whether the subject can perform [action] within [scope], at [nowMs].
  bool can(
    String action, {
    required String scope,
    int? nowMs,
  }) {
    final int now = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final Capability c in _byId.values) {
      if (c.scope != scope) continue;
      if (!c.isLive(now)) continue;
      if (c.grants(action)) return true;
    }
    return false;
  }

  /// Whether the subject holds any live capability for [scope].
  bool hasScope(String scope, {int? nowMs}) {
    final int now = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    return _byId.values.any((c) => c.scope == scope && c.isLive(now));
  }
}

/// Verifies capability events and folds them into a [CapabilitySet].
///
/// Verification is a signature-chain check:
///  1. the event itself must verify (Ed25519 + content hash) — delegated to
///     [EventFactory.verifyEvent];
///  2. the event author must equal the [CapabilityBody.issuerPubkey] (an
///     issuer cannot forge a grant on another issuer's behalf);
///  3. the issuer must be *authorized for the scope* — either the scope's root
///     authority (e.g. the mission creator) or a holder of a `grant`
///     capability for that scope.
///
/// A capability granted by a non-authorized issuer is rejected and never
/// enters the folded set.
class CapabilityVerifier {
  CapabilityVerifier({EventFactory? factory})
      : _factory = factory ?? EventFactory();

  final EventFactory _factory;

  /// Builds a signed `CAPABILITY_GRANTED` event. The [issuerKeyPair] signs it;
  /// its pubkey is written into both the event header and the body's
  /// `issuerPubkey`, binding issuer identity to the signature.
  Future<SignedEvent> grant({
    required KeyPairData issuerKeyPair,
    required LamportClock clock,
    required String capabilityId,
    required List<int> subjectPubkey,
    required String scope,
    required List<String> actions,
    int validUntilMs = 0,
    List<int>? prevEventId,
  }) {
    final body = CapabilityBody(
      capabilityId: capabilityId,
      subjectPubkey: subjectPubkey,
      issuerPubkey: issuerKeyPair.publicKey,
      scope: scope,
      actions: actions,
      validUntilMs: Int64(validUntilMs),
    );
    return _factory.buildFromMessage(
      keyPair: issuerKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_CAPABILITY_GRANTED,
      body: body,
      prevEventId: prevEventId,
    );
  }

  /// Builds a signed `CAPABILITY_REVOKED` event referencing the capability to
  /// withdraw by id. The [issuerKeyPair] must be authorized for the scope (the
  /// fold enforces this).
  Future<SignedEvent> revoke({
    required KeyPairData issuerKeyPair,
    required LamportClock clock,
    required String capabilityId,
    required List<int> subjectPubkey,
    required String scope,
    List<int>? prevEventId,
  }) {
    final body = CapabilityBody(
      capabilityId: capabilityId,
      subjectPubkey: subjectPubkey,
      issuerPubkey: issuerKeyPair.publicKey,
      scope: scope,
    );
    return _factory.buildFromMessage(
      keyPair: issuerKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_CAPABILITY_REVOKED,
      body: body,
      prevEventId: prevEventId,
    );
  }

  /// Folds all capability events into a [CapabilitySet] for [subjectPubkey].
  ///
  /// [rootAuthoritiesByScope] maps a scope to the pubkeys that are its root
  /// authority (e.g. `mission:2193` -> the mission 2193 creator). Grants from a
  /// root authority are always honored; grants from anyone else are honored
  /// only if that issuer itself holds a live `grant` capability for the scope.
  ///
  /// Events are processed in Lamport-then-id order so a grant is always seen
  /// before any later revocation of it, and a delegated issuer's own `grant`
  /// capability is established before grants that depend on it.
  Future<CapabilitySet> foldForSubject({
    required List<int> subjectPubkey,
    required List<SignedEvent> events,
    required Map<String, Set<AuthorityKey>> rootAuthoritiesByScope,
    int? nowMs,
  }) async {
    final int now = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final Uint8List subject = Uint8List.fromList(subjectPubkey);

    // Order deterministically & causally: lamport asc, then event id.
    final List<SignedEvent> ordered = List<SignedEvent>.of(events)
      ..sort(_compareEvents);

    // Track, per scope, the subjects that currently hold a live `grant`
    // capability (so we can authorize delegated issuers). Keyed by scope ->
    // set of authority keys. Seeded with the roots.
    final Map<String, Set<AuthorityKey>> granters =
        <String, Set<AuthorityKey>>{};
    rootAuthoritiesByScope.forEach((scope, keys) {
      granters[scope] = <AuthorityKey>{...keys};
    });

    // All live capabilities for OUR subject.
    final Map<String, Capability> held = <String, Capability>{};

    for (final SignedEvent e in ordered) {
      final EventType t = e.header.type;
      final bool isGrant = t == EventType.EVENT_TYPE_CAPABILITY_GRANTED;
      final bool isRevoke = t == EventType.EVENT_TYPE_CAPABILITY_REVOKED;
      if (!isGrant && !isRevoke) continue;

      if (!await _factory.verifyEvent(e)) continue;

      final CapabilityBody body = CapabilityBody.fromBuffer(e.body);

      // The event author MUST be the declared issuer.
      if (!_bytesEqual(e.header.authorPubkey, body.issuerPubkey)) continue;

      // The issuer must be authorized for the scope.
      final Set<AuthorityKey> scopeGranters =
          granters[body.scope] ?? const <AuthorityKey>{};
      final bool issuerAuthorized =
          scopeGranters.contains(AuthorityKey(body.issuerPubkey));
      if (!issuerAuthorized) continue;

      // Maintain the delegated-granter set regardless of subject: anyone who is
      // granted a `grant` capability for a scope becomes a granter for it.
      if (isGrant && body.actions.contains(kGrantAction)) {
        (granters[body.scope] ??= <AuthorityKey>{})
            .add(AuthorityKey(body.subjectPubkey));
      }
      if (isRevoke && body.actions.contains(kGrantAction)) {
        granters[body.scope]?.remove(AuthorityKey(body.subjectPubkey));
      }

      // Only accumulate capabilities addressed to our subject.
      if (!_bytesEqual(body.subjectPubkey, subject)) continue;

      if (isGrant) {
        final Capability cap = Capability.fromBody(body);
        if (!cap.isLive(now)) continue; // already-expired grant is a no-op
        held[cap.capabilityId] = cap;
      } else {
        held.remove(body.capabilityId);
      }
    }

    return CapabilitySet(held);
  }

  static int _compareEvents(SignedEvent a, SignedEvent b) {
    final int la = a.header.lamport.toInt();
    final int lb = b.header.lamport.toInt();
    if (la != lb) return la - lb;
    return _compareBytes(a.header.eventId, b.header.eventId);
  }

  static int _compareBytes(List<int> a, List<int> b) {
    final int n = a.length < b.length ? a.length : b.length;
    for (int i = 0; i < n; i++) {
      final int d = a[i] - b[i];
      if (d != 0) return d;
    }
    return a.length - b.length;
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Order-insensitive, hashable wrapper around a pubkey so it can key a [Set] or
/// [Map]. Mirrors `AuthorKey` from the db layer but is local to logistics so
/// this module has no db dependency.
class AuthorityKey {
  AuthorityKey(List<int> bytes) : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;

  @override
  bool operator ==(Object other) {
    if (other is! AuthorityKey) return false;
    if (bytes.length != other.bytes.length) return false;
    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] != other.bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    int h = 0x811c9dc5;
    for (final int b in bytes) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }
}
