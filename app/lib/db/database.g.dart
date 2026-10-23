// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $EventsTable extends Events with TableInfo<$EventsTable, Event> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<Uint8List> eventId = GeneratedColumn<Uint8List>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorPubkeyMeta = const VerificationMeta(
    'authorPubkey',
  );
  @override
  late final GeneratedColumn<Uint8List> authorPubkey =
      GeneratedColumn<Uint8List>(
        'author_pubkey',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lamportMeta = const VerificationMeta(
    'lamport',
  );
  @override
  late final GeneratedColumn<int> lamport = GeneratedColumn<int>(
    'lamport',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prevEventIdMeta = const VerificationMeta(
    'prevEventId',
  );
  @override
  late final GeneratedColumn<Uint8List> prevEventId =
      GeneratedColumn<Uint8List>(
        'prev_event_id',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _h3CellMeta = const VerificationMeta('h3Cell');
  @override
  late final GeneratedColumn<int> h3Cell = GeneratedColumn<int>(
    'h3_cell',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rawMeta = const VerificationMeta('raw');
  @override
  late final GeneratedColumn<Uint8List> raw = GeneratedColumn<Uint8List>(
    'raw',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _validMeta = const VerificationMeta('valid');
  @override
  late final GeneratedColumn<bool> valid = GeneratedColumn<bool>(
    'valid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("valid" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    type,
    authorPubkey,
    lamport,
    prevEventId,
    createdAtMs,
    h3Cell,
    raw,
    valid,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<Event> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('author_pubkey')) {
      context.handle(
        _authorPubkeyMeta,
        authorPubkey.isAcceptableOrUnknown(
          data['author_pubkey']!,
          _authorPubkeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_authorPubkeyMeta);
    }
    if (data.containsKey('lamport')) {
      context.handle(
        _lamportMeta,
        lamport.isAcceptableOrUnknown(data['lamport']!, _lamportMeta),
      );
    } else if (isInserting) {
      context.missing(_lamportMeta);
    }
    if (data.containsKey('prev_event_id')) {
      context.handle(
        _prevEventIdMeta,
        prevEventId.isAcceptableOrUnknown(
          data['prev_event_id']!,
          _prevEventIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    }
    if (data.containsKey('h3_cell')) {
      context.handle(
        _h3CellMeta,
        h3Cell.isAcceptableOrUnknown(data['h3_cell']!, _h3CellMeta),
      );
    }
    if (data.containsKey('raw')) {
      context.handle(
        _rawMeta,
        raw.isAcceptableOrUnknown(data['raw']!, _rawMeta),
      );
    } else if (isInserting) {
      context.missing(_rawMeta);
    }
    if (data.containsKey('valid')) {
      context.handle(
        _validMeta,
        valid.isAcceptableOrUnknown(data['valid']!, _validMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  Event map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Event(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}event_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      authorPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}author_pubkey'],
      )!,
      lamport: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lamport'],
      )!,
      prevEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}prev_event_id'],
      ),
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      h3Cell: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}h3_cell'],
      )!,
      raw: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}raw'],
      )!,
      valid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}valid'],
      )!,
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }
}

class Event extends DataClass implements Insertable<Event> {
  /// 32-byte BLAKE2b-256 content hash. Primary key / dedup key / DAG id.
  final Uint8List eventId;

  /// [EventType] enum value (header.type).
  final int type;

  /// Author's 32-byte Ed25519 public key (header.author_pubkey).
  final Uint8List authorPubkey;

  /// Lamport logical clock (header.lamport). Stored as an integer; values are
  /// conceptually uint64 but stay well within SQLite's signed 64-bit range for
  /// realistic event counts.
  final int lamport;

  /// Author's previous event id (per-author hash chain). Nullable/empty for the
  /// author's first event.
  final Uint8List? prevEventId;

  /// Advisory wall-clock millis (header.created_at_ms). Freshness UI only.
  final int createdAtMs;

  /// Optional coarse H3 geospatial bucket (header.h3_cell).
  final int h3Cell;

  /// The full `SignedEvent.writeToBuffer()` bytes, stored verbatim.
  final Uint8List raw;

