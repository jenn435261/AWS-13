// This is a generated file - do not edit.
//
// Generated from resilience/v1/sync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'event.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

enum SyncFrame_Frame { hello, have, want, batch, ack, mesh, notSet }

/// A gossip frame is the outermost unit exchanged on a transport session.
class SyncFrame extends $pb.GeneratedMessage {
  factory SyncFrame({
    Hello? hello,
    HaveDigest? have,
    WantList? want,
    EventBatch? batch,
    Ack? ack,
    MeshPacket? mesh,
  }) {
    final result = SyncFrame._();
    if (hello != null) result.hello = hello;
    if (have != null) result.have = have;
    if (want != null) result.want = want;
    if (batch != null) result.batch = batch;
    if (ack != null) result.ack = ack;
    if (mesh != null) result.mesh = mesh;
    return result;
  }

  SyncFrame._();

  factory SyncFrame.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncFrame()..mergeFromBuffer(data, registry);
  factory SyncFrame.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncFrame()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, SyncFrame_Frame> _SyncFrame_FrameByTag = {
    1: SyncFrame_Frame.hello,
    2: SyncFrame_Frame.have,
    3: SyncFrame_Frame.want,
    4: SyncFrame_Frame.batch,
    5: SyncFrame_Frame.ack,
    6: SyncFrame_Frame.mesh,
    0: SyncFrame_Frame.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncFrame',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: SyncFrame.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5, 6])
    ..aOM<Hello>(1, _omitFieldNames ? '' : 'hello',
        subBuilder: Hello.$_createMessage)
    ..aOM<HaveDigest>(2, _omitFieldNames ? '' : 'have',
        subBuilder: HaveDigest.$_createMessage)
    ..aOM<WantList>(3, _omitFieldNames ? '' : 'want',
        subBuilder: WantList.$_createMessage)
    ..aOM<EventBatch>(4, _omitFieldNames ? '' : 'batch',
        subBuilder: EventBatch.$_createMessage)
    ..aOM<Ack>(5, _omitFieldNames ? '' : 'ack', subBuilder: Ack.$_createMessage)
    ..aOM<MeshPacket>(6, _omitFieldNames ? '' : 'mesh',
        subBuilder: MeshPacket.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncFrame clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncFrame copyWith(void Function(SyncFrame) updates) =>
      super.copyWith((message) => updates(message as SyncFrame)) as SyncFrame;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SyncFrame() / SyncFrame.new instead')
  static SyncFrame create() => SyncFrame._();
  static $pb.GeneratedMessage $_createMessage() => SyncFrame._();
  @$core.override
  SyncFrame createEmptyInstance() => SyncFrame._();
  @$core.pragma('dart2js:noInline')
  static SyncFrame getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncFrame>(SyncFrame.$_createMessage);
  static SyncFrame? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  SyncFrame_Frame whichFrame() => _SyncFrame_FrameByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  void clearFrame() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  Hello get hello => $_getN(0);
  @$pb.TagNumber(1)
  set hello(Hello value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHello() => $_has(0);
  @$pb.TagNumber(1)
  void clearHello() => $_clearField(1);
  @$pb.TagNumber(1)
  Hello ensureHello() => $_ensure(0);

  @$pb.TagNumber(2)
  HaveDigest get have => $_getN(1);
  @$pb.TagNumber(2)
  set have(HaveDigest value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasHave() => $_has(1);
  @$pb.TagNumber(2)
  void clearHave() => $_clearField(2);
  @$pb.TagNumber(2)
  HaveDigest ensureHave() => $_ensure(1);

  @$pb.TagNumber(3)
  WantList get want => $_getN(2);
  @$pb.TagNumber(3)
  set want(WantList value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasWant() => $_has(2);
  @$pb.TagNumber(3)
  void clearWant() => $_clearField(3);
  @$pb.TagNumber(3)
  WantList ensureWant() => $_ensure(2);

  @$pb.TagNumber(4)
  EventBatch get batch => $_getN(3);
  @$pb.TagNumber(4)
  set batch(EventBatch value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasBatch() => $_has(3);
  @$pb.TagNumber(4)
  void clearBatch() => $_clearField(4);
  @$pb.TagNumber(4)
  EventBatch ensureBatch() => $_ensure(3);

  @$pb.TagNumber(5)
  Ack get ack => $_getN(4);
  @$pb.TagNumber(5)
  set ack(Ack value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasAck() => $_has(4);
  @$pb.TagNumber(5)
  void clearAck() => $_clearField(5);
  @$pb.TagNumber(5)
  Ack ensureAck() => $_ensure(4);

  @$pb.TagNumber(6)
  MeshPacket get mesh => $_getN(5);
  @$pb.TagNumber(6)
  set mesh(MeshPacket value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasMesh() => $_has(5);
  @$pb.TagNumber(6)
  void clearMesh() => $_clearField(6);
  @$pb.TagNumber(6)
  MeshPacket ensureMesh() => $_ensure(5);
}

class Hello extends $pb.GeneratedMessage {
  factory Hello({
    $core.List<$core.int>? nodePubkey,
    $core.String? softwareVersion,
    $fixnum.Int64? lamportHighWater,
    $core.Iterable<$core.List<$core.int>>? knownAuthors,
  }) {
    final result = Hello._();
    if (nodePubkey != null) result.nodePubkey = nodePubkey;
    if (softwareVersion != null) result.softwareVersion = softwareVersion;
    if (lamportHighWater != null) result.lamportHighWater = lamportHighWater;
    if (knownAuthors != null) result.knownAuthors.addAll(knownAuthors);
    return result;
  }

  Hello._();

  factory Hello.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Hello()..mergeFromBuffer(data, registry);
  factory Hello.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Hello()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Hello',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: Hello.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'nodePubkey', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'softwareVersion')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'lamportHighWater', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..p<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'knownAuthors', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Hello clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Hello copyWith(void Function(Hello) updates) =>
      super.copyWith((message) => updates(message as Hello)) as Hello;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Hello() / Hello.new instead')
  static Hello create() => Hello._();
  static $pb.GeneratedMessage $_createMessage() => Hello._();
  @$core.override
  Hello createEmptyInstance() => Hello._();
  @$core.pragma('dart2js:noInline')
  static Hello getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Hello>(Hello.$_createMessage);
  static Hello? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get nodePubkey => $_getN(0);
  @$pb.TagNumber(1)
  set nodePubkey($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodePubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodePubkey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get softwareVersion => $_getSZ(1);
  @$pb.TagNumber(2)
  set softwareVersion($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSoftwareVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearSoftwareVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get lamportHighWater => $_getI64(2);
  @$pb.TagNumber(3)
  set lamportHighWater($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLamportHighWater() => $_has(2);
  @$pb.TagNumber(3)
  void clearLamportHighWater() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.List<$core.int>> get knownAuthors => $_getList(3);
}

class HaveDigest_AuthorHW extends $pb.GeneratedMessage {
  factory HaveDigest_AuthorHW({
    $core.List<$core.int>? authorPubkey,
    $fixnum.Int64? highWater,
    $core.List<$core.int>? headEventId,
  }) {
    final result = HaveDigest_AuthorHW._();
    if (authorPubkey != null) result.authorPubkey = authorPubkey;
    if (highWater != null) result.highWater = highWater;
    if (headEventId != null) result.headEventId = headEventId;
    return result;
  }

  HaveDigest_AuthorHW._();

  factory HaveDigest_AuthorHW.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HaveDigest_AuthorHW()..mergeFromBuffer(data, registry);
  factory HaveDigest_AuthorHW.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HaveDigest_AuthorHW()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HaveDigest.AuthorHW',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: HaveDigest_AuthorHW.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'authorPubkey', $pb.PbFieldType.OY)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'highWater', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'headEventId', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HaveDigest_AuthorHW clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HaveDigest_AuthorHW copyWith(void Function(HaveDigest_AuthorHW) updates) =>
      super.copyWith((message) => updates(message as HaveDigest_AuthorHW))
          as HaveDigest_AuthorHW;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use HaveDigest_AuthorHW() / HaveDigest_AuthorHW.new instead')
  static HaveDigest_AuthorHW create() => HaveDigest_AuthorHW._();
  static $pb.GeneratedMessage $_createMessage() => HaveDigest_AuthorHW._();
  @$core.override
  HaveDigest_AuthorHW createEmptyInstance() => HaveDigest_AuthorHW._();
  @$core.pragma('dart2js:noInline')
  static HaveDigest_AuthorHW getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HaveDigest_AuthorHW>(
          HaveDigest_AuthorHW.$_createMessage);
  static HaveDigest_AuthorHW? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get authorPubkey => $_getN(0);
  @$pb.TagNumber(1)
  set authorPubkey($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAuthorPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearAuthorPubkey() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get highWater => $_getI64(1);
  @$pb.TagNumber(2)
  set highWater($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHighWater() => $_has(1);
  @$pb.TagNumber(2)
  void clearHighWater() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get headEventId => $_getN(2);
  @$pb.TagNumber(3)
  set headEventId($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeadEventId() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeadEventId() => $_clearField(3);
}

/// Compact digest of held events. We send per-author high-water lamport values
/// plus a bloom filter of recent event ids so the peer can compute the diff
/// without transferring the full id set.
class HaveDigest extends $pb.GeneratedMessage {
  factory HaveDigest({
    $core.Iterable<HaveDigest_AuthorHW>? authors,
    $core.List<$core.int>? bloom,
    $core.int? bloomHashes,
    $core.int? bloomBits,
  }) {
    final result = HaveDigest._();
    if (authors != null) result.authors.addAll(authors);
    if (bloom != null) result.bloom = bloom;
    if (bloomHashes != null) result.bloomHashes = bloomHashes;
    if (bloomBits != null) result.bloomBits = bloomBits;
    return result;
  }

  HaveDigest._();

  factory HaveDigest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HaveDigest()..mergeFromBuffer(data, registry);
  factory HaveDigest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HaveDigest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HaveDigest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: HaveDigest.$_createMessage)
    ..pPM<HaveDigest_AuthorHW>(1, _omitFieldNames ? '' : 'authors',
        subBuilder: HaveDigest_AuthorHW.$_createMessage)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'bloom', $pb.PbFieldType.OY)
    ..aI(3, _omitFieldNames ? '' : 'bloomHashes',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'bloomBits', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HaveDigest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HaveDigest copyWith(void Function(HaveDigest) updates) =>
      super.copyWith((message) => updates(message as HaveDigest)) as HaveDigest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use HaveDigest() / HaveDigest.new instead')
  static HaveDigest create() => HaveDigest._();
  static $pb.GeneratedMessage $_createMessage() => HaveDigest._();
  @$core.override
  HaveDigest createEmptyInstance() => HaveDigest._();
  @$core.pragma('dart2js:noInline')
  static HaveDigest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HaveDigest>(HaveDigest.$_createMessage);
  static HaveDigest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<HaveDigest_AuthorHW> get authors => $_getList(0);

  @$pb.TagNumber(2)
  $core.List<$core.int> get bloom => $_getN(1);
  @$pb.TagNumber(2)
  set bloom($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBloom() => $_has(1);
  @$pb.TagNumber(2)
  void clearBloom() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get bloomHashes => $_getIZ(2);
  @$pb.TagNumber(3)
  set bloomHashes($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBloomHashes() => $_has(2);
  @$pb.TagNumber(3)
  void clearBloomHashes() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get bloomBits => $_getIZ(3);
  @$pb.TagNumber(4)
  set bloomBits($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBloomBits() => $_has(3);
  @$pb.TagNumber(4)
  void clearBloomBits() => $_clearField(4);
}

/// Or request everything above a per-author watermark:
class WantList_AuthorFrom extends $pb.GeneratedMessage {
  factory WantList_AuthorFrom({
    $core.List<$core.int>? authorPubkey,
    $fixnum.Int64? fromLamport,
  }) {
    final result = WantList_AuthorFrom._();
    if (authorPubkey != null) result.authorPubkey = authorPubkey;
    if (fromLamport != null) result.fromLamport = fromLamport;
    return result;
  }

  WantList_AuthorFrom._();

  factory WantList_AuthorFrom.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WantList_AuthorFrom()..mergeFromBuffer(data, registry);
  factory WantList_AuthorFrom.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WantList_AuthorFrom()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WantList.AuthorFrom',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: WantList_AuthorFrom.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'authorPubkey', $pb.PbFieldType.OY)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'fromLamport', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WantList_AuthorFrom clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WantList_AuthorFrom copyWith(void Function(WantList_AuthorFrom) updates) =>
      super.copyWith((message) => updates(message as WantList_AuthorFrom))
          as WantList_AuthorFrom;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use WantList_AuthorFrom() / WantList_AuthorFrom.new instead')
  static WantList_AuthorFrom create() => WantList_AuthorFrom._();
  static $pb.GeneratedMessage $_createMessage() => WantList_AuthorFrom._();
  @$core.override
  WantList_AuthorFrom createEmptyInstance() => WantList_AuthorFrom._();
  @$core.pragma('dart2js:noInline')
  static WantList_AuthorFrom getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WantList_AuthorFrom>(
          WantList_AuthorFrom.$_createMessage);
  static WantList_AuthorFrom? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get authorPubkey => $_getN(0);
  @$pb.TagNumber(1)
  set authorPubkey($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAuthorPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearAuthorPubkey() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get fromLamport => $_getI64(1);
  @$pb.TagNumber(2)
  set fromLamport($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFromLamport() => $_has(1);
  @$pb.TagNumber(2)
  void clearFromLamport() => $_clearField(2);
}

class WantList extends $pb.GeneratedMessage {
  factory WantList({
    $core.Iterable<$core.List<$core.int>>? eventIds,
    $core.Iterable<WantList_AuthorFrom>? from,
  }) {
    final result = WantList._();
    if (eventIds != null) result.eventIds.addAll(eventIds);
    if (from != null) result.from.addAll(from);
    return result;
  }

  WantList._();

  factory WantList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WantList()..mergeFromBuffer(data, registry);
  factory WantList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WantList()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WantList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: WantList.$_createMessage)
    ..p<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'eventIds', $pb.PbFieldType.PY)
    ..pPM<WantList_AuthorFrom>(2, _omitFieldNames ? '' : 'from',
        subBuilder: WantList_AuthorFrom.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WantList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WantList copyWith(void Function(WantList) updates) =>
      super.copyWith((message) => updates(message as WantList)) as WantList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WantList() / WantList.new instead')
  static WantList create() => WantList._();
  static $pb.GeneratedMessage $_createMessage() => WantList._();
  @$core.override
  WantList createEmptyInstance() => WantList._();
  @$core.pragma('dart2js:noInline')
  static WantList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WantList>(WantList.$_createMessage);
  static WantList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.List<$core.int>> get eventIds => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<WantList_AuthorFrom> get from => $_getList(1);
}

class EventBatch extends $pb.GeneratedMessage {
  factory EventBatch({
    $core.Iterable<$1.SignedEvent>? events,
    $core.bool? more,
  }) {
    final result = EventBatch._();
    if (events != null) result.events.addAll(events);
    if (more != null) result.more = more;
    return result;
  }

  EventBatch._();

  factory EventBatch.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EventBatch()..mergeFromBuffer(data, registry);
  factory EventBatch.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EventBatch()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EventBatch',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: EventBatch.$_createMessage)
    ..pPM<$1.SignedEvent>(1, _omitFieldNames ? '' : 'events',
        subBuilder: $1.SignedEvent.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'more')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventBatch clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventBatch copyWith(void Function(EventBatch) updates) =>
      super.copyWith((message) => updates(message as EventBatch)) as EventBatch;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EventBatch() / EventBatch.new instead')
  static EventBatch create() => EventBatch._();
  static $pb.GeneratedMessage $_createMessage() => EventBatch._();
  @$core.override
  EventBatch createEmptyInstance() => EventBatch._();
  @$core.pragma('dart2js:noInline')
  static EventBatch getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EventBatch>(EventBatch.$_createMessage);
  static EventBatch? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$1.SignedEvent> get events => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get more => $_getBF(1);
  @$pb.TagNumber(2)
  set more($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMore() => $_has(1);
  @$pb.TagNumber(2)
  void clearMore() => $_clearField(2);
}

class Ack extends $pb.GeneratedMessage {
  factory Ack({
    $core.Iterable<$core.List<$core.int>>? applied,
    $core.Iterable<$core.List<$core.int>>? rejected,
  }) {
    final result = Ack._();
    if (applied != null) result.applied.addAll(applied);
    if (rejected != null) result.rejected.addAll(rejected);
    return result;
  }

  Ack._();

  factory Ack.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Ack()..mergeFromBuffer(data, registry);
  factory Ack.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Ack()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Ack',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: Ack.$_createMessage)
    ..p<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'applied', $pb.PbFieldType.PY)
    ..p<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'rejected', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ack clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ack copyWith(void Function(Ack) updates) =>
      super.copyWith((message) => updates(message as Ack)) as Ack;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Ack() / Ack.new instead')
  static Ack create() => Ack._();
  static $pb.GeneratedMessage $_createMessage() => Ack._();
  @$core.override
  Ack createEmptyInstance() => Ack._();
  @$core.pragma('dart2js:noInline')
  static Ack getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Ack>(Ack.$_createMessage);
  static Ack? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.List<$core.int>> get applied => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<$core.List<$core.int>> get rejected => $_getList(1);
}

/// Compact packet for LoRa / Meshtastic. Only high-priority small events.
/// Relays see priority, TTL, opaque dest hint, ciphertext — nothing sensitive.
class MeshPacket extends $pb.GeneratedMessage {
  factory MeshPacket({
    $core.List<$core.int>? packetId,
    $1.Priority? priority,
    $core.int? ttl,
    $core.List<$core.int>? destHint,
    $core.List<$core.int>? payload,
    $core.int? fragIndex,
    $core.int? fragTotal,
  }) {
    final result = MeshPacket._();
    if (packetId != null) result.packetId = packetId;
    if (priority != null) result.priority = priority;
    if (ttl != null) result.ttl = ttl;
    if (destHint != null) result.destHint = destHint;
    if (payload != null) result.payload = payload;
    if (fragIndex != null) result.fragIndex = fragIndex;
    if (fragTotal != null) result.fragTotal = fragTotal;
    return result;
  }

  MeshPacket._();

  factory MeshPacket.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MeshPacket()..mergeFromBuffer(data, registry);
  factory MeshPacket.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MeshPacket()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MeshPacket',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: MeshPacket.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'packetId', $pb.PbFieldType.OY)
    ..aE<$1.Priority>(2, _omitFieldNames ? '' : 'priority',
        enumValues: $1.Priority.values)
    ..aI(3, _omitFieldNames ? '' : 'ttl', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'destHint', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..aI(6, _omitFieldNames ? '' : 'fragIndex', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'fragTotal', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MeshPacket clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MeshPacket copyWith(void Function(MeshPacket) updates) =>
      super.copyWith((message) => updates(message as MeshPacket)) as MeshPacket;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MeshPacket() / MeshPacket.new instead')
  static MeshPacket create() => MeshPacket._();
  static $pb.GeneratedMessage $_createMessage() => MeshPacket._();
  @$core.override
  MeshPacket createEmptyInstance() => MeshPacket._();
  @$core.pragma('dart2js:noInline')
  static MeshPacket getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MeshPacket>(MeshPacket.$_createMessage);
  static MeshPacket? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get packetId => $_getN(0);
  @$pb.TagNumber(1)
  set packetId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPacketId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPacketId() => $_clearField(1);

  @$pb.TagNumber(2)
  $1.Priority get priority => $_getN(1);
  @$pb.TagNumber(2)
  set priority($1.Priority value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPriority() => $_has(1);
  @$pb.TagNumber(2)
  void clearPriority() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get ttl => $_getIZ(2);
  @$pb.TagNumber(3)
  set ttl($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTtl() => $_has(2);
  @$pb.TagNumber(3)
  void clearTtl() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get destHint => $_getN(3);
  @$pb.TagNumber(4)
  set destHint($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDestHint() => $_has(3);
  @$pb.TagNumber(4)
  void clearDestHint() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get payload => $_getN(4);
  @$pb.TagNumber(5)
  set payload($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPayload() => $_has(4);
  @$pb.TagNumber(5)
  void clearPayload() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get fragIndex => $_getIZ(5);
  @$pb.TagNumber(6)
  set fragIndex($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFragIndex() => $_has(5);
  @$pb.TagNumber(6)
  void clearFragIndex() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get fragTotal => $_getIZ(6);
  @$pb.TagNumber(7)
  set fragTotal($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasFragTotal() => $_has(6);
  @$pb.TagNumber(7)
  void clearFragTotal() => $_clearField(7);
}

class PushEventsRequest extends $pb.GeneratedMessage {
  factory PushEventsRequest({
    $core.Iterable<$1.SignedEvent>? events,
  }) {
    final result = PushEventsRequest._();
    if (events != null) result.events.addAll(events);
    return result;
  }

  PushEventsRequest._();

  factory PushEventsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PushEventsRequest()..mergeFromBuffer(data, registry);
  factory PushEventsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PushEventsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PushEventsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: PushEventsRequest.$_createMessage)
    ..pPM<$1.SignedEvent>(1, _omitFieldNames ? '' : 'events',
        subBuilder: $1.SignedEvent.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PushEventsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PushEventsRequest copyWith(void Function(PushEventsRequest) updates) =>
      super.copyWith((message) => updates(message as PushEventsRequest))
          as PushEventsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PushEventsRequest() / PushEventsRequest.new instead')
  static PushEventsRequest create() => PushEventsRequest._();
  static $pb.GeneratedMessage $_createMessage() => PushEventsRequest._();
  @$core.override
  PushEventsRequest createEmptyInstance() => PushEventsRequest._();
  @$core.pragma('dart2js:noInline')
  static PushEventsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PushEventsRequest>(
          PushEventsRequest.$_createMessage);
  static PushEventsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$1.SignedEvent> get events => $_getList(0);
}

class PushEventsResponse extends $pb.GeneratedMessage {
  factory PushEventsResponse({
    Ack? ack,
  }) {
    final result = PushEventsResponse._();
    if (ack != null) result.ack = ack;
    return result;
  }

  PushEventsResponse._();

  factory PushEventsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PushEventsResponse()..mergeFromBuffer(data, registry);
  factory PushEventsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PushEventsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PushEventsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: PushEventsResponse.$_createMessage)
    ..aOM<Ack>(1, _omitFieldNames ? '' : 'ack', subBuilder: Ack.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PushEventsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PushEventsResponse copyWith(void Function(PushEventsResponse) updates) =>
      super.copyWith((message) => updates(message as PushEventsResponse))
          as PushEventsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PushEventsResponse() / PushEventsResponse.new instead')
  static PushEventsResponse create() => PushEventsResponse._();
  static $pb.GeneratedMessage $_createMessage() => PushEventsResponse._();
  @$core.override
  PushEventsResponse createEmptyInstance() => PushEventsResponse._();
  @$core.pragma('dart2js:noInline')
  static PushEventsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PushEventsResponse>(
          PushEventsResponse.$_createMessage);
  static PushEventsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Ack get ack => $_getN(0);
  @$pb.TagNumber(1)
  set ack(Ack value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAck() => $_has(0);
  @$pb.TagNumber(1)
  void clearAck() => $_clearField(1);
  @$pb.TagNumber(1)
  Ack ensureAck() => $_ensure(0);
}

class PullEventsRequest_AuthorFrom extends $pb.GeneratedMessage {
  factory PullEventsRequest_AuthorFrom({
    $core.List<$core.int>? authorPubkey,
    $fixnum.Int64? fromLamport,
  }) {
    final result = PullEventsRequest_AuthorFrom._();
    if (authorPubkey != null) result.authorPubkey = authorPubkey;
    if (fromLamport != null) result.fromLamport = fromLamport;
    return result;
  }

  PullEventsRequest_AuthorFrom._();

  factory PullEventsRequest_AuthorFrom.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PullEventsRequest_AuthorFrom()..mergeFromBuffer(data, registry);
  factory PullEventsRequest_AuthorFrom.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PullEventsRequest_AuthorFrom()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PullEventsRequest.AuthorFrom',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: PullEventsRequest_AuthorFrom.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'authorPubkey', $pb.PbFieldType.OY)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'fromLamport', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullEventsRequest_AuthorFrom clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullEventsRequest_AuthorFrom copyWith(
          void Function(PullEventsRequest_AuthorFrom) updates) =>
      super.copyWith(
              (message) => updates(message as PullEventsRequest_AuthorFrom))
          as PullEventsRequest_AuthorFrom;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PullEventsRequest_AuthorFrom() / PullEventsRequest_AuthorFrom.new instead')
  static PullEventsRequest_AuthorFrom create() =>
      PullEventsRequest_AuthorFrom._();
  static $pb.GeneratedMessage $_createMessage() =>
      PullEventsRequest_AuthorFrom._();
  @$core.override
  PullEventsRequest_AuthorFrom createEmptyInstance() =>
      PullEventsRequest_AuthorFrom._();
  @$core.pragma('dart2js:noInline')
  static PullEventsRequest_AuthorFrom getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PullEventsRequest_AuthorFrom>(
          PullEventsRequest_AuthorFrom.$_createMessage);
  static PullEventsRequest_AuthorFrom? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get authorPubkey => $_getN(0);
  @$pb.TagNumber(1)
  set authorPubkey($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAuthorPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearAuthorPubkey() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get fromLamport => $_getI64(1);
  @$pb.TagNumber(2)
  set fromLamport($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFromLamport() => $_has(1);
  @$pb.TagNumber(2)
  void clearFromLamport() => $_clearField(2);
}

class PullEventsRequest extends $pb.GeneratedMessage {
  factory PullEventsRequest({
    $core.Iterable<PullEventsRequest_AuthorFrom>? from,
    $fixnum.Int64? h3Cell,
    $core.int? limit,
  }) {
    final result = PullEventsRequest._();
    if (from != null) result.from.addAll(from);
    if (h3Cell != null) result.h3Cell = h3Cell;
    if (limit != null) result.limit = limit;
    return result;
  }

  PullEventsRequest._();

  factory PullEventsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PullEventsRequest()..mergeFromBuffer(data, registry);
  factory PullEventsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PullEventsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PullEventsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: PullEventsRequest.$_createMessage)
    ..pPM<PullEventsRequest_AuthorFrom>(1, _omitFieldNames ? '' : 'from',
        subBuilder: PullEventsRequest_AuthorFrom.$_createMessage)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'h3Cell', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(3, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullEventsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullEventsRequest copyWith(void Function(PullEventsRequest) updates) =>
      super.copyWith((message) => updates(message as PullEventsRequest))
          as PullEventsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PullEventsRequest() / PullEventsRequest.new instead')
  static PullEventsRequest create() => PullEventsRequest._();
  static $pb.GeneratedMessage $_createMessage() => PullEventsRequest._();
  @$core.override
  PullEventsRequest createEmptyInstance() => PullEventsRequest._();
  @$core.pragma('dart2js:noInline')
  static PullEventsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PullEventsRequest>(
          PullEventsRequest.$_createMessage);
  static PullEventsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PullEventsRequest_AuthorFrom> get from => $_getList(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get h3Cell => $_getI64(1);
  @$pb.TagNumber(2)
  set h3Cell($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasH3Cell() => $_has(1);
  @$pb.TagNumber(2)
  void clearH3Cell() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get limit => $_getIZ(2);
  @$pb.TagNumber(3)
  set limit($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimit() => $_clearField(3);
}

class PullEventsResponse extends $pb.GeneratedMessage {
  factory PullEventsResponse({
    EventBatch? batch,
  }) {
    final result = PullEventsResponse._();
    if (batch != null) result.batch = batch;
    return result;
  }

  PullEventsResponse._();

  factory PullEventsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PullEventsResponse()..mergeFromBuffer(data, registry);
  factory PullEventsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PullEventsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PullEventsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'resilience.v1'),
      createEmptyInstance: PullEventsResponse.$_createMessage)
    ..aOM<EventBatch>(1, _omitFieldNames ? '' : 'batch',
        subBuilder: EventBatch.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullEventsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullEventsResponse copyWith(void Function(PullEventsResponse) updates) =>
      super.copyWith((message) => updates(message as PullEventsResponse))
          as PullEventsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PullEventsResponse() / PullEventsResponse.new instead')
  static PullEventsResponse create() => PullEventsResponse._();
  static $pb.GeneratedMessage $_createMessage() => PullEventsResponse._();
  @$core.override
  PullEventsResponse createEmptyInstance() => PullEventsResponse._();
  @$core.pragma('dart2js:noInline')
  static PullEventsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PullEventsResponse>(
          PullEventsResponse.$_createMessage);
  static PullEventsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  EventBatch get batch => $_getN(0);
  @$pb.TagNumber(1)
  set batch(EventBatch value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasBatch() => $_has(0);
  @$pb.TagNumber(1)
  void clearBatch() => $_clearField(1);
  @$pb.TagNumber(1)
  EventBatch ensureBatch() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
