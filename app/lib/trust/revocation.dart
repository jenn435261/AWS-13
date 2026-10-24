import '../db/event_dao.dart' show AuthorKey;
import '../gen/resilience/v1/event.pb.dart';

/// The set of public keys that have been revoked, folded from
/// `EVENT_TYPE_KEY_REVOKED` events in the log.
///
/// A revocation is a signed claim that a key should no longer be trusted (e.g.
/// a device was lost, or an org de-authorized a responder). Once a key is
/// revoked it loses any verified-org provenance (spec §9): the trust engine
/// falls its SOURCE dimension back to community.
///
/// We keep the *earliest* revocation timestamp per key. Revocation is
/// monotonic — a key cannot be "un-revoked" by a later event — and the UI wants
/// to show when the key was first revoked (feeds the freshness/age display).
class RevocationSet {
  /// revoked pubkey -> earliest observed revocation timestamp (unix millis).
  final Map<AuthorKey, int> _revoked = <AuthorKey, int>{};

  RevocationSet._();

  /// Builds a [RevocationSet] by folding every `KEY_REVOKED` event in [events].
  ///
  /// [events] is the full (verified) event log; non-revocation events are
  /// ignored. Order-independent: applying the same events in any order yields
  /// the same set.
  factory RevocationSet.fromEvents(Iterable<SignedEvent> events) {
    final RevocationSet set = RevocationSet._();
    for (final SignedEvent e in events) {
      set.apply(e);
    }
    return set;
  }

  /// Folds a single event into the set. Non-revocation events are no-ops, so
  /// this is safe to call as an incremental update from the projection layer.
  void apply(SignedEvent event) {
    if (event.header.type != EventType.EVENT_TYPE_KEY_REVOKED) return;
    final KeyRevokedBody body;
    try {
      body = KeyRevokedBody.fromBuffer(event.body);
    } catch (_) {
      return;
    }
    if (body.revokedPubkey.isEmpty) return;

    // Prefer the body's declared revocation time; fall back to the event's
    // advisory creation time when the body omits it.
    final int ts = body.hasRevokedAtMs()
        ? body.revokedAtMs.toInt()
        : event.header.createdAtMs.toInt();

    final AuthorKey key = AuthorKey(body.revokedPubkey);
    final int? existing = _revoked[key];
    if (existing == null || ts < existing) {
      _revoked[key] = ts;
    }
  }

  /// Whether [pubkey] has been revoked.
  bool isRevoked(List<int> pubkey) {
    if (pubkey.isEmpty) return false;
    return _revoked.containsKey(AuthorKey(pubkey));
  }

  /// The timestamp (unix millis) at which [pubkey] was first revoked, or `null`
  /// if it has not been revoked. Exposed for the freshness/age UI.
  int? revokedAtMs(List<int> pubkey) {
    if (pubkey.isEmpty) return null;
    return _revoked[AuthorKey(pubkey)];
  }

  /// The number of revoked keys.
  int get length => _revoked.length;
}
