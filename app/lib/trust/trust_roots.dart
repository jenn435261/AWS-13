import 'dart:typed_data';

import '../db/event_dao.dart' show AuthorKey;

/// Holds the set of organization *root* public keys that this device trusts as
/// anchors for the verified-org certificate chain (spec §9: SOURCE dimension).
///
/// A root is the top of an org PKI: a certificate authority whose signature
/// (transitively, via [OrgCertificateBody] events) confers the
/// `PROVENANCE_KIND_VERIFIED_ORG` badge on a subject pubkey. Roots are *not*
/// discovered from the event log — that would let anyone mint their own badge.
/// They are provisioned out-of-band: seeded here at build time and later
/// populated from a signed "readiness package" distributed to responders.
///
/// The store is intentionally tiny and pure: it answers one question,
/// [isTrustedRoot], and lets callers [add] roots as a readiness package is
/// ingested.
class TrustRootStore {
  final Set<AuthorKey> _roots = <AuthorKey>{};

  /// Creates a store seeded with an initial list of trusted root pubkeys.
  ///
  /// Each entry is the raw 32-byte Ed25519 public key of an org root.
  TrustRootStore({Iterable<List<int>> seed = const <List<int>>[]}) {
    for (final List<int> root in seed) {
      add(root);
    }
  }

  /// Adds [pubkey] as a trusted root. Idempotent.
  void add(List<int> pubkey) {
    if (pubkey.isEmpty) return;
    _roots.add(AuthorKey(pubkey));
  }

  /// Removes [pubkey] from the trusted roots. Idempotent.
  void remove(List<int> pubkey) => _roots.remove(AuthorKey(pubkey));

  /// Adds every pubkey in [pubkeys] as a trusted root (e.g. when applying a
  /// readiness package).
  void addAll(Iterable<List<int>> pubkeys) {
    for (final List<int> p in pubkeys) {
      add(p);
    }
  }

  /// Whether [pubkey] is one of the trusted org roots.
  bool isTrustedRoot(List<int> pubkey) {
    if (pubkey.isEmpty) return false;
    return _roots.contains(AuthorKey(pubkey));
  }

  /// The number of trusted roots currently held.
  int get length => _roots.length;

  /// A defensive copy of the trusted roots as byte lists.
  List<Uint8List> get roots =>
      _roots.map((AuthorKey k) => Uint8List.fromList(k.bytes)).toList();
}
