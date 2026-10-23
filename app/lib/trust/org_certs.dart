import '../db/event_dao.dart' show AuthorKey;
import '../gen/resilience/v1/event.pb.dart';
import 'revocation.dart';
import 'trust_roots.dart';

/// Folds `ORG_CERTIFICATE` (and `IDENTITY_CERTIFICATE`) events into a directed
/// certificate graph, then answers the SOURCE question of the trust model:
/// is a given author a *verified organization* or merely *community*?
///
/// A certificate is an edge `issuer -> subject`: the issuer vouches that the
/// subject belongs to its organization. An author is VERIFIED_ORG iff there is
/// a chain of such edges from some pubkey in [TrustRootStore] down to the
/// author, every link is issued by a non-revoked key, and the author itself is
/// not revoked (spec §9). Otherwise the author is COMMUNITY — the default, and
/// never an error state (low trust stays visible, it is just not badged).
///
/// We never collapse this into a numeric score; it is one of the three
/// independent dimensions the UI surfaces.
class OrgCertGraph {
  /// subject pubkey -> the set of issuer pubkeys that certified it.
  final Map<AuthorKey, Set<AuthorKey>> _issuers =
      <AuthorKey, Set<AuthorKey>>{};

  OrgCertGraph._();

  /// Builds the graph by folding every certificate event in [events].
  factory OrgCertGraph.fromEvents(Iterable<SignedEvent> events) {
    final OrgCertGraph g = OrgCertGraph._();
    for (final SignedEvent e in events) {
      g.apply(e);
    }
    return g;
  }

  /// Folds a single event. Non-certificate events are no-ops so this can be
  /// used for incremental projection updates.
  void apply(SignedEvent event) {
    switch (event.header.type) {
      case EventType.EVENT_TYPE_ORG_CERTIFICATE:
        _applyOrgCert(event);
        break;
      case EventType.EVENT_TYPE_IDENTITY_CERTIFICATE:
        _applyIdentityCert(event);
        break;
      default:
        break;
    }
  }

  void _applyOrgCert(SignedEvent event) {
    final OrgCertificateBody body;
    try {
      body = OrgCertificateBody.fromBuffer(event.body);
    } catch (_) {
      return;
    }
    if (body.subjectPubkey.isEmpty) return;

    // The issuer is whoever signed the certificate event (the author). The
    // body also names an org root; we record the author as the issuing edge so
    // a chain can be walked from a trusted root. When the author signs on
    // behalf of a root it holds, root == author for a direct certification.
    final List<int> issuer = event.header.authorPubkey;
    _addEdge(issuer: issuer, subject: body.subjectPubkey);

    // If the body explicitly carries the org root and it differs from the
    // author, also record root -> author so a direct root-signed cert chains
    // even when the root key is the declared anchor rather than the signer.
    if (body.orgRootPubkey.isNotEmpty &&
        !_bytesEqual(body.orgRootPubkey, issuer)) {
      _addEdge(issuer: body.orgRootPubkey, subject: issuer);
    }
  }

  void _applyIdentityCert(SignedEvent event) {
    // An identity certificate is self-asserted (an author publishing their own
    // signing/display info). It does not, by itself, confer org provenance, so
    // it adds no cross-identity edge. Kept as a recognized type for forward
    // compatibility and so folding the full log is lossless.
  }

  void _addEdge({required List<int> issuer, required List<int> subject}) {
    if (issuer.isEmpty || subject.isEmpty) return;
    final AuthorKey subjectKey = AuthorKey(subject);
    _issuers
        .putIfAbsent(subjectKey, () => <AuthorKey>{})
        .add(AuthorKey(issuer));
  }

  /// Returns the provenance of [authorPubkey].
  ///
  /// `PROVENANCE_KIND_VERIFIED_ORG` iff a valid certificate chain exists from a
  /// trusted root in [roots] to [authorPubkey], every key on that chain
  /// (including the author) is not revoked per [revocations], and no cycle is
  /// followed. Otherwise `PROVENANCE_KIND_COMMUNITY`.
  ProvenanceKind provenanceOf(
    List<int> authorPubkey, {
    required TrustRootStore roots,
    required RevocationSet revocations,
  }) {
    if (authorPubkey.isEmpty) return ProvenanceKind.PROVENANCE_KIND_COMMUNITY;

    // A revoked author can never be verified, regardless of its certs.
    if (revocations.isRevoked(authorPubkey)) {
      return ProvenanceKind.PROVENANCE_KIND_COMMUNITY;
    }

    // A trusted root certifies itself.
    if (roots.isTrustedRoot(authorPubkey)) {
      return ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG;
    }

    // Walk issuer edges upward from the author looking for a trusted root.
    // Depth-first with a visited set to defeat cycles.
    final Set<AuthorKey> visited = <AuthorKey>{};
    final List<AuthorKey> stack = <AuthorKey>[AuthorKey(authorPubkey)];

    while (stack.isNotEmpty) {
      final AuthorKey current = stack.removeLast();
      if (!visited.add(current)) continue;

      // A key on the chain that is revoked breaks that path.
      if (revocations.isRevoked(current.bytes)) continue;

      final Set<AuthorKey>? issuers = _issuers[current];
      if (issuers == null) continue;

      for (final AuthorKey issuer in issuers) {
        if (revocations.isRevoked(issuer.bytes)) continue;
        if (roots.isTrustedRoot(issuer.bytes)) {
          return ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG;
        }
        if (!visited.contains(issuer)) {
          stack.add(issuer);
        }
      }
    }

    return ProvenanceKind.PROVENANCE_KIND_COMMUNITY;
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
