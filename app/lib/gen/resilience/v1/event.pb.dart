// This is a generated file - do not edit.
//
// Generated from resilience/v1/event.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'event.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'event.pbenum.dart';

/// Top-level signed, self-describing unit that travels over every transport.
class SignedEvent extends $pb.GeneratedMessage {
  factory SignedEvent({
    EventHeader? header,
    $core.List<$core.int>? body,
    $core.List<$core.int>? signature,
  }) {
    final result = SignedEvent._();
    if (header != null) result.header = header;
    if (body != null) result.body = body;
    if (signature != null) result.signature = signature;
    return result;
  }

  SignedEvent._();

  factory SignedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SignedEvent()..mergeFromBuffer(data, registry);
  factory SignedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SignedEvent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignedEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: SignedEvent.$_createMessage)
    ..aOM<EventHeader>(1, _omitFieldNames ? '' : 'header',
        subBuilder: EventHeader.$_createMessage)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'body', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignedEvent copyWith(void Function(SignedEvent) updates) =>
      super.copyWith((message) => updates(message as SignedEvent))
          as SignedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SignedEvent() / SignedEvent.new instead')
  static SignedEvent create() => SignedEvent._();
  static $pb.GeneratedMessage $_createMessage() => SignedEvent._();
  @$core.override
  SignedEvent createEmptyInstance() => SignedEvent._();
  @$core.pragma('dart2js:noInline')
  static SignedEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SignedEvent>(
          SignedEvent.$_createMessage);
  static SignedEvent? _defaultInstance;

  /// The canonical event header (hashed + signed).
  @$pb.TagNumber(1)
  EventHeader get header => $_getN(0);
  @$pb.TagNumber(1)
  set header(EventHeader value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHeader() => $_has(0);
  @$pb.TagNumber(1)
  void clearHeader() => $_clearField(1);
  @$pb.TagNumber(1)
  EventHeader ensureHeader() => $_ensure(0);

  /// The opaque event body. One of the *Body messages below, packed as bytes
  /// so relays can forward without understanding the schema. The concrete type
  /// is given by header.type.
  @$pb.TagNumber(2)
  $core.List<$core.int> get body => $_getN(1);
  @$pb.TagNumber(2)
  set body($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBody() => $_has(1);
  @$pb.TagNumber(2)
  void clearBody() => $_clearField(2);

  /// Ed25519 signature over (sha/blake of header || body). 64 bytes.
  @$pb.TagNumber(3)
  $core.List<$core.int> get signature => $_getN(2);
  @$pb.TagNumber(3)
  set signature($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSignature() => $_has(2);
  @$pb.TagNumber(3)
  void clearSignature() => $_clearField(3);
}

class EventHeader extends $pb.GeneratedMessage {
  factory EventHeader({
    $core.List<$core.int>? eventId,
    EventType? type,
    $core.List<$core.int>? authorPubkey,
    $fixnum.Int64? lamport,
    $core.List<$core.int>? prevEventId,
    $core.Iterable<$core.List<$core.int>>? dependsOn,
    $fixnum.Int64? createdAtMs,
    $core.int? schemaVersion,
    $fixnum.Int64? h3Cell,
  }) {
    final result = EventHeader._();
    if (eventId != null) result.eventId = eventId;
    if (type != null) result.type = type;
    if (authorPubkey != null) result.authorPubkey = authorPubkey;
    if (lamport != null) result.lamport = lamport;
    if (prevEventId != null) result.prevEventId = prevEventId;
    if (dependsOn != null) result.dependsOn.addAll(dependsOn);
    if (createdAtMs != null) result.createdAtMs = createdAtMs;
    if (schemaVersion != null) result.schemaVersion = schemaVersion;
    if (h3Cell != null) result.h3Cell = h3Cell;
    return result;
  }

  EventHeader._();

  factory EventHeader.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EventHeader()..mergeFromBuffer(data, registry);
  factory EventHeader.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EventHeader()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EventHeader',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: EventHeader.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'eventId', $pb.PbFieldType.OY)
    ..aE<EventType>(2, _omitFieldNames ? '' : 'type',
        enumValues: EventType.values)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'authorPubkey', $pb.PbFieldType.OY)
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'lamport', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'prevEventId', $pb.PbFieldType.OY)
    ..p<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'dependsOn', $pb.PbFieldType.PY)
    ..aInt64(7, _omitFieldNames ? '' : 'createdAtMs')
    ..aI(8, _omitFieldNames ? '' : 'schemaVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(9, _omitFieldNames ? '' : 'h3Cell', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventHeader clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventHeader copyWith(void Function(EventHeader) updates) =>
      super.copyWith((message) => updates(message as EventHeader))
          as EventHeader;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EventHeader() / EventHeader.new instead')
  static EventHeader create() => EventHeader._();
  static $pb.GeneratedMessage $_createMessage() => EventHeader._();
  @$core.override
  EventHeader createEmptyInstance() => EventHeader._();
  @$core.pragma('dart2js:noInline')
  static EventHeader getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EventHeader>(
          EventHeader.$_createMessage);
  static EventHeader? _defaultInstance;

  /// Content-addressed id: BLAKE2b-256 of canonical(header-without-id || body).
  /// 32 bytes. Primary key, dedup key, and DAG node id.
  @$pb.TagNumber(1)
  $core.List<$core.int> get eventId => $_getN(0);
  @$pb.TagNumber(1)
  set eventId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEventId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEventId() => $_clearField(1);

  /// Event schema/type discriminator for `SignedEvent.body`.
  @$pb.TagNumber(2)
  EventType get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(EventType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  /// Author's Ed25519 public identity key (32 bytes). The signer.
  @$pb.TagNumber(3)
  $core.List<$core.int> get authorPubkey => $_getN(2);
  @$pb.TagNumber(3)
  set authorPubkey($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAuthorPubkey() => $_has(2);
  @$pb.TagNumber(3)
  void clearAuthorPubkey() => $_clearField(3);

  /// Lamport logical clock for causal ordering. Monotonic per author;
  /// max(seen)+1 on creation. Survives wrong wall-clock.
  @$pb.TagNumber(4)
  $fixnum.Int64 get lamport => $_getI64(3);
  @$pb.TagNumber(4)
  set lamport($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLamport() => $_has(3);
  @$pb.TagNumber(4)
  void clearLamport() => $_clearField(4);

  /// Back-reference to the author's previous event id (hash chain per author).
  /// Empty for the author's first event. Enables tamper-evident per-author logs.
  @$pb.TagNumber(5)
  $core.List<$core.int> get prevEventId => $_getN(4);
  @$pb.TagNumber(5)
  set prevEventId($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPrevEventId() => $_has(4);
  @$pb.TagNumber(5)
  void clearPrevEventId() => $_clearField(5);

  /// Additional causal dependencies (ids of events this one references), e.g.
  /// a confirmation references the resource it confirms. Used for DAG ordering.
  @$pb.TagNumber(6)
  $pb.PbList<$core.List<$core.int>> get dependsOn => $_getList(5);

  /// Wall-clock at creation (unix millis), advisory only. Never authoritative
  /// for ordering — used for the freshness/decay UI and tie-breaking.
  @$pb.TagNumber(7)
  $fixnum.Int64 get createdAtMs => $_getI64(6);
  @$pb.TagNumber(7)
  set createdAtMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCreatedAtMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearCreatedAtMs() => $_clearField(7);

  /// Monotonic schema version for forward-compat.
  @$pb.TagNumber(8)
  $core.int get schemaVersion => $_getIZ(7);
  @$pb.TagNumber(8)
  set schemaVersion($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSchemaVersion() => $_has(7);
  @$pb.TagNumber(8)
  void clearSchemaVersion() => $_clearField(8);

  /// Optional opaque H3 cell index (geospatial bucketing) for coarse routing
  /// and "resources near me" without exposing exact coordinates on the wire.
  @$pb.TagNumber(9)
  $fixnum.Int64 get h3Cell => $_getI64(8);
  @$pb.TagNumber(9)
  set h3Cell($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasH3Cell() => $_has(8);
  @$pb.TagNumber(9)
  void clearH3Cell() => $_clearField(9);
}

/// Approximate-by-default location. Exact coords only populated when the author
/// deliberately shares them (e.g. with an assigned courier via a restricted
/// channel). `h3_cell` gives a coarse bucket safe to broadcast.
class GeoPoint extends $pb.GeneratedMessage {
  factory GeoPoint({
    $fixnum.Int64? h3Cell,
    $core.double? approxLat,
    $core.double? approxLon,
    $core.double? exactLat,
    $core.double? exactLon,
    $core.bool? hasExact,
    $core.String? address,
  }) {
    final result = GeoPoint._();
    if (h3Cell != null) result.h3Cell = h3Cell;
    if (approxLat != null) result.approxLat = approxLat;
    if (approxLon != null) result.approxLon = approxLon;
    if (exactLat != null) result.exactLat = exactLat;
    if (exactLon != null) result.exactLon = exactLon;
    if (hasExact != null) result.hasExact = hasExact;
    if (address != null) result.address = address;
    return result;
  }

  GeoPoint._();

  factory GeoPoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GeoPoint()..mergeFromBuffer(data, registry);
  factory GeoPoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GeoPoint()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GeoPoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: GeoPoint.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'h3Cell', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aD(2, _omitFieldNames ? '' : 'approxLat')
    ..aD(3, _omitFieldNames ? '' : 'approxLon')
    ..aD(4, _omitFieldNames ? '' : 'exactLat')
    ..aD(5, _omitFieldNames ? '' : 'exactLon')
    ..aOB(6, _omitFieldNames ? '' : 'hasExact')
    ..aOS(7, _omitFieldNames ? '' : 'address')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GeoPoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GeoPoint copyWith(void Function(GeoPoint) updates) =>
      super.copyWith((message) => updates(message as GeoPoint)) as GeoPoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GeoPoint() / GeoPoint.new instead')
  static GeoPoint create() => GeoPoint._();
  static $pb.GeneratedMessage $_createMessage() => GeoPoint._();
  @$core.override
  GeoPoint createEmptyInstance() => GeoPoint._();
  @$core.pragma('dart2js:noInline')
  static GeoPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GeoPoint>(GeoPoint.$_createMessage);
  static GeoPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get h3Cell => $_getI64(0);
  @$pb.TagNumber(1)
  set h3Cell($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasH3Cell() => $_has(0);
  @$pb.TagNumber(1)
  void clearH3Cell() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get approxLat => $_getN(1);
  @$pb.TagNumber(2)
  set approxLat($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasApproxLat() => $_has(1);
  @$pb.TagNumber(2)
  void clearApproxLat() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get approxLon => $_getN(2);
  @$pb.TagNumber(3)
  set approxLon($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasApproxLon() => $_has(2);
  @$pb.TagNumber(3)
  void clearApproxLon() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get exactLat => $_getN(3);
  @$pb.TagNumber(4)
  set exactLat($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExactLat() => $_has(3);
  @$pb.TagNumber(4)
  void clearExactLat() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get exactLon => $_getN(4);
  @$pb.TagNumber(5)
  set exactLon($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasExactLon() => $_has(4);
  @$pb.TagNumber(5)
  void clearExactLon() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get hasExact => $_getBF(5);
  @$pb.TagNumber(6)
  set hasExact($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHasExact() => $_has(5);
  @$pb.TagNumber(6)
  void clearHasExact() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get address => $_getSZ(6);
  @$pb.TagNumber(7)
  set address($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAddress() => $_has(6);
  @$pb.TagNumber(7)
  void clearAddress() => $_clearField(7);
}

class IdentityCertificateBody extends $pb.GeneratedMessage {
  factory IdentityCertificateBody({
    $core.List<$core.int>? signingPubkey,
    $core.List<$core.int>? keyAgreementPubkey,
    $core.String? displayName,
    $core.String? resilienceId,
    $fixnum.Int64? validFromMs,
    $fixnum.Int64? validUntilMs,
  }) {
    final result = IdentityCertificateBody._();
    if (signingPubkey != null) result.signingPubkey = signingPubkey;
    if (keyAgreementPubkey != null)
      result.keyAgreementPubkey = keyAgreementPubkey;
    if (displayName != null) result.displayName = displayName;
    if (resilienceId != null) result.resilienceId = resilienceId;
    if (validFromMs != null) result.validFromMs = validFromMs;
    if (validUntilMs != null) result.validUntilMs = validUntilMs;
    return result;
  }

  IdentityCertificateBody._();

  factory IdentityCertificateBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      IdentityCertificateBody()..mergeFromBuffer(data, registry);
  factory IdentityCertificateBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      IdentityCertificateBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IdentityCertificateBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: IdentityCertificateBody.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'signingPubkey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'keyAgreementPubkey', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'displayName')
    ..aOS(4, _omitFieldNames ? '' : 'resilienceId')
    ..aInt64(5, _omitFieldNames ? '' : 'validFromMs')
    ..aInt64(6, _omitFieldNames ? '' : 'validUntilMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IdentityCertificateBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IdentityCertificateBody copyWith(
          void Function(IdentityCertificateBody) updates) =>
      super.copyWith((message) => updates(message as IdentityCertificateBody))
          as IdentityCertificateBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use IdentityCertificateBody() / IdentityCertificateBody.new instead')
  static IdentityCertificateBody create() => IdentityCertificateBody._();
  static $pb.GeneratedMessage $_createMessage() => IdentityCertificateBody._();
  @$core.override
  IdentityCertificateBody createEmptyInstance() => IdentityCertificateBody._();
  @$core.pragma('dart2js:noInline')
  static IdentityCertificateBody getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IdentityCertificateBody>(
          IdentityCertificateBody.$_createMessage);
  static IdentityCertificateBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get signingPubkey => $_getN(0);
  @$pb.TagNumber(1)
  set signingPubkey($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSigningPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearSigningPubkey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get keyAgreementPubkey => $_getN(1);
  @$pb.TagNumber(2)
  set keyAgreementPubkey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKeyAgreementPubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearKeyAgreementPubkey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get displayName => $_getSZ(2);
  @$pb.TagNumber(3)
  set displayName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDisplayName() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisplayName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get resilienceId => $_getSZ(3);
  @$pb.TagNumber(4)
  set resilienceId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasResilienceId() => $_has(3);
  @$pb.TagNumber(4)
  void clearResilienceId() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get validFromMs => $_getI64(4);
  @$pb.TagNumber(5)
  set validFromMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasValidFromMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearValidFromMs() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get validUntilMs => $_getI64(5);
  @$pb.TagNumber(6)
  set validUntilMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasValidUntilMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearValidUntilMs() => $_clearField(6);
}

class OrgCertificateBody extends $pb.GeneratedMessage {
  factory OrgCertificateBody({
    $core.List<$core.int>? orgRootPubkey,
    $core.List<$core.int>? subjectPubkey,
    $core.String? orgName,
    $core.String? facilityName,
    ProvenanceKind? provenance,
    $fixnum.Int64? validFromMs,
    $fixnum.Int64? validUntilMs,
  }) {
    final result = OrgCertificateBody._();
    if (orgRootPubkey != null) result.orgRootPubkey = orgRootPubkey;
    if (subjectPubkey != null) result.subjectPubkey = subjectPubkey;
    if (orgName != null) result.orgName = orgName;
    if (facilityName != null) result.facilityName = facilityName;
    if (provenance != null) result.provenance = provenance;
    if (validFromMs != null) result.validFromMs = validFromMs;
    if (validUntilMs != null) result.validUntilMs = validUntilMs;
    return result;
  }

  OrgCertificateBody._();

  factory OrgCertificateBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OrgCertificateBody()..mergeFromBuffer(data, registry);
  factory OrgCertificateBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OrgCertificateBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OrgCertificateBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: OrgCertificateBody.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'orgRootPubkey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'subjectPubkey', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'orgName')
    ..aOS(4, _omitFieldNames ? '' : 'facilityName')
    ..aE<ProvenanceKind>(5, _omitFieldNames ? '' : 'provenance',
        enumValues: ProvenanceKind.values)
    ..aInt64(6, _omitFieldNames ? '' : 'validFromMs')
    ..aInt64(7, _omitFieldNames ? '' : 'validUntilMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OrgCertificateBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OrgCertificateBody copyWith(void Function(OrgCertificateBody) updates) =>
      super.copyWith((message) => updates(message as OrgCertificateBody))
          as OrgCertificateBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OrgCertificateBody() / OrgCertificateBody.new instead')
  static OrgCertificateBody create() => OrgCertificateBody._();
  static $pb.GeneratedMessage $_createMessage() => OrgCertificateBody._();
  @$core.override
  OrgCertificateBody createEmptyInstance() => OrgCertificateBody._();
  @$core.pragma('dart2js:noInline')
  static OrgCertificateBody getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OrgCertificateBody>(
          OrgCertificateBody.$_createMessage);
  static OrgCertificateBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get orgRootPubkey => $_getN(0);
  @$pb.TagNumber(1)
  set orgRootPubkey($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrgRootPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrgRootPubkey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get subjectPubkey => $_getN(1);
  @$pb.TagNumber(2)
  set subjectPubkey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSubjectPubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubjectPubkey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get orgName => $_getSZ(2);
  @$pb.TagNumber(3)
  set orgName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOrgName() => $_has(2);
  @$pb.TagNumber(3)
  void clearOrgName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get facilityName => $_getSZ(3);
  @$pb.TagNumber(4)
  set facilityName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFacilityName() => $_has(3);
  @$pb.TagNumber(4)
  void clearFacilityName() => $_clearField(4);

  @$pb.TagNumber(5)
  ProvenanceKind get provenance => $_getN(4);
  @$pb.TagNumber(5)
  set provenance(ProvenanceKind value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasProvenance() => $_has(4);
  @$pb.TagNumber(5)
  void clearProvenance() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get validFromMs => $_getI64(5);
  @$pb.TagNumber(6)
  set validFromMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasValidFromMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearValidFromMs() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get validUntilMs => $_getI64(6);
  @$pb.TagNumber(7)
  set validUntilMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasValidUntilMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearValidUntilMs() => $_clearField(7);
}

class KeyRevokedBody extends $pb.GeneratedMessage {
  factory KeyRevokedBody({
    $core.List<$core.int>? revokedPubkey,
    $core.String? reason,
    $fixnum.Int64? revokedAtMs,
  }) {
    final result = KeyRevokedBody._();
    if (revokedPubkey != null) result.revokedPubkey = revokedPubkey;
    if (reason != null) result.reason = reason;
    if (revokedAtMs != null) result.revokedAtMs = revokedAtMs;
    return result;
  }

  KeyRevokedBody._();

  factory KeyRevokedBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KeyRevokedBody()..mergeFromBuffer(data, registry);
  factory KeyRevokedBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KeyRevokedBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyRevokedBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: KeyRevokedBody.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'revokedPubkey', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..aInt64(3, _omitFieldNames ? '' : 'revokedAtMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyRevokedBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyRevokedBody copyWith(void Function(KeyRevokedBody) updates) =>
      super.copyWith((message) => updates(message as KeyRevokedBody))
          as KeyRevokedBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use KeyRevokedBody() / KeyRevokedBody.new instead')
  static KeyRevokedBody create() => KeyRevokedBody._();
  static $pb.GeneratedMessage $_createMessage() => KeyRevokedBody._();
  @$core.override
  KeyRevokedBody createEmptyInstance() => KeyRevokedBody._();
  @$core.pragma('dart2js:noInline')
  static KeyRevokedBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KeyRevokedBody>(
          KeyRevokedBody.$_createMessage);
  static KeyRevokedBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get revokedPubkey => $_getN(0);
  @$pb.TagNumber(1)
  set revokedPubkey($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRevokedPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearRevokedPubkey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get revokedAtMs => $_getI64(2);
  @$pb.TagNumber(3)
  set revokedAtMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRevokedAtMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearRevokedAtMs() => $_clearField(3);
}

class ResourceBody extends $pb.GeneratedMessage {
  factory ResourceBody({
    $core.String? resourceId,
    ResourceCategory? category,
    $core.String? title,
    $core.String? notes,
    AmountBand? amount,
    Availability? availability,
    $fixnum.Int64? availableUntilMs,
    GeoPoint? location,
    ProvenanceKind? provenance,
    $core.bool? isShelter,
  }) {
    final result = ResourceBody._();
    if (resourceId != null) result.resourceId = resourceId;
    if (category != null) result.category = category;
    if (title != null) result.title = title;
    if (notes != null) result.notes = notes;
    if (amount != null) result.amount = amount;
    if (availability != null) result.availability = availability;
    if (availableUntilMs != null) result.availableUntilMs = availableUntilMs;
    if (location != null) result.location = location;
    if (provenance != null) result.provenance = provenance;
    if (isShelter != null) result.isShelter = isShelter;
    return result;
  }

  ResourceBody._();

  factory ResourceBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResourceBody()..mergeFromBuffer(data, registry);
  factory ResourceBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResourceBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResourceBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: ResourceBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'resourceId')
    ..aE<ResourceCategory>(2, _omitFieldNames ? '' : 'category',
        enumValues: ResourceCategory.values)
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOS(4, _omitFieldNames ? '' : 'notes')
    ..aE<AmountBand>(5, _omitFieldNames ? '' : 'amount',
        enumValues: AmountBand.values)
    ..aE<Availability>(6, _omitFieldNames ? '' : 'availability',
        enumValues: Availability.values)
    ..aInt64(7, _omitFieldNames ? '' : 'availableUntilMs')
    ..aOM<GeoPoint>(8, _omitFieldNames ? '' : 'location',
        subBuilder: GeoPoint.$_createMessage)
    ..aE<ProvenanceKind>(9, _omitFieldNames ? '' : 'provenance',
        enumValues: ProvenanceKind.values)
    ..aOB(10, _omitFieldNames ? '' : 'isShelter')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResourceBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResourceBody copyWith(void Function(ResourceBody) updates) =>
      super.copyWith((message) => updates(message as ResourceBody))
          as ResourceBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ResourceBody() / ResourceBody.new instead')
  static ResourceBody create() => ResourceBody._();
  static $pb.GeneratedMessage $_createMessage() => ResourceBody._();
  @$core.override
  ResourceBody createEmptyInstance() => ResourceBody._();
  @$core.pragma('dart2js:noInline')
  static ResourceBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ResourceBody>(
          ResourceBody.$_createMessage);
  static ResourceBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get resourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasResourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearResourceId() => $_clearField(1);

  @$pb.TagNumber(2)
  ResourceCategory get category => $_getN(1);
  @$pb.TagNumber(2)
  set category(ResourceCategory value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCategory() => $_has(1);
  @$pb.TagNumber(2)
  void clearCategory() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get notes => $_getSZ(3);
  @$pb.TagNumber(4)
  set notes($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNotes() => $_has(3);
  @$pb.TagNumber(4)
  void clearNotes() => $_clearField(4);

  @$pb.TagNumber(5)
  AmountBand get amount => $_getN(4);
  @$pb.TagNumber(5)
  set amount(AmountBand value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasAmount() => $_has(4);
  @$pb.TagNumber(5)
  void clearAmount() => $_clearField(5);

  @$pb.TagNumber(6)
  Availability get availability => $_getN(5);
  @$pb.TagNumber(6)
  set availability(Availability value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasAvailability() => $_has(5);
  @$pb.TagNumber(6)
  void clearAvailability() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get availableUntilMs => $_getI64(6);
  @$pb.TagNumber(7)
  set availableUntilMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAvailableUntilMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearAvailableUntilMs() => $_clearField(7);

  @$pb.TagNumber(8)
  GeoPoint get location => $_getN(7);
  @$pb.TagNumber(8)
  set location(GeoPoint value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasLocation() => $_has(7);
  @$pb.TagNumber(8)
  void clearLocation() => $_clearField(8);
  @$pb.TagNumber(8)
  GeoPoint ensureLocation() => $_ensure(7);

  @$pb.TagNumber(9)
  ProvenanceKind get provenance => $_getN(8);
  @$pb.TagNumber(9)
  set provenance(ProvenanceKind value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasProvenance() => $_has(8);
  @$pb.TagNumber(9)
  void clearProvenance() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get isShelter => $_getBF(9);
  @$pb.TagNumber(10)
  set isShelter($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIsShelter() => $_has(9);
  @$pb.TagNumber(10)
  void clearIsShelter() => $_clearField(10);
}

/// Correction/update that references a prior resource event in depends_on.
class ResourceUpdateBody extends $pb.GeneratedMessage {
  factory ResourceUpdateBody({
    $core.String? resourceId,
    AmountBand? amount,
    Availability? availability,
    $core.String? notes,
    $core.bool? withdrawn,
  }) {
    final result = ResourceUpdateBody._();
    if (resourceId != null) result.resourceId = resourceId;
    if (amount != null) result.amount = amount;
    if (availability != null) result.availability = availability;
    if (notes != null) result.notes = notes;
    if (withdrawn != null) result.withdrawn = withdrawn;
    return result;
  }

  ResourceUpdateBody._();

  factory ResourceUpdateBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResourceUpdateBody()..mergeFromBuffer(data, registry);
  factory ResourceUpdateBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResourceUpdateBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResourceUpdateBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: ResourceUpdateBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'resourceId')
    ..aE<AmountBand>(2, _omitFieldNames ? '' : 'amount',
        enumValues: AmountBand.values)
    ..aE<Availability>(3, _omitFieldNames ? '' : 'availability',
        enumValues: Availability.values)
    ..aOS(4, _omitFieldNames ? '' : 'notes')
    ..aOB(5, _omitFieldNames ? '' : 'withdrawn')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResourceUpdateBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResourceUpdateBody copyWith(void Function(ResourceUpdateBody) updates) =>
      super.copyWith((message) => updates(message as ResourceUpdateBody))
          as ResourceUpdateBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ResourceUpdateBody() / ResourceUpdateBody.new instead')
  static ResourceUpdateBody create() => ResourceUpdateBody._();
  static $pb.GeneratedMessage $_createMessage() => ResourceUpdateBody._();
  @$core.override
  ResourceUpdateBody createEmptyInstance() => ResourceUpdateBody._();
  @$core.pragma('dart2js:noInline')
  static ResourceUpdateBody getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResourceUpdateBody>(
          ResourceUpdateBody.$_createMessage);
  static ResourceUpdateBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get resourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasResourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearResourceId() => $_clearField(1);

  @$pb.TagNumber(2)
  AmountBand get amount => $_getN(1);
  @$pb.TagNumber(2)
  set amount(AmountBand value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAmount() => $_has(1);
  @$pb.TagNumber(2)
  void clearAmount() => $_clearField(2);

  @$pb.TagNumber(3)
  Availability get availability => $_getN(2);
  @$pb.TagNumber(3)
  set availability(Availability value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAvailability() => $_has(2);
  @$pb.TagNumber(3)
  void clearAvailability() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get notes => $_getSZ(3);
  @$pb.TagNumber(4)
  set notes($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNotes() => $_has(3);
  @$pb.TagNumber(4)
  void clearNotes() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get withdrawn => $_getBF(4);
  @$pb.TagNumber(5)
  set withdrawn($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasWithdrawn() => $_has(4);
  @$pb.TagNumber(5)
  void clearWithdrawn() => $_clearField(5);
}

class ObservationBody extends $pb.GeneratedMessage {
  factory ObservationBody({
    $core.String? resourceId,
    ObservationBody_Kind? kind,
    $core.String? note,
    AmountBand? observedAmount,
  }) {
    final result = ObservationBody._();
    if (resourceId != null) result.resourceId = resourceId;
    if (kind != null) result.kind = kind;
    if (note != null) result.note = note;
    if (observedAmount != null) result.observedAmount = observedAmount;
    return result;
  }

  ObservationBody._();

  factory ObservationBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ObservationBody()..mergeFromBuffer(data, registry);
  factory ObservationBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ObservationBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ObservationBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: ObservationBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'resourceId')
    ..aE<ObservationBody_Kind>(2, _omitFieldNames ? '' : 'kind',
        enumValues: ObservationBody_Kind.values)
    ..aOS(3, _omitFieldNames ? '' : 'note')
    ..aE<AmountBand>(4, _omitFieldNames ? '' : 'observedAmount',
        enumValues: AmountBand.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ObservationBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ObservationBody copyWith(void Function(ObservationBody) updates) =>
      super.copyWith((message) => updates(message as ObservationBody))
          as ObservationBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ObservationBody() / ObservationBody.new instead')
  static ObservationBody create() => ObservationBody._();
  static $pb.GeneratedMessage $_createMessage() => ObservationBody._();
  @$core.override
  ObservationBody createEmptyInstance() => ObservationBody._();
  @$core.pragma('dart2js:noInline')
  static ObservationBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ObservationBody>(
          ObservationBody.$_createMessage);
  static ObservationBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get resourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasResourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearResourceId() => $_clearField(1);

  @$pb.TagNumber(2)
  ObservationBody_Kind get kind => $_getN(1);
  @$pb.TagNumber(2)
  set kind(ObservationBody_Kind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get note => $_getSZ(2);
  @$pb.TagNumber(3)
  set note($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNote() => $_has(2);
  @$pb.TagNumber(3)
  void clearNote() => $_clearField(3);

  @$pb.TagNumber(4)
  AmountBand get observedAmount => $_getN(3);
  @$pb.TagNumber(4)
  set observedAmount(AmountBand value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasObservedAmount() => $_has(3);
  @$pb.TagNumber(4)
  void clearObservedAmount() => $_clearField(4);
}

class InventorySnapshotBody extends $pb.GeneratedMessage {
  factory InventorySnapshotBody({
    $core.String? resourceId,
    $fixnum.Int64? quantity,
    $core.String? unit,
    $fixnum.Int64? asOfMs,
  }) {
    final result = InventorySnapshotBody._();
    if (resourceId != null) result.resourceId = resourceId;
    if (quantity != null) result.quantity = quantity;
    if (unit != null) result.unit = unit;
    if (asOfMs != null) result.asOfMs = asOfMs;
    return result;
  }

  InventorySnapshotBody._();

  factory InventorySnapshotBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      InventorySnapshotBody()..mergeFromBuffer(data, registry);
  factory InventorySnapshotBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      InventorySnapshotBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InventorySnapshotBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: InventorySnapshotBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'resourceId')
    ..aInt64(2, _omitFieldNames ? '' : 'quantity')
    ..aOS(3, _omitFieldNames ? '' : 'unit')
    ..aInt64(4, _omitFieldNames ? '' : 'asOfMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InventorySnapshotBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InventorySnapshotBody copyWith(
          void Function(InventorySnapshotBody) updates) =>
      super.copyWith((message) => updates(message as InventorySnapshotBody))
          as InventorySnapshotBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use InventorySnapshotBody() / InventorySnapshotBody.new instead')
  static InventorySnapshotBody create() => InventorySnapshotBody._();
  static $pb.GeneratedMessage $_createMessage() => InventorySnapshotBody._();
  @$core.override
  InventorySnapshotBody createEmptyInstance() => InventorySnapshotBody._();
  @$core.pragma('dart2js:noInline')
  static InventorySnapshotBody getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InventorySnapshotBody>(
          InventorySnapshotBody.$_createMessage);
  static InventorySnapshotBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get resourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasResourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearResourceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get quantity => $_getI64(1);
  @$pb.TagNumber(2)
  set quantity($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuantity() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuantity() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get unit => $_getSZ(2);
  @$pb.TagNumber(3)
  set unit($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUnit() => $_has(2);
  @$pb.TagNumber(3)
  void clearUnit() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get asOfMs => $_getI64(3);
  @$pb.TagNumber(4)
  set asOfMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAsOfMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearAsOfMs() => $_clearField(4);
}

class ReservationBody extends $pb.GeneratedMessage {
  factory ReservationBody({
    $core.String? resourceId,
    $fixnum.Int64? quantity,
    $core.String? missionId,
    $fixnum.Int64? reservedUntilMs,
  }) {
    final result = ReservationBody._();
    if (resourceId != null) result.resourceId = resourceId;
    if (quantity != null) result.quantity = quantity;
    if (missionId != null) result.missionId = missionId;
    if (reservedUntilMs != null) result.reservedUntilMs = reservedUntilMs;
    return result;
  }

  ReservationBody._();

  factory ReservationBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReservationBody()..mergeFromBuffer(data, registry);
  factory ReservationBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReservationBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReservationBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: ReservationBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'resourceId')
    ..aInt64(2, _omitFieldNames ? '' : 'quantity')
    ..aOS(3, _omitFieldNames ? '' : 'missionId')
    ..aInt64(4, _omitFieldNames ? '' : 'reservedUntilMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReservationBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReservationBody copyWith(void Function(ReservationBody) updates) =>
      super.copyWith((message) => updates(message as ReservationBody))
          as ReservationBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReservationBody() / ReservationBody.new instead')
  static ReservationBody create() => ReservationBody._();
  static $pb.GeneratedMessage $_createMessage() => ReservationBody._();
  @$core.override
  ReservationBody createEmptyInstance() => ReservationBody._();
  @$core.pragma('dart2js:noInline')
  static ReservationBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ReservationBody>(
          ReservationBody.$_createMessage);
  static ReservationBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get resourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasResourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearResourceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get quantity => $_getI64(1);
  @$pb.TagNumber(2)
  set quantity($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuantity() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuantity() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get missionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set missionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMissionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearMissionId() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get reservedUntilMs => $_getI64(3);
  @$pb.TagNumber(4)
  set reservedUntilMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReservedUntilMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearReservedUntilMs() => $_clearField(4);
}

class HelpRequestBody extends $pb.GeneratedMessage {
  factory HelpRequestBody({
    $core.String? requestId,
    $core.Iterable<ResourceCategory>? categories,
    $core.String? freeform,
    Priority? priority,
    GeoPoint? location,
    $fixnum.Int64? neededByMs,
  }) {
    final result = HelpRequestBody._();
    if (requestId != null) result.requestId = requestId;
    if (categories != null) result.categories.addAll(categories);
    if (freeform != null) result.freeform = freeform;
    if (priority != null) result.priority = priority;
    if (location != null) result.location = location;
    if (neededByMs != null) result.neededByMs = neededByMs;
    return result;
  }

  HelpRequestBody._();

  factory HelpRequestBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HelpRequestBody()..mergeFromBuffer(data, registry);
  factory HelpRequestBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HelpRequestBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HelpRequestBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: HelpRequestBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..pc<ResourceCategory>(
        2, _omitFieldNames ? '' : 'categories', $pb.PbFieldType.KE,
        valueOf: ResourceCategory.valueOf,
        enumValues: ResourceCategory.values,
        defaultEnumValue: ResourceCategory.RESOURCE_CATEGORY_UNSPECIFIED)
    ..aOS(3, _omitFieldNames ? '' : 'freeform')
    ..aE<Priority>(4, _omitFieldNames ? '' : 'priority',
        enumValues: Priority.values)
    ..aOM<GeoPoint>(5, _omitFieldNames ? '' : 'location',
        subBuilder: GeoPoint.$_createMessage)
    ..aInt64(6, _omitFieldNames ? '' : 'neededByMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HelpRequestBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HelpRequestBody copyWith(void Function(HelpRequestBody) updates) =>
      super.copyWith((message) => updates(message as HelpRequestBody))
          as HelpRequestBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use HelpRequestBody() / HelpRequestBody.new instead')
  static HelpRequestBody create() => HelpRequestBody._();
  static $pb.GeneratedMessage $_createMessage() => HelpRequestBody._();
  @$core.override
  HelpRequestBody createEmptyInstance() => HelpRequestBody._();
  @$core.pragma('dart2js:noInline')
  static HelpRequestBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<HelpRequestBody>(
          HelpRequestBody.$_createMessage);
  static HelpRequestBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<ResourceCategory> get categories => $_getList(1);

  @$pb.TagNumber(3)
  $core.String get freeform => $_getSZ(2);
  @$pb.TagNumber(3)
  set freeform($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFreeform() => $_has(2);
  @$pb.TagNumber(3)
  void clearFreeform() => $_clearField(3);

  @$pb.TagNumber(4)
  Priority get priority => $_getN(3);
  @$pb.TagNumber(4)
  set priority(Priority value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPriority() => $_has(3);
  @$pb.TagNumber(4)
  void clearPriority() => $_clearField(4);

  @$pb.TagNumber(5)
  GeoPoint get location => $_getN(4);
  @$pb.TagNumber(5)
  set location(GeoPoint value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasLocation() => $_has(4);
  @$pb.TagNumber(5)
  void clearLocation() => $_clearField(5);
  @$pb.TagNumber(5)
  GeoPoint ensureLocation() => $_ensure(4);

  @$pb.TagNumber(6)
  $fixnum.Int64 get neededByMs => $_getI64(5);
  @$pb.TagNumber(6)
  set neededByMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNeededByMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearNeededByMs() => $_clearField(6);
}

class HelpOfferBody extends $pb.GeneratedMessage {
  factory HelpOfferBody({
    $core.String? offerId,
    $core.Iterable<ResourceCategory>? categories,
    AmountBand? amount,
    Availability? availability,
    $core.String? notes,
    GeoPoint? location,
  }) {
    final result = HelpOfferBody._();
    if (offerId != null) result.offerId = offerId;
    if (categories != null) result.categories.addAll(categories);
    if (amount != null) result.amount = amount;
    if (availability != null) result.availability = availability;
    if (notes != null) result.notes = notes;
    if (location != null) result.location = location;
    return result;
  }

  HelpOfferBody._();

  factory HelpOfferBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HelpOfferBody()..mergeFromBuffer(data, registry);
  factory HelpOfferBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HelpOfferBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HelpOfferBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: HelpOfferBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'offerId')
    ..pc<ResourceCategory>(
        2, _omitFieldNames ? '' : 'categories', $pb.PbFieldType.KE,
        valueOf: ResourceCategory.valueOf,
        enumValues: ResourceCategory.values,
        defaultEnumValue: ResourceCategory.RESOURCE_CATEGORY_UNSPECIFIED)
    ..aE<AmountBand>(3, _omitFieldNames ? '' : 'amount',
        enumValues: AmountBand.values)
    ..aE<Availability>(4, _omitFieldNames ? '' : 'availability',
        enumValues: Availability.values)
    ..aOS(5, _omitFieldNames ? '' : 'notes')
    ..aOM<GeoPoint>(6, _omitFieldNames ? '' : 'location',
        subBuilder: GeoPoint.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HelpOfferBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HelpOfferBody copyWith(void Function(HelpOfferBody) updates) =>
      super.copyWith((message) => updates(message as HelpOfferBody))
          as HelpOfferBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use HelpOfferBody() / HelpOfferBody.new instead')
  static HelpOfferBody create() => HelpOfferBody._();
  static $pb.GeneratedMessage $_createMessage() => HelpOfferBody._();
  @$core.override
  HelpOfferBody createEmptyInstance() => HelpOfferBody._();
  @$core.pragma('dart2js:noInline')
  static HelpOfferBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<HelpOfferBody>(
          HelpOfferBody.$_createMessage);
  static HelpOfferBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get offerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set offerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOfferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOfferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<ResourceCategory> get categories => $_getList(1);

  @$pb.TagNumber(3)
  AmountBand get amount => $_getN(2);
  @$pb.TagNumber(3)
  set amount(AmountBand value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => $_clearField(3);

  @$pb.TagNumber(4)
  Availability get availability => $_getN(3);
  @$pb.TagNumber(4)
  set availability(Availability value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasAvailability() => $_has(3);
  @$pb.TagNumber(4)
  void clearAvailability() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get notes => $_getSZ(4);
  @$pb.TagNumber(5)
  set notes($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasNotes() => $_has(4);
  @$pb.TagNumber(5)
  void clearNotes() => $_clearField(5);

  @$pb.TagNumber(6)
  GeoPoint get location => $_getN(5);
  @$pb.TagNumber(6)
  set location(GeoPoint value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasLocation() => $_has(5);
  @$pb.TagNumber(6)
  void clearLocation() => $_clearField(6);
  @$pb.TagNumber(6)
  GeoPoint ensureLocation() => $_ensure(5);
}

/// Closes/cancels a prior HELP_REQUESTED. Honored ONLY when signed by the same
/// author that signed the original request (owner-only; a close from any other
/// key is ignored by the fold). References the request by id.
class HelpRequestClosedBody extends $pb.GeneratedMessage {
  factory HelpRequestClosedBody({
    $core.String? requestId,
    $core.String? reason,
    $fixnum.Int64? closedAtMs,
  }) {
    final result = HelpRequestClosedBody._();
    if (requestId != null) result.requestId = requestId;
    if (reason != null) result.reason = reason;
    if (closedAtMs != null) result.closedAtMs = closedAtMs;
    return result;
  }

  HelpRequestClosedBody._();

  factory HelpRequestClosedBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HelpRequestClosedBody()..mergeFromBuffer(data, registry);
  factory HelpRequestClosedBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HelpRequestClosedBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HelpRequestClosedBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: HelpRequestClosedBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..aInt64(3, _omitFieldNames ? '' : 'closedAtMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HelpRequestClosedBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HelpRequestClosedBody copyWith(
          void Function(HelpRequestClosedBody) updates) =>
      super.copyWith((message) => updates(message as HelpRequestClosedBody))
          as HelpRequestClosedBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use HelpRequestClosedBody() / HelpRequestClosedBody.new instead')
  static HelpRequestClosedBody create() => HelpRequestClosedBody._();
  static $pb.GeneratedMessage $_createMessage() => HelpRequestClosedBody._();
  @$core.override
  HelpRequestClosedBody createEmptyInstance() => HelpRequestClosedBody._();
  @$core.pragma('dart2js:noInline')
  static HelpRequestClosedBody getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HelpRequestClosedBody>(
          HelpRequestClosedBody.$_createMessage);
  static HelpRequestClosedBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get closedAtMs => $_getI64(2);
  @$pb.TagNumber(3)
  set closedAtMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasClosedAtMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearClosedAtMs() => $_clearField(3);
}

class TransportOfferBody extends $pb.GeneratedMessage {
  factory TransportOfferBody({
    $core.String? offerId,
    TransportMode? mode,
    CapacityBand? capacity,
    Availability? availability,
    GeoPoint? location,
  }) {
    final result = TransportOfferBody._();
    if (offerId != null) result.offerId = offerId;
    if (mode != null) result.mode = mode;
    if (capacity != null) result.capacity = capacity;
    if (availability != null) result.availability = availability;
    if (location != null) result.location = location;
    return result;
  }

  TransportOfferBody._();

  factory TransportOfferBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransportOfferBody()..mergeFromBuffer(data, registry);
  factory TransportOfferBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransportOfferBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransportOfferBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: TransportOfferBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'offerId')
    ..aE<TransportMode>(2, _omitFieldNames ? '' : 'mode',
        enumValues: TransportMode.values)
    ..aE<CapacityBand>(3, _omitFieldNames ? '' : 'capacity',
        enumValues: CapacityBand.values)
    ..aE<Availability>(4, _omitFieldNames ? '' : 'availability',
        enumValues: Availability.values)
    ..aOM<GeoPoint>(5, _omitFieldNames ? '' : 'location',
        subBuilder: GeoPoint.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransportOfferBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransportOfferBody copyWith(void Function(TransportOfferBody) updates) =>
      super.copyWith((message) => updates(message as TransportOfferBody))
          as TransportOfferBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TransportOfferBody() / TransportOfferBody.new instead')
  static TransportOfferBody create() => TransportOfferBody._();
  static $pb.GeneratedMessage $_createMessage() => TransportOfferBody._();
  @$core.override
  TransportOfferBody createEmptyInstance() => TransportOfferBody._();
  @$core.pragma('dart2js:noInline')
  static TransportOfferBody getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransportOfferBody>(
          TransportOfferBody.$_createMessage);
  static TransportOfferBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get offerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set offerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOfferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOfferId() => $_clearField(1);

  @$pb.TagNumber(2)
  TransportMode get mode => $_getN(1);
  @$pb.TagNumber(2)
  set mode(TransportMode value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasMode() => $_has(1);
  @$pb.TagNumber(2)
  void clearMode() => $_clearField(2);

  @$pb.TagNumber(3)
  CapacityBand get capacity => $_getN(2);
  @$pb.TagNumber(3)
  set capacity(CapacityBand value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCapacity() => $_has(2);
  @$pb.TagNumber(3)
  void clearCapacity() => $_clearField(3);

  @$pb.TagNumber(4)
  Availability get availability => $_getN(3);
  @$pb.TagNumber(4)
  set availability(Availability value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasAvailability() => $_has(3);
  @$pb.TagNumber(4)
  void clearAvailability() => $_clearField(4);

  @$pb.TagNumber(5)
  GeoPoint get location => $_getN(4);
  @$pb.TagNumber(5)
  set location(GeoPoint value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasLocation() => $_has(4);
  @$pb.TagNumber(5)
  void clearLocation() => $_clearField(5);
  @$pb.TagNumber(5)
  GeoPoint ensureLocation() => $_ensure(4);
}

class ChannelCreatedBody extends $pb.GeneratedMessage {
  factory ChannelCreatedBody({
    $core.String? channelId,
    ChannelType? type,
    $core.String? name,
    $core.Iterable<$core.List<$core.int>>? initialMembers,
  }) {
    final result = ChannelCreatedBody._();
    if (channelId != null) result.channelId = channelId;
    if (type != null) result.type = type;
    if (name != null) result.name = name;
    if (initialMembers != null) result.initialMembers.addAll(initialMembers);
    return result;
  }

  ChannelCreatedBody._();

  factory ChannelCreatedBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChannelCreatedBody()..mergeFromBuffer(data, registry);
  factory ChannelCreatedBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChannelCreatedBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChannelCreatedBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: ChannelCreatedBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'channelId')
    ..aE<ChannelType>(2, _omitFieldNames ? '' : 'type',
        enumValues: ChannelType.values)
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..p<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'initialMembers', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChannelCreatedBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChannelCreatedBody copyWith(void Function(ChannelCreatedBody) updates) =>
      super.copyWith((message) => updates(message as ChannelCreatedBody))
          as ChannelCreatedBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ChannelCreatedBody() / ChannelCreatedBody.new instead')
  static ChannelCreatedBody create() => ChannelCreatedBody._();
  static $pb.GeneratedMessage $_createMessage() => ChannelCreatedBody._();
  @$core.override
  ChannelCreatedBody createEmptyInstance() => ChannelCreatedBody._();
  @$core.pragma('dart2js:noInline')
  static ChannelCreatedBody getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChannelCreatedBody>(
          ChannelCreatedBody.$_createMessage);
  static ChannelCreatedBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get channelId => $_getSZ(0);
  @$pb.TagNumber(1)
  set channelId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChannelId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannelId() => $_clearField(1);

  @$pb.TagNumber(2)
  ChannelType get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(ChannelType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.List<$core.int>> get initialMembers => $_getList(3);
}

class ChannelMembershipBody extends $pb.GeneratedMessage {
  factory ChannelMembershipBody({
    $core.String? channelId,
    $core.Iterable<$core.List<$core.int>>? added,
    $core.Iterable<$core.List<$core.int>>? removed,
    $fixnum.Int64? epoch,
  }) {
    final result = ChannelMembershipBody._();
    if (channelId != null) result.channelId = channelId;
    if (added != null) result.added.addAll(added);
    if (removed != null) result.removed.addAll(removed);
    if (epoch != null) result.epoch = epoch;
    return result;
  }

  ChannelMembershipBody._();

  factory ChannelMembershipBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChannelMembershipBody()..mergeFromBuffer(data, registry);
  factory ChannelMembershipBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChannelMembershipBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChannelMembershipBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: ChannelMembershipBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'channelId')
    ..p<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'added', $pb.PbFieldType.PY)
    ..p<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'removed', $pb.PbFieldType.PY)
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'epoch', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChannelMembershipBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChannelMembershipBody copyWith(
          void Function(ChannelMembershipBody) updates) =>
      super.copyWith((message) => updates(message as ChannelMembershipBody))
          as ChannelMembershipBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ChannelMembershipBody() / ChannelMembershipBody.new instead')
  static ChannelMembershipBody create() => ChannelMembershipBody._();
  static $pb.GeneratedMessage $_createMessage() => ChannelMembershipBody._();
  @$core.override
  ChannelMembershipBody createEmptyInstance() => ChannelMembershipBody._();
  @$core.pragma('dart2js:noInline')
  static ChannelMembershipBody getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChannelMembershipBody>(
          ChannelMembershipBody.$_createMessage);
  static ChannelMembershipBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get channelId => $_getSZ(0);
  @$pb.TagNumber(1)
  set channelId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChannelId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannelId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.List<$core.int>> get added => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$core.List<$core.int>> get removed => $_getList(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get epoch => $_getI64(3);
  @$pb.TagNumber(4)
  set epoch($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEpoch() => $_has(3);
  @$pb.TagNumber(4)
  void clearEpoch() => $_clearField(4);
}

/// Carries ciphertext only. Relays see recipient hint + ciphertext, nothing else.
class MessageBody extends $pb.GeneratedMessage {
  factory MessageBody({
    $core.String? messageId,
    $core.String? channelId,
    $core.List<$core.int>? recipientHint,
    $core.List<$core.int>? ciphertext,
    $core.int? groupEpoch,
    Priority? priority,
  }) {
    final result = MessageBody._();
    if (messageId != null) result.messageId = messageId;
    if (channelId != null) result.channelId = channelId;
    if (recipientHint != null) result.recipientHint = recipientHint;
    if (ciphertext != null) result.ciphertext = ciphertext;
    if (groupEpoch != null) result.groupEpoch = groupEpoch;
    if (priority != null) result.priority = priority;
    return result;
  }

  MessageBody._();

  factory MessageBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MessageBody()..mergeFromBuffer(data, registry);
  factory MessageBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MessageBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: MessageBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOS(2, _omitFieldNames ? '' : 'channelId')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'recipientHint', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'ciphertext', $pb.PbFieldType.OY)
    ..aI(5, _omitFieldNames ? '' : 'groupEpoch', fieldType: $pb.PbFieldType.OU3)
    ..aE<Priority>(6, _omitFieldNames ? '' : 'priority',
        enumValues: Priority.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageBody copyWith(void Function(MessageBody) updates) =>
      super.copyWith((message) => updates(message as MessageBody))
          as MessageBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MessageBody() / MessageBody.new instead')
  static MessageBody create() => MessageBody._();
  static $pb.GeneratedMessage $_createMessage() => MessageBody._();
  @$core.override
  MessageBody createEmptyInstance() => MessageBody._();
  @$core.pragma('dart2js:noInline')
  static MessageBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MessageBody>(
          MessageBody.$_createMessage);
  static MessageBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get channelId => $_getSZ(1);
  @$pb.TagNumber(2)
  set channelId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChannelId() => $_has(1);
  @$pb.TagNumber(2)
  void clearChannelId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get recipientHint => $_getN(2);
  @$pb.TagNumber(3)
  set recipientHint($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRecipientHint() => $_has(2);
  @$pb.TagNumber(3)
  void clearRecipientHint() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get ciphertext => $_getN(3);
  @$pb.TagNumber(4)
  set ciphertext($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCiphertext() => $_has(3);
  @$pb.TagNumber(4)
  void clearCiphertext() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get groupEpoch => $_getIZ(4);
  @$pb.TagNumber(5)
  set groupEpoch($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGroupEpoch() => $_has(4);
  @$pb.TagNumber(5)
  void clearGroupEpoch() => $_clearField(5);

  @$pb.TagNumber(6)
  Priority get priority => $_getN(5);
  @$pb.TagNumber(6)
  set priority(Priority value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPriority() => $_has(5);
  @$pb.TagNumber(6)
  void clearPriority() => $_clearField(6);
}

class ReceiptBody extends $pb.GeneratedMessage {
  factory ReceiptBody({
    $core.String? messageId,
    $core.List<$core.int>? byPubkey,
  }) {
    final result = ReceiptBody._();
    if (messageId != null) result.messageId = messageId;
    if (byPubkey != null) result.byPubkey = byPubkey;
    return result;
  }

  ReceiptBody._();

  factory ReceiptBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReceiptBody()..mergeFromBuffer(data, registry);
  factory ReceiptBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReceiptBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReceiptBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: ReceiptBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'byPubkey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReceiptBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReceiptBody copyWith(void Function(ReceiptBody) updates) =>
      super.copyWith((message) => updates(message as ReceiptBody))
          as ReceiptBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReceiptBody() / ReceiptBody.new instead')
  static ReceiptBody create() => ReceiptBody._();
  static $pb.GeneratedMessage $_createMessage() => ReceiptBody._();
  @$core.override
  ReceiptBody createEmptyInstance() => ReceiptBody._();
  @$core.pragma('dart2js:noInline')
  static ReceiptBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ReceiptBody>(
          ReceiptBody.$_createMessage);
  static ReceiptBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get byPubkey => $_getN(1);
  @$pb.TagNumber(2)
  set byPubkey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasByPubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearByPubkey() => $_clearField(2);
}

class PrekeyBundleBody extends $pb.GeneratedMessage {
  factory PrekeyBundleBody({
    $core.List<$core.int>? identityPubkey,
    $core.int? registrationId,
    $core.int? signedPrekeyId,
    $core.List<$core.int>? signedPrekeyPub,
    $core.List<$core.int>? signedPrekeySig,
    $core.int? prekeyId,
    $core.List<$core.int>? prekeyPub,
  }) {
    final result = PrekeyBundleBody._();
    if (identityPubkey != null) result.identityPubkey = identityPubkey;
    if (registrationId != null) result.registrationId = registrationId;
    if (signedPrekeyId != null) result.signedPrekeyId = signedPrekeyId;
    if (signedPrekeyPub != null) result.signedPrekeyPub = signedPrekeyPub;
    if (signedPrekeySig != null) result.signedPrekeySig = signedPrekeySig;
    if (prekeyId != null) result.prekeyId = prekeyId;
    if (prekeyPub != null) result.prekeyPub = prekeyPub;
    return result;
  }

  PrekeyBundleBody._();

  factory PrekeyBundleBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PrekeyBundleBody()..mergeFromBuffer(data, registry);
  factory PrekeyBundleBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PrekeyBundleBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PrekeyBundleBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: PrekeyBundleBody.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'identityPubkey', $pb.PbFieldType.OY)
    ..aI(2, _omitFieldNames ? '' : 'registrationId',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'signedPrekeyId',
        fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'signedPrekeyPub', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'signedPrekeySig', $pb.PbFieldType.OY)
    ..aI(6, _omitFieldNames ? '' : 'prekeyId', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        7, _omitFieldNames ? '' : 'prekeyPub', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PrekeyBundleBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PrekeyBundleBody copyWith(void Function(PrekeyBundleBody) updates) =>
      super.copyWith((message) => updates(message as PrekeyBundleBody))
          as PrekeyBundleBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PrekeyBundleBody() / PrekeyBundleBody.new instead')
  static PrekeyBundleBody create() => PrekeyBundleBody._();
  static $pb.GeneratedMessage $_createMessage() => PrekeyBundleBody._();
  @$core.override
  PrekeyBundleBody createEmptyInstance() => PrekeyBundleBody._();
  @$core.pragma('dart2js:noInline')
  static PrekeyBundleBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PrekeyBundleBody>(
          PrekeyBundleBody.$_createMessage);
  static PrekeyBundleBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get identityPubkey => $_getN(0);
  @$pb.TagNumber(1)
  set identityPubkey($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIdentityPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearIdentityPubkey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get registrationId => $_getIZ(1);
  @$pb.TagNumber(2)
  set registrationId($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRegistrationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRegistrationId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get signedPrekeyId => $_getIZ(2);
  @$pb.TagNumber(3)
  set signedPrekeyId($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSignedPrekeyId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSignedPrekeyId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get signedPrekeyPub => $_getN(3);
  @$pb.TagNumber(4)
  set signedPrekeyPub($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSignedPrekeyPub() => $_has(3);
  @$pb.TagNumber(4)
  void clearSignedPrekeyPub() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get signedPrekeySig => $_getN(4);
  @$pb.TagNumber(5)
  set signedPrekeySig($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSignedPrekeySig() => $_has(4);
  @$pb.TagNumber(5)
  void clearSignedPrekeySig() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get prekeyId => $_getIZ(5);
  @$pb.TagNumber(6)
  set prekeyId($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPrekeyId() => $_has(5);
  @$pb.TagNumber(6)
  void clearPrekeyId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.int> get prekeyPub => $_getN(6);
  @$pb.TagNumber(7)
  set prekeyPub($core.List<$core.int> value) => $_setBytes(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPrekeyPub() => $_has(6);
  @$pb.TagNumber(7)
  void clearPrekeyPub() => $_clearField(7);
}

class MissionBody extends $pb.GeneratedMessage {
  factory MissionBody({
    $core.String? missionId,
    ResourceCategory? cargoCategory,
    $core.String? cargoDescription,
    $fixnum.Int64? cargoQuantity,
    $core.String? pickupName,
    GeoPoint? pickupLocation,
    $core.String? destinationName,
    GeoPoint? destinationLocation,
    Priority? priority,
    $core.String? channelId,
  }) {
    final result = MissionBody._();
    if (missionId != null) result.missionId = missionId;
    if (cargoCategory != null) result.cargoCategory = cargoCategory;
    if (cargoDescription != null) result.cargoDescription = cargoDescription;
    if (cargoQuantity != null) result.cargoQuantity = cargoQuantity;
    if (pickupName != null) result.pickupName = pickupName;
    if (pickupLocation != null) result.pickupLocation = pickupLocation;
    if (destinationName != null) result.destinationName = destinationName;
    if (destinationLocation != null)
      result.destinationLocation = destinationLocation;
    if (priority != null) result.priority = priority;
    if (channelId != null) result.channelId = channelId;
    return result;
  }

  MissionBody._();

  factory MissionBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MissionBody()..mergeFromBuffer(data, registry);
  factory MissionBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MissionBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MissionBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: MissionBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'missionId')
    ..aE<ResourceCategory>(2, _omitFieldNames ? '' : 'cargoCategory',
        enumValues: ResourceCategory.values)
    ..aOS(3, _omitFieldNames ? '' : 'cargoDescription')
    ..aInt64(4, _omitFieldNames ? '' : 'cargoQuantity')
    ..aOS(5, _omitFieldNames ? '' : 'pickupName')
    ..aOM<GeoPoint>(6, _omitFieldNames ? '' : 'pickupLocation',
        subBuilder: GeoPoint.$_createMessage)
    ..aOS(7, _omitFieldNames ? '' : 'destinationName')
    ..aOM<GeoPoint>(8, _omitFieldNames ? '' : 'destinationLocation',
        subBuilder: GeoPoint.$_createMessage)
    ..aE<Priority>(9, _omitFieldNames ? '' : 'priority',
        enumValues: Priority.values)
    ..aOS(10, _omitFieldNames ? '' : 'channelId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MissionBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MissionBody copyWith(void Function(MissionBody) updates) =>
      super.copyWith((message) => updates(message as MissionBody))
          as MissionBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MissionBody() / MissionBody.new instead')
  static MissionBody create() => MissionBody._();
  static $pb.GeneratedMessage $_createMessage() => MissionBody._();
  @$core.override
  MissionBody createEmptyInstance() => MissionBody._();
  @$core.pragma('dart2js:noInline')
  static MissionBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MissionBody>(
          MissionBody.$_createMessage);
  static MissionBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get missionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set missionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMissionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMissionId() => $_clearField(1);

  @$pb.TagNumber(2)
  ResourceCategory get cargoCategory => $_getN(1);
  @$pb.TagNumber(2)
  set cargoCategory(ResourceCategory value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCargoCategory() => $_has(1);
  @$pb.TagNumber(2)
  void clearCargoCategory() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get cargoDescription => $_getSZ(2);
  @$pb.TagNumber(3)
  set cargoDescription($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCargoDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearCargoDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get cargoQuantity => $_getI64(3);
  @$pb.TagNumber(4)
  set cargoQuantity($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCargoQuantity() => $_has(3);
  @$pb.TagNumber(4)
  void clearCargoQuantity() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get pickupName => $_getSZ(4);
  @$pb.TagNumber(5)
  set pickupName($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPickupName() => $_has(4);
  @$pb.TagNumber(5)
  void clearPickupName() => $_clearField(5);

  @$pb.TagNumber(6)
  GeoPoint get pickupLocation => $_getN(5);
  @$pb.TagNumber(6)
  set pickupLocation(GeoPoint value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPickupLocation() => $_has(5);
  @$pb.TagNumber(6)
  void clearPickupLocation() => $_clearField(6);
  @$pb.TagNumber(6)
  GeoPoint ensurePickupLocation() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.String get destinationName => $_getSZ(6);
  @$pb.TagNumber(7)
  set destinationName($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDestinationName() => $_has(6);
  @$pb.TagNumber(7)
  void clearDestinationName() => $_clearField(7);

  @$pb.TagNumber(8)
  GeoPoint get destinationLocation => $_getN(7);
  @$pb.TagNumber(8)
  set destinationLocation(GeoPoint value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasDestinationLocation() => $_has(7);
  @$pb.TagNumber(8)
  void clearDestinationLocation() => $_clearField(8);
  @$pb.TagNumber(8)
  GeoPoint ensureDestinationLocation() => $_ensure(7);

  @$pb.TagNumber(9)
  Priority get priority => $_getN(8);
  @$pb.TagNumber(9)
  set priority(Priority value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasPriority() => $_has(8);
  @$pb.TagNumber(9)
  void clearPriority() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get channelId => $_getSZ(9);
  @$pb.TagNumber(10)
  set channelId($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasChannelId() => $_has(9);
  @$pb.TagNumber(10)
  void clearChannelId() => $_clearField(10);
}

class MissionAcceptBody extends $pb.GeneratedMessage {
  factory MissionAcceptBody({
    $core.String? missionId,
    $core.List<$core.int>? carrierPubkey,
  }) {
    final result = MissionAcceptBody._();
    if (missionId != null) result.missionId = missionId;
    if (carrierPubkey != null) result.carrierPubkey = carrierPubkey;
    return result;
  }

  MissionAcceptBody._();

  factory MissionAcceptBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MissionAcceptBody()..mergeFromBuffer(data, registry);
  factory MissionAcceptBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MissionAcceptBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MissionAcceptBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: MissionAcceptBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'missionId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'carrierPubkey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MissionAcceptBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MissionAcceptBody copyWith(void Function(MissionAcceptBody) updates) =>
      super.copyWith((message) => updates(message as MissionAcceptBody))
          as MissionAcceptBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MissionAcceptBody() / MissionAcceptBody.new instead')
  static MissionAcceptBody create() => MissionAcceptBody._();
  static $pb.GeneratedMessage $_createMessage() => MissionAcceptBody._();
  @$core.override
  MissionAcceptBody createEmptyInstance() => MissionAcceptBody._();
  @$core.pragma('dart2js:noInline')
  static MissionAcceptBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MissionAcceptBody>(
          MissionAcceptBody.$_createMessage);
  static MissionAcceptBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get missionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set missionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMissionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMissionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get carrierPubkey => $_getN(1);
  @$pb.TagNumber(2)
  set carrierPubkey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCarrierPubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearCarrierPubkey() => $_clearField(2);
}

class MissionMatchBody extends $pb.GeneratedMessage {
  factory MissionMatchBody({
    $core.String? missionId,
    $core.String? requestId,
    $core.String? offerId,
  }) {
    final result = MissionMatchBody._();
    if (missionId != null) result.missionId = missionId;
    if (requestId != null) result.requestId = requestId;
    if (offerId != null) result.offerId = offerId;
    return result;
  }

  MissionMatchBody._();

  factory MissionMatchBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MissionMatchBody()..mergeFromBuffer(data, registry);
  factory MissionMatchBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MissionMatchBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MissionMatchBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: MissionMatchBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'missionId')
    ..aOS(2, _omitFieldNames ? '' : 'requestId')
    ..aOS(3, _omitFieldNames ? '' : 'offerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MissionMatchBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MissionMatchBody copyWith(void Function(MissionMatchBody) updates) =>
      super.copyWith((message) => updates(message as MissionMatchBody))
          as MissionMatchBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MissionMatchBody() / MissionMatchBody.new instead')
  static MissionMatchBody create() => MissionMatchBody._();
  static $pb.GeneratedMessage $_createMessage() => MissionMatchBody._();
  @$core.override
  MissionMatchBody createEmptyInstance() => MissionMatchBody._();
  @$core.pragma('dart2js:noInline')
  static MissionMatchBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MissionMatchBody>(
          MissionMatchBody.$_createMessage);
  static MissionMatchBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get missionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set missionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMissionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMissionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get offerId => $_getSZ(2);
  @$pb.TagNumber(3)
  set offerId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOfferId() => $_has(2);
  @$pb.TagNumber(3)
  void clearOfferId() => $_clearField(3);
}

/// Signed package lifecycle events (QR-driven).
class PackageEventBody extends $pb.GeneratedMessage {
  factory PackageEventBody({
    $core.String? packageId,
    $core.String? missionId,
    $core.List<$core.int>? actorPubkey,
    $core.List<$core.int>? counterpartyPubkey,
    PackageEventBody_Stage? stage,
    $fixnum.Int64? atMs,
  }) {
    final result = PackageEventBody._();
    if (packageId != null) result.packageId = packageId;
    if (missionId != null) result.missionId = missionId;
    if (actorPubkey != null) result.actorPubkey = actorPubkey;
    if (counterpartyPubkey != null)
      result.counterpartyPubkey = counterpartyPubkey;
    if (stage != null) result.stage = stage;
    if (atMs != null) result.atMs = atMs;
    return result;
  }

  PackageEventBody._();

  factory PackageEventBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PackageEventBody()..mergeFromBuffer(data, registry);
  factory PackageEventBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PackageEventBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PackageEventBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: PackageEventBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'packageId')
    ..aOS(2, _omitFieldNames ? '' : 'missionId')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'actorPubkey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'counterpartyPubkey', $pb.PbFieldType.OY)
    ..aE<PackageEventBody_Stage>(5, _omitFieldNames ? '' : 'stage',
        enumValues: PackageEventBody_Stage.values)
    ..aInt64(6, _omitFieldNames ? '' : 'atMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PackageEventBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PackageEventBody copyWith(void Function(PackageEventBody) updates) =>
      super.copyWith((message) => updates(message as PackageEventBody))
          as PackageEventBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PackageEventBody() / PackageEventBody.new instead')
  static PackageEventBody create() => PackageEventBody._();
  static $pb.GeneratedMessage $_createMessage() => PackageEventBody._();
  @$core.override
  PackageEventBody createEmptyInstance() => PackageEventBody._();
  @$core.pragma('dart2js:noInline')
  static PackageEventBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PackageEventBody>(
          PackageEventBody.$_createMessage);
  static PackageEventBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get packageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set packageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPackageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPackageId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get missionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set missionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMissionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMissionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get actorPubkey => $_getN(2);
  @$pb.TagNumber(3)
  set actorPubkey($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActorPubkey() => $_has(2);
  @$pb.TagNumber(3)
  void clearActorPubkey() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get counterpartyPubkey => $_getN(3);
  @$pb.TagNumber(4)
  set counterpartyPubkey($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCounterpartyPubkey() => $_has(3);
  @$pb.TagNumber(4)
  void clearCounterpartyPubkey() => $_clearField(4);

  @$pb.TagNumber(5)
  PackageEventBody_Stage get stage => $_getN(4);
  @$pb.TagNumber(5)
  set stage(PackageEventBody_Stage value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasStage() => $_has(4);
  @$pb.TagNumber(5)
  void clearStage() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get atMs => $_getI64(5);
  @$pb.TagNumber(6)
  set atMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAtMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearAtMs() => $_clearField(6);
}

class CapabilityBody extends $pb.GeneratedMessage {
  factory CapabilityBody({
    $core.String? capabilityId,
    $core.List<$core.int>? subjectPubkey,
    $core.List<$core.int>? issuerPubkey,
    $core.String? scope,
    $core.Iterable<$core.String>? actions,
    $fixnum.Int64? validUntilMs,
  }) {
    final result = CapabilityBody._();
    if (capabilityId != null) result.capabilityId = capabilityId;
    if (subjectPubkey != null) result.subjectPubkey = subjectPubkey;
    if (issuerPubkey != null) result.issuerPubkey = issuerPubkey;
    if (scope != null) result.scope = scope;
    if (actions != null) result.actions.addAll(actions);
    if (validUntilMs != null) result.validUntilMs = validUntilMs;
    return result;
  }

  CapabilityBody._();

  factory CapabilityBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CapabilityBody()..mergeFromBuffer(data, registry);
  factory CapabilityBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CapabilityBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CapabilityBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: CapabilityBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'capabilityId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'subjectPubkey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'issuerPubkey', $pb.PbFieldType.OY)
    ..aOS(4, _omitFieldNames ? '' : 'scope')
    ..pPS(5, _omitFieldNames ? '' : 'actions')
    ..aInt64(6, _omitFieldNames ? '' : 'validUntilMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CapabilityBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CapabilityBody copyWith(void Function(CapabilityBody) updates) =>
      super.copyWith((message) => updates(message as CapabilityBody))
          as CapabilityBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CapabilityBody() / CapabilityBody.new instead')
  static CapabilityBody create() => CapabilityBody._();
  static $pb.GeneratedMessage $_createMessage() => CapabilityBody._();
  @$core.override
  CapabilityBody createEmptyInstance() => CapabilityBody._();
  @$core.pragma('dart2js:noInline')
  static CapabilityBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CapabilityBody>(
          CapabilityBody.$_createMessage);
  static CapabilityBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get capabilityId => $_getSZ(0);
  @$pb.TagNumber(1)
  set capabilityId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCapabilityId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCapabilityId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get subjectPubkey => $_getN(1);
  @$pb.TagNumber(2)
  set subjectPubkey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSubjectPubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubjectPubkey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get issuerPubkey => $_getN(2);
  @$pb.TagNumber(3)
  set issuerPubkey($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIssuerPubkey() => $_has(2);
  @$pb.TagNumber(3)
  void clearIssuerPubkey() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get scope => $_getSZ(3);
  @$pb.TagNumber(4)
  set scope($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasScope() => $_has(3);
  @$pb.TagNumber(4)
  void clearScope() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get actions => $_getList(4);

  @$pb.TagNumber(6)
  $fixnum.Int64 get validUntilMs => $_getI64(5);
  @$pb.TagNumber(6)
  set validUntilMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasValidUntilMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearValidUntilMs() => $_clearField(6);
}

class EmergencyAlertBody extends $pb.GeneratedMessage {
  factory EmergencyAlertBody({
    $core.String? alertId,
    $core.String? title,
    $core.String? detail,
    Priority? priority,
    GeoPoint? area,
    $fixnum.Int64? expiresMs,
  }) {
    final result = EmergencyAlertBody._();
    if (alertId != null) result.alertId = alertId;
    if (title != null) result.title = title;
    if (detail != null) result.detail = detail;
    if (priority != null) result.priority = priority;
    if (area != null) result.area = area;
    if (expiresMs != null) result.expiresMs = expiresMs;
    return result;
  }

  EmergencyAlertBody._();

  factory EmergencyAlertBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EmergencyAlertBody()..mergeFromBuffer(data, registry);
  factory EmergencyAlertBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EmergencyAlertBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EmergencyAlertBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: EmergencyAlertBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'alertId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'detail')
    ..aE<Priority>(4, _omitFieldNames ? '' : 'priority',
        enumValues: Priority.values)
    ..aOM<GeoPoint>(5, _omitFieldNames ? '' : 'area',
        subBuilder: GeoPoint.$_createMessage)
    ..aInt64(6, _omitFieldNames ? '' : 'expiresMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EmergencyAlertBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EmergencyAlertBody copyWith(void Function(EmergencyAlertBody) updates) =>
      super.copyWith((message) => updates(message as EmergencyAlertBody))
          as EmergencyAlertBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EmergencyAlertBody() / EmergencyAlertBody.new instead')
  static EmergencyAlertBody create() => EmergencyAlertBody._();
  static $pb.GeneratedMessage $_createMessage() => EmergencyAlertBody._();
  @$core.override
  EmergencyAlertBody createEmptyInstance() => EmergencyAlertBody._();
  @$core.pragma('dart2js:noInline')
  static EmergencyAlertBody getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EmergencyAlertBody>(
          EmergencyAlertBody.$_createMessage);
  static EmergencyAlertBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get alertId => $_getSZ(0);
  @$pb.TagNumber(1)
  set alertId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAlertId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAlertId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get detail => $_getSZ(2);
  @$pb.TagNumber(3)
  set detail($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDetail() => $_has(2);
  @$pb.TagNumber(3)
  void clearDetail() => $_clearField(3);

  @$pb.TagNumber(4)
  Priority get priority => $_getN(3);
  @$pb.TagNumber(4)
  set priority(Priority value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPriority() => $_has(3);
  @$pb.TagNumber(4)
  void clearPriority() => $_clearField(4);

  @$pb.TagNumber(5)
  GeoPoint get area => $_getN(4);
  @$pb.TagNumber(5)
  set area(GeoPoint value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasArea() => $_has(4);
  @$pb.TagNumber(5)
  void clearArea() => $_clearField(5);
  @$pb.TagNumber(5)
  GeoPoint ensureArea() => $_ensure(4);

  @$pb.TagNumber(6)
  $fixnum.Int64 get expiresMs => $_getI64(5);
  @$pb.TagNumber(6)
  set expiresMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasExpiresMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearExpiresMs() => $_clearField(6);
}

/// --- Location sharing (opt-in, audience-scoped, revocable, privacy-first) ----
///
/// DESIGN RULES (must hold for the civil-unrest / hostile-listener threat model):
///   * Sharing is OFF by default and requires explicit per-share user consent.
///   * The audience is chosen each time: a single contact, a channel/group, or
///     a public beacon. `scope` names it.
///   * Ephemeral + revocable: `expires_ms` bounds the share; a LOCATION_STOP
///     event (or expiry) ends it. UI must let the user stop at any time.
///   * Granularity is the user's choice: a coarse `h3_cell` only, OR exact
///     coordinates. For non-public audiences the point should be delivered as
///     ciphertext (see `encrypted_point`) so relays never see coordinates.
///   * Relays/mesh see only `scope`, coarse `h3_cell` (if the user allowed it),
///     and opaque ciphertext — never a name, phone number, or exact address.
class LocationShareBody extends $pb.GeneratedMessage {
  factory LocationShareBody({
    $core.String? shareId,
    $core.String? scope,
    $fixnum.Int64? h3Cell,
    GeoPoint? publicPoint,
    $core.List<$core.int>? encryptedPoint,
    $fixnum.Int64? expiresMs,
    $core.String? note,
    $fixnum.Int64? seq,
  }) {
    final result = LocationShareBody._();
    if (shareId != null) result.shareId = shareId;
    if (scope != null) result.scope = scope;
    if (h3Cell != null) result.h3Cell = h3Cell;
    if (publicPoint != null) result.publicPoint = publicPoint;
    if (encryptedPoint != null) result.encryptedPoint = encryptedPoint;
    if (expiresMs != null) result.expiresMs = expiresMs;
    if (note != null) result.note = note;
    if (seq != null) result.seq = seq;
    return result;
  }

  LocationShareBody._();

  factory LocationShareBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LocationShareBody()..mergeFromBuffer(data, registry);
  factory LocationShareBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LocationShareBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LocationShareBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: LocationShareBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'shareId')
    ..aOS(2, _omitFieldNames ? '' : 'scope')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'h3Cell', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<GeoPoint>(4, _omitFieldNames ? '' : 'publicPoint',
        subBuilder: GeoPoint.$_createMessage)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'encryptedPoint', $pb.PbFieldType.OY)
    ..aInt64(6, _omitFieldNames ? '' : 'expiresMs')
    ..aOS(7, _omitFieldNames ? '' : 'note')
    ..a<$fixnum.Int64>(8, _omitFieldNames ? '' : 'seq', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LocationShareBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LocationShareBody copyWith(void Function(LocationShareBody) updates) =>
      super.copyWith((message) => updates(message as LocationShareBody))
          as LocationShareBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LocationShareBody() / LocationShareBody.new instead')
  static LocationShareBody create() => LocationShareBody._();
  static $pb.GeneratedMessage $_createMessage() => LocationShareBody._();
  @$core.override
  LocationShareBody createEmptyInstance() => LocationShareBody._();
  @$core.pragma('dart2js:noInline')
  static LocationShareBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LocationShareBody>(
          LocationShareBody.$_createMessage);
  static LocationShareBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get shareId => $_getSZ(0);
  @$pb.TagNumber(1)
  set shareId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasShareId() => $_has(0);
  @$pb.TagNumber(1)
  void clearShareId() => $_clearField(1);

  /// Audience scope for this share. Exactly one meaning per share:
  ///   "contact:PUBKEYHEX"  — one recipient (encrypted_point set)
  ///   "channel:CHANNELID"  — a group/community/mission channel
  ///   "public"             — an opt-in public beacon (coarse only)
  @$pb.TagNumber(2)
  $core.String get scope => $_getSZ(1);
  @$pb.TagNumber(2)
  set scope($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasScope() => $_has(1);
  @$pb.TagNumber(2)
  void clearScope() => $_clearField(2);

  /// Coarse geospatial bucket the user explicitly allowed to travel in the
  /// clear (e.g. "I'm in this neighborhood"). 0 if the user shared nothing
  /// coarse. Safe to broadcast; cannot pinpoint an individual.
  @$pb.TagNumber(3)
  $fixnum.Int64 get h3Cell => $_getI64(2);
  @$pb.TagNumber(3)
  set h3Cell($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasH3Cell() => $_has(2);
  @$pb.TagNumber(3)
  void clearH3Cell() => $_clearField(3);

  /// Plaintext point ONLY for a deliberately public beacon where the user chose
  /// to reveal precise location. For contact/channel scopes this MUST be empty
  /// and the precise point travels in `encrypted_point` instead.
  @$pb.TagNumber(4)
  GeoPoint get publicPoint => $_getN(3);
  @$pb.TagNumber(4)
  set publicPoint(GeoPoint value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPublicPoint() => $_has(3);
  @$pb.TagNumber(4)
  void clearPublicPoint() => $_clearField(4);
  @$pb.TagNumber(4)
  GeoPoint ensurePublicPoint() => $_ensure(3);

  /// The precise location encrypted to the chosen audience (Signal 1:1 for a
  /// contact, Sender-Key for a channel). Opaque to relays. Empty for a coarse-
  /// only or public-point share.
  @$pb.TagNumber(5)
  $core.List<$core.int> get encryptedPoint => $_getN(4);
  @$pb.TagNumber(5)
  set encryptedPoint($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEncryptedPoint() => $_has(4);
  @$pb.TagNumber(5)
  void clearEncryptedPoint() => $_clearField(5);

  /// When this share stops being valid (unix millis). Always set; a share is
  /// never indefinite by default. UI surfaces the countdown.
  @$pb.TagNumber(6)
  $fixnum.Int64 get expiresMs => $_getI64(5);
  @$pb.TagNumber(6)
  set expiresMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasExpiresMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearExpiresMs() => $_clearField(6);

  /// Optional short note ("moving toward the north exit"). For non-public
  /// audiences this should also be encrypted; keep empty on the public path.
  @$pb.TagNumber(7)
  $core.String get note => $_getSZ(6);
  @$pb.TagNumber(7)
  set note($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasNote() => $_has(6);
  @$pb.TagNumber(7)
  void clearNote() => $_clearField(7);

  /// Monotonic sequence so a stream of updates for one share_id orders itself.
  @$pb.TagNumber(8)
  $fixnum.Int64 get seq => $_getI64(7);
  @$pb.TagNumber(8)
  set seq($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSeq() => $_has(7);
  @$pb.TagNumber(8)
  void clearSeq() => $_clearField(8);
}

/// Revokes/stops an active share (or all shares by the author when share_id is
/// empty). Signed by the sharer; honored even if it arrives before `expires_ms`.
class LocationStopBody extends $pb.GeneratedMessage {
  factory LocationStopBody({
    $core.String? shareId,
    $fixnum.Int64? stoppedAtMs,
  }) {
    final result = LocationStopBody._();
    if (shareId != null) result.shareId = shareId;
    if (stoppedAtMs != null) result.stoppedAtMs = stoppedAtMs;
    return result;
  }

  LocationStopBody._();

  factory LocationStopBody.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LocationStopBody()..mergeFromBuffer(data, registry);
  factory LocationStopBody.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LocationStopBody()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LocationStopBody',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: LocationStopBody.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'shareId')
    ..aInt64(2, _omitFieldNames ? '' : 'stoppedAtMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LocationStopBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LocationStopBody copyWith(void Function(LocationStopBody) updates) =>
      super.copyWith((message) => updates(message as LocationStopBody))
          as LocationStopBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LocationStopBody() / LocationStopBody.new instead')
  static LocationStopBody create() => LocationStopBody._();
  static $pb.GeneratedMessage $_createMessage() => LocationStopBody._();
  @$core.override
  LocationStopBody createEmptyInstance() => LocationStopBody._();
  @$core.pragma('dart2js:noInline')
  static LocationStopBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LocationStopBody>(
          LocationStopBody.$_createMessage);
  static LocationStopBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get shareId => $_getSZ(0);
  @$pb.TagNumber(1)
  set shareId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasShareId() => $_has(0);
  @$pb.TagNumber(1)
  void clearShareId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get stoppedAtMs => $_getI64(1);
  @$pb.TagNumber(2)
  set stoppedAtMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStoppedAtMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearStoppedAtMs() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
