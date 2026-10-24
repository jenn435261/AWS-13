
import 'package:drift/drift.dart';

import '../db/database.dart';
import 'identity_card.dart';

/// Persists the public identity cards of the people this user has added.
///
/// A contact is a cryptographic identity (never a phone number), so the whole
/// record is just the card's protobuf bytes, keyed by Resilience ID, in the
/// existing KeyValue table. Nothing here is secret.
class ContactStore {
  ContactStore(this._db);

  final AppDatabase _db;

  static const String _prefix = 'contact:';

  /// All saved contacts, ordered by display name.
  Future<List<IdentityCard>> list() async {
    final rows = await (_db.select(_db.keyValue)
          ..where((t) => t.key.like('$_prefix%')))
        .get();
    final cards = <IdentityCard>[];
    for (final r in rows) {
      try {
        cards.add(IdentityCard.fromBytes(r.value));
      } catch (_) {
        // A corrupt row must never break the contacts screen.
      }
    }
    cards.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return cards;
  }

  /// Saves [card]. Returns false when it is already saved (idempotent).
  Future<bool> add(IdentityCard card) async {
    final key = '$_prefix${card.resilienceId}';
    final existing = await (_db.select(_db.keyValue)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    if (existing != null) return false;
    await _db.into(_db.keyValue).insert(KeyValueCompanion.insert(
        key: key, value: Uint8List.fromList(card.toBytes())));
    return true;
  }

  Future<void> remove(String resilienceId) =>
      (_db.delete(_db.keyValue)..where((t) => t.key.equals('$_prefix$resilienceId')))
          .go();
}