  /// Whether this event passed signature + hash verification at insert time.
  final bool valid;
  const Event({
    required this.eventId,
    required this.type,
    required this.authorPubkey,
    required this.lamport,
    this.prevEventId,
    required this.createdAtMs,
    required this.h3Cell,
    required this.raw,
    required this.valid,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<Uint8List>(eventId);
    map['type'] = Variable<int>(type);
    map['author_pubkey'] = Variable<Uint8List>(authorPubkey);
    map['lamport'] = Variable<int>(lamport);
    if (!nullToAbsent || prevEventId != null) {
      map['prev_event_id'] = Variable<Uint8List>(prevEventId);
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['h3_cell'] = Variable<int>(h3Cell);
    map['raw'] = Variable<Uint8List>(raw);
    map['valid'] = Variable<bool>(valid);
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      eventId: Value(eventId),
      type: Value(type),
      authorPubkey: Value(authorPubkey),
      lamport: Value(lamport),
      prevEventId: prevEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(prevEventId),
      createdAtMs: Value(createdAtMs),
      h3Cell: Value(h3Cell),
      raw: Value(raw),
      valid: Value(valid),
    );
  }

  factory Event.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Event(
      eventId: serializer.fromJson<Uint8List>(json['eventId']),
      type: serializer.fromJson<int>(json['type']),
      authorPubkey: serializer.fromJson<Uint8List>(json['authorPubkey']),
      lamport: serializer.fromJson<int>(json['lamport']),
      prevEventId: serializer.fromJson<Uint8List?>(json['prevEventId']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      h3Cell: serializer.fromJson<int>(json['h3Cell']),
      raw: serializer.fromJson<Uint8List>(json['raw']),
      valid: serializer.fromJson<bool>(json['valid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<Uint8List>(eventId),
      'type': serializer.toJson<int>(type),
      'authorPubkey': serializer.toJson<Uint8List>(authorPubkey),
      'lamport': serializer.toJson<int>(lamport),
      'prevEventId': serializer.toJson<Uint8List?>(prevEventId),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'h3Cell': serializer.toJson<int>(h3Cell),
      'raw': serializer.toJson<Uint8List>(raw),
      'valid': serializer.toJson<bool>(valid),
    };
  }

  Event copyWith({
    Uint8List? eventId,
    int? type,
    Uint8List? authorPubkey,
    int? lamport,
    Value<Uint8List?> prevEventId = const Value.absent(),
    int? createdAtMs,
    int? h3Cell,
    Uint8List? raw,
    bool? valid,
  }) => Event(
    eventId: eventId ?? this.eventId,
    type: type ?? this.type,
    authorPubkey: authorPubkey ?? this.authorPubkey,
    lamport: lamport ?? this.lamport,
    prevEventId: prevEventId.present ? prevEventId.value : this.prevEventId,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    h3Cell: h3Cell ?? this.h3Cell,
    raw: raw ?? this.raw,
    valid: valid ?? this.valid,
  );
  Event copyWithCompanion(EventsCompanion data) {
    return Event(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      type: data.type.present ? data.type.value : this.type,
      authorPubkey: data.authorPubkey.present
          ? data.authorPubkey.value
          : this.authorPubkey,
      lamport: data.lamport.present ? data.lamport.value : this.lamport,
      prevEventId: data.prevEventId.present
          ? data.prevEventId.value
          : this.prevEventId,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      h3Cell: data.h3Cell.present ? data.h3Cell.value : this.h3Cell,
      raw: data.raw.present ? data.raw.value : this.raw,
      valid: data.valid.present ? data.valid.value : this.valid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Event(')
          ..write('eventId: $eventId, ')
          ..write('type: $type, ')
          ..write('authorPubkey: $authorPubkey, ')
          ..write('lamport: $lamport, ')
          ..write('prevEventId: $prevEventId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('h3Cell: $h3Cell, ')
          ..write('raw: $raw, ')
          ..write('valid: $valid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    $driftBlobEquality.hash(eventId),
    type,
    $driftBlobEquality.hash(authorPubkey),
    lamport,
    $driftBlobEquality.hash(prevEventId),
    createdAtMs,
    h3Cell,
    $driftBlobEquality.hash(raw),
    valid,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Event &&
          $driftBlobEquality.equals(other.eventId, this.eventId) &&
          other.type == this.type &&
          $driftBlobEquality.equals(other.authorPubkey, this.authorPubkey) &&
          other.lamport == this.lamport &&
          $driftBlobEquality.equals(other.prevEventId, this.prevEventId) &&
          other.createdAtMs == this.createdAtMs &&
          other.h3Cell == this.h3Cell &&
          $driftBlobEquality.equals(other.raw, this.raw) &&
          other.valid == this.valid);
}

class EventsCompanion extends UpdateCompanion<Event> {
  final Value<Uint8List> eventId;
  final Value<int> type;
  final Value<Uint8List> authorPubkey;
  final Value<int> lamport;
  final Value<Uint8List?> prevEventId;
  final Value<int> createdAtMs;
  final Value<int> h3Cell;
  final Value<Uint8List> raw;
  final Value<bool> valid;
  final Value<int> rowid;
  const EventsCompanion({
    this.eventId = const Value.absent(),
    this.type = const Value.absent(),
    this.authorPubkey = const Value.absent(),
    this.lamport = const Value.absent(),
    this.prevEventId = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.h3Cell = const Value.absent(),
    this.raw = const Value.absent(),
    this.valid = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventsCompanion.insert({
    required Uint8List eventId,
    required int type,
    required Uint8List authorPubkey,
    required int lamport,
    this.prevEventId = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.h3Cell = const Value.absent(),
    required Uint8List raw,
    this.valid = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       type = Value(type),
       authorPubkey = Value(authorPubkey),
       lamport = Value(lamport),
       raw = Value(raw);
  static Insertable<Event> custom({
    Expression<Uint8List>? eventId,
    Expression<int>? type,
    Expression<Uint8List>? authorPubkey,
    Expression<int>? lamport,
    Expression<Uint8List>? prevEventId,
    Expression<int>? createdAtMs,
    Expression<int>? h3Cell,
    Expression<Uint8List>? raw,
    Expression<bool>? valid,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (type != null) 'type': type,
      if (authorPubkey != null) 'author_pubkey': authorPubkey,
      if (lamport != null) 'lamport': lamport,
      if (prevEventId != null) 'prev_event_id': prevEventId,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (h3Cell != null) 'h3_cell': h3Cell,
      if (raw != null) 'raw': raw,
      if (valid != null) 'valid': valid,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventsCompanion copyWith({
    Value<Uint8List>? eventId,
    Value<int>? type,
    Value<Uint8List>? authorPubkey,
    Value<int>? lamport,
    Value<Uint8List?>? prevEventId,
    Value<int>? createdAtMs,
    Value<int>? h3Cell,
    Value<Uint8List>? raw,
    Value<bool>? valid,
    Value<int>? rowid,
  }) {
    return EventsCompanion(
      eventId: eventId ?? this.eventId,
      type: type ?? this.type,
      authorPubkey: authorPubkey ?? this.authorPubkey,
      lamport: lamport ?? this.lamport,
      prevEventId: prevEventId ?? this.prevEventId,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      h3Cell: h3Cell ?? this.h3Cell,
      raw: raw ?? this.raw,
      valid: valid ?? this.valid,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<Uint8List>(eventId.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (authorPubkey.present) {
      map['author_pubkey'] = Variable<Uint8List>(authorPubkey.value);
    }
    if (lamport.present) {
      map['lamport'] = Variable<int>(lamport.value);
    }
    if (prevEventId.present) {
      map['prev_event_id'] = Variable<Uint8List>(prevEventId.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (h3Cell.present) {
      map['h3_cell'] = Variable<int>(h3Cell.value);
    }
    if (raw.present) {
      map['raw'] = Variable<Uint8List>(raw.value);
    }
    if (valid.present) {
      map['valid'] = Variable<bool>(valid.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('type: $type, ')
          ..write('authorPubkey: $authorPubkey, ')
          ..write('lamport: $lamport, ')
          ..write('prevEventId: $prevEventId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('h3Cell: $h3Cell, ')
          ..write('raw: $raw, ')
          ..write('valid: $valid, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KeyValueTable extends KeyValue
    with TableInfo<$KeyValueTable, KeyValueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KeyValueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<Uint8List> value = GeneratedColumn<Uint8List>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'key_value';
  @override
  VerificationContext validateIntegrity(
    Insertable<KeyValueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KeyValueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KeyValueData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $KeyValueTable createAlias(String alias) {
    return $KeyValueTable(attachedDatabase, alias);
  }
}

class KeyValueData extends DataClass implements Insertable<KeyValueData> {
  final String key;
  final Uint8List value;
  const KeyValueData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<Uint8List>(value);
    return map;
  }

  KeyValueCompanion toCompanion(bool nullToAbsent) {
    return KeyValueCompanion(key: Value(key), value: Value(value));
  }

  factory KeyValueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KeyValueData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<Uint8List>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<Uint8List>(value),
    };
  }

  KeyValueData copyWith({String? key, Uint8List? value}) =>
      KeyValueData(key: key ?? this.key, value: value ?? this.value);
  KeyValueData copyWithCompanion(KeyValueCompanion data) {
    return KeyValueData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KeyValueData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, $driftBlobEquality.hash(value));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyValueData &&
          other.key == this.key &&
          $driftBlobEquality.equals(other.value, this.value));
}

class KeyValueCompanion extends UpdateCompanion<KeyValueData> {
  final Value<String> key;
  final Value<Uint8List> value;
  final Value<int> rowid;
  const KeyValueCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KeyValueCompanion.insert({
    required String key,
    required Uint8List value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<KeyValueData> custom({
    Expression<String>? key,
    Expression<Uint8List>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KeyValueCompanion copyWith({
    Value<String>? key,
    Value<Uint8List>? value,
    Value<int>? rowid,
  }) {
    return KeyValueCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<Uint8List>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KeyValueCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EventsTable events = $EventsTable(this);
  late final $KeyValueTable keyValue = $KeyValueTable(this);
  late final EventDao eventDao = EventDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [events, keyValue];
}

typedef $$EventsTableCreateCompanionBuilder =
    EventsCompanion Function({
      required Uint8List eventId,
      required int type,
      required Uint8List authorPubkey,
      required int lamport,
      Value<Uint8List?> prevEventId,
      Value<int> createdAtMs,
      Value<int> h3Cell,
      required Uint8List raw,
      Value<bool> valid,
      Value<int> rowid,
    });
typedef $$EventsTableUpdateCompanionBuilder =
    EventsCompanion Function({
      Value<Uint8List> eventId,
      Value<int> type,
      Value<Uint8List> authorPubkey,
      Value<int> lamport,
      Value<Uint8List?> prevEventId,
      Value<int> createdAtMs,
      Value<int> h3Cell,
      Value<Uint8List> raw,
      Value<bool> valid,
      Value<int> rowid,
    });

class $$EventsTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get authorPubkey => $composableBuilder(
    column: $table.authorPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lamport => $composableBuilder(
    column: $table.lamport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get prevEventId => $composableBuilder(
    column: $table.prevEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get h3Cell => $composableBuilder(
    column: $table.h3Cell,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get raw => $composableBuilder(
    column: $table.raw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get valid => $composableBuilder(
    column: $table.valid,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get authorPubkey => $composableBuilder(
    column: $table.authorPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lamport => $composableBuilder(
    column: $table.lamport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get prevEventId => $composableBuilder(
    column: $table.prevEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get h3Cell => $composableBuilder(
    column: $table.h3Cell,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get raw => $composableBuilder(
    column: $table.raw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get valid => $composableBuilder(
    column: $table.valid,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<Uint8List> get authorPubkey => $composableBuilder(
    column: $table.authorPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lamport =>
      $composableBuilder(column: $table.lamport, builder: (column) => column);

  GeneratedColumn<Uint8List> get prevEventId => $composableBuilder(
    column: $table.prevEventId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get h3Cell =>
      $composableBuilder(column: $table.h3Cell, builder: (column) => column);

  GeneratedColumn<Uint8List> get raw =>
      $composableBuilder(column: $table.raw, builder: (column) => column);

  GeneratedColumn<bool> get valid =>
      $composableBuilder(column: $table.valid, builder: (column) => column);
}

class $$EventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsTable,
          Event,
          $$EventsTableFilterComposer,
          $$EventsTableOrderingComposer,
          $$EventsTableAnnotationComposer,
          $$EventsTableCreateCompanionBuilder,
          $$EventsTableUpdateCompanionBuilder,
          (Event, BaseReferences<_$AppDatabase, $EventsTable, Event>),
          Event,
          PrefetchHooks Function()
        > {
  $$EventsTableTableManager(_$AppDatabase db, $EventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Uint8List> eventId = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<Uint8List> authorPubkey = const Value.absent(),
                Value<int> lamport = const Value.absent(),
                Value<Uint8List?> prevEventId = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> h3Cell = const Value.absent(),
                Value<Uint8List> raw = const Value.absent(),
                Value<bool> valid = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion(
                eventId: eventId,
                type: type,
                authorPubkey: authorPubkey,
                lamport: lamport,
                prevEventId: prevEventId,
                createdAtMs: createdAtMs,
                h3Cell: h3Cell,
                raw: raw,
                valid: valid,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required Uint8List eventId,
                required int type,
                required Uint8List authorPubkey,
                required int lamport,
                Value<Uint8List?> prevEventId = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> h3Cell = const Value.absent(),
                required Uint8List raw,
                Value<bool> valid = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion.insert(
                eventId: eventId,
                type: type,
                authorPubkey: authorPubkey,
                lamport: lamport,
                prevEventId: prevEventId,
                createdAtMs: createdAtMs,
                h3Cell: h3Cell,
                raw: raw,
                valid: valid,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EventsTable, Event>(table),
                  BaseReferences<_$AppDatabase, $EventsTable, Event>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsTable,
      Event,
      $$EventsTableFilterComposer,
      $$EventsTableOrderingComposer,
      $$EventsTableAnnotationComposer,
      $$EventsTableCreateCompanionBuilder,
      $$EventsTableUpdateCompanionBuilder,
      (Event, BaseReferences<_$AppDatabase, $EventsTable, Event>),
      Event,
      PrefetchHooks Function()
    >;
typedef $$KeyValueTableCreateCompanionBuilder =
    KeyValueCompanion Function({
      required String key,
      required Uint8List value,
      Value<int> rowid,
    });
typedef $$KeyValueTableUpdateCompanionBuilder =
    KeyValueCompanion Function({
      Value<String> key,
      Value<Uint8List> value,
      Value<int> rowid,
    });

class $$KeyValueTableFilterComposer
    extends Composer<_$AppDatabase, $KeyValueTable> {
  $$KeyValueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KeyValueTableOrderingComposer
    extends Composer<_$AppDatabase, $KeyValueTable> {
  $$KeyValueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KeyValueTableAnnotationComposer
    extends Composer<_$AppDatabase, $KeyValueTable> {
  $$KeyValueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<Uint8List> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KeyValueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KeyValueTable,
          KeyValueData,
          $$KeyValueTableFilterComposer,
          $$KeyValueTableOrderingComposer,
          $$KeyValueTableAnnotationComposer,
          $$KeyValueTableCreateCompanionBuilder,
          $$KeyValueTableUpdateCompanionBuilder,
          (
            KeyValueData,
            BaseReferences<_$AppDatabase, $KeyValueTable, KeyValueData>,
          ),
          KeyValueData,
          PrefetchHooks Function()
        > {
  $$KeyValueTableTableManager(_$AppDatabase db, $KeyValueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KeyValueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KeyValueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KeyValueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<Uint8List> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KeyValueCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required Uint8List value,
                Value<int> rowid = const Value.absent(),
              }) => KeyValueCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KeyValueTable, KeyValueData>(table),
                  BaseReferences<_$AppDatabase, $KeyValueTable, KeyValueData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KeyValueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KeyValueTable,
      KeyValueData,
      $$KeyValueTableFilterComposer,
      $$KeyValueTableOrderingComposer,
      $$KeyValueTableAnnotationComposer,
      $$KeyValueTableCreateCompanionBuilder,
      $$KeyValueTableUpdateCompanionBuilder,
      (
        KeyValueData,
        BaseReferences<_$AppDatabase, $KeyValueTable, KeyValueData>,
      ),
      KeyValueData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$KeyValueTableTableManager get keyValue =>
      $$KeyValueTableTableManager(_db, _db.keyValue);
}
