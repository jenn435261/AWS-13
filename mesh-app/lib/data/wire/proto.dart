import 'dart:convert';
import 'dart:typed_data';

/// The few protobuf wire rules the app needs to speak the team's
/// `resilience.v1` messages, without generated code.
///
/// Canonical form, matching the Node's deterministic encoder: fields in
/// ascending number order, proto3 defaults (0, false, empty) left out.
/// Integers stay below 2^53 so the same bytes come out on the web.
class ProtoWriter {
  final _out = BytesBuilder(copy: false);

  void _varint(int value) {
    assert(value >= 0, 'negative varints are not used on this wire');
    var v = value;
    while (v >= 0x80) {
      _out.addByte((v % 0x80) | 0x80);
      v = v ~/ 0x80;
    }
    _out.addByte(v);
  }

  void _tag(int field, int wireType) => _varint(field * 8 + wireType);

  /// uint32, uint64, int64 (non-negative), enum.
  void uint(int field, int value) {
    if (value == 0) return;
    _tag(field, 0);
    _varint(value);
  }

  void boolean(int field, bool value) {
    if (!value) return;
    _tag(field, 0);
    _varint(1);
  }

  void float64(int field, double value) {
    if (value == 0 && !value.isNegative) return;
    _tag(field, 1);
    _out.add(
      (ByteData(8)..setFloat64(0, value, Endian.little)).buffer.asUint8List(),
    );
  }

  void bytes(int field, List<int> value) {
    if (value.isEmpty) return;
    _lengthDelimited(field, value);
  }

  void string(int field, String value) => bytes(field, utf8.encode(value));

  /// An embedded message. Unlike scalars, a present message is written
  /// even when it is empty.
  void message(int field, List<int>? encoded) {
    if (encoded == null) return;
    _lengthDelimited(field, encoded);
  }

  /// `repeated bytes` / `repeated Message`: one entry per element, kept in
  /// order, empty elements included.
  void repeated(int field, Iterable<List<int>> values) {
    for (final v in values) {
      _lengthDelimited(field, v);
    }
  }

  /// `repeated` enums and integers, packed as proto3 does by default.
  void packed(int field, Iterable<int> values) {
    if (values.isEmpty) return;
    final inner = ProtoWriter();
    values.forEach(inner._varint);
    _lengthDelimited(field, inner.done());
  }

  void _lengthDelimited(int field, List<int> value) {
    _tag(field, 2);
    _varint(value.length);
    _out.add(value);
  }

  Uint8List done() => _out.toBytes();
}

/// Thrown for bytes that are not a valid protobuf message.
class ProtoFormatException implements Exception {
  const ProtoFormatException(this.message);

  final String message;

  @override
  String toString() => 'ProtoFormatException: $message';
}

/// Reads every field of one message. Repeated fields keep their order.
class ProtoReader {
  ProtoReader(List<int> data) {
    final bytes = data is Uint8List ? data : Uint8List.fromList(data);
    var i = 0;
    int varint() {
      var result = 0;
      var scale = 1;
      // Ten bytes is the longest a 64-bit varint can be.
      for (var n = 0; n < 10; n++) {
        if (i >= bytes.length) throw const ProtoFormatException('truncated varint');
        final b = bytes[i++];
        result += (b & 0x7f) * scale;
        if (b < 0x80) return result;
        scale *= 0x80;
      }
      throw const ProtoFormatException('varint too long');
    }

    Uint8List take(int n) {
      if (n < 0 || i + n > bytes.length) {
        throw const ProtoFormatException('truncated field');
      }
      final out = Uint8List.sublistView(bytes, i, i + n);
      i += n;
      return out;
    }

    while (i < bytes.length) {
      final key = varint();
      final field = key ~/ 8;
      if (field == 0) throw const ProtoFormatException('field number 0');
      final Object value = switch (key % 8) {
        0 => varint(),
        1 => take(8),
        2 => take(varint()),
        5 => take(4),
        _ => throw ProtoFormatException('wire type ${key % 8}'),
      };
      (_fields[field] ??= []).add(value);
    }
  }

  final _fields = <int, List<Object>>{};

  bool has(int field) => _fields.containsKey(field);

  int uint(int field) {
    final v = _fields[field]?.last;
    return v is int ? v : 0;
  }

  bool boolean(int field) => uint(field) != 0;

  double float64(int field) {
    final v = _fields[field]?.last;
    if (v is! Uint8List || v.length != 8) return 0;
    return ByteData.sublistView(v).getFloat64(0, Endian.little);
  }

  Uint8List bytes(int field) {
    final v = _fields[field]?.last;
    return v is Uint8List ? Uint8List.fromList(v) : Uint8List(0);
  }

  String string(int field) => utf8.decode(bytes(field), allowMalformed: true);

  /// The embedded message at [field], or null when it is absent.
  ProtoReader? message(int field) =>
      has(field) ? ProtoReader(bytes(field)) : null;

  List<Uint8List> repeated(int field) => [
        for (final v in _fields[field] ?? const <Object>[])
          if (v is Uint8List) Uint8List.fromList(v),
      ];

  /// A repeated integer field, packed or not.
  List<int> packed(int field) {
    final out = <int>[];
    for (final v in _fields[field] ?? const <Object>[]) {
      if (v is int) {
        out.add(v);
      } else if (v is Uint8List) {
        out.addAll(_unpack(v));
      }
    }
    return out;
  }

  /// Consecutive varints, as a packed field holds them.
  static List<int> _unpack(Uint8List run) {
    final out = <int>[];
    var i = 0;
    while (i < run.length) {
      var result = 0;
      var scale = 1;
      while (true) {
        if (i >= run.length) throw const ProtoFormatException('truncated packed varint');
        final b = run[i++];
        result += (b & 0x7f) * scale;
        if (b < 0x80) break;
        scale *= 0x80;
      }
      out.add(result);
    }
    return out;
  }
}
