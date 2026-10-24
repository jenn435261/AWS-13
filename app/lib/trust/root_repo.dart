import '../db/json_store.dart';

/// A trusted organization root the user chose to trust on this device.
class TrustedRoot {
  final String hex; // 32-byte Ed25519 public key, lowercase hex
  final String name;
  final int addedMs;
  const TrustedRoot(this.hex, this.name, this.addedMs);

  List<int> get bytes => [
        for (var i = 0; i + 1 < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16)
      ];
}

String toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Persists which org roots this device trusts. Trusting a root is a local,
/// deliberate decision (never learned from the event log, which would let
/// anyone mint their own badge); this keeps that decision across restarts.
class TrustRootRepo {
  TrustRootRepo(this._store);
  final JsonStore _store;

  Future<List<TrustedRoot>> list() async {
    final out = <TrustedRoot>[];
    for (final j in await _store.all()) {
      final hex = j['hex'];
      if (hex is String && hex.length == 64) {
        out.add(TrustedRoot(hex, j['name'] as String? ?? '',
            (j['addedMs'] as num?)?.toInt() ?? 0));
      }
    }
    out.sort((a, b) => a.addedMs.compareTo(b.addedMs));
    return out;
  }

  Future<void> add(List<int> pubkey, String name) => _store.put(
      toHex(pubkey), {
        'hex': toHex(pubkey),
        'name': name,
        'addedMs': DateTime.now().millisecondsSinceEpoch
      });

  Future<void> remove(List<int> pubkey) => _store.delete(toHex(pubkey));
}
