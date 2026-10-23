// This is a generated file - do not edit.
//
// Generated from resilience/v1/sync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use syncFrameDescriptor instead')
const SyncFrame$json = {
  '1': 'SyncFrame',
  '2': [
    {
      '1': 'hello',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.Hello',
      '9': 0,
      '10': 'hello'
    },
    {
      '1': 'have',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.HaveDigest',
      '9': 0,
      '10': 'have'
    },
    {
      '1': 'want',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.WantList',
      '9': 0,
      '10': 'want'
    },
    {
      '1': 'batch',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.EventBatch',
      '9': 0,
      '10': 'batch'
    },
    {
      '1': 'ack',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.Ack',
      '9': 0,
      '10': 'ack'
    },
    {
      '1': 'mesh',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.MeshPacket',
      '9': 0,
      '10': 'mesh'
    },
  ],
  '8': [
    {'1': 'frame'},
  ],
};

/// Descriptor for `SyncFrame`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncFrameDescriptor = $convert.base64Decode(
    'CglTeW5jRnJhbWUSLAoFaGVsbG8YASABKAsyFC5yZXNpbGllbmNlLnYxLkhlbGxvSABSBWhlbG'
    'xvEi8KBGhhdmUYAiABKAsyGS5yZXNpbGllbmNlLnYxLkhhdmVEaWdlc3RIAFIEaGF2ZRItCgR3'
    'YW50GAMgASgLMhcucmVzaWxpZW5jZS52MS5XYW50TGlzdEgAUgR3YW50EjEKBWJhdGNoGAQgAS'
    'gLMhkucmVzaWxpZW5jZS52MS5FdmVudEJhdGNoSABSBWJhdGNoEiYKA2FjaxgFIAEoCzISLnJl'
    'c2lsaWVuY2UudjEuQWNrSABSA2FjaxIvCgRtZXNoGAYgASgLMhkucmVzaWxpZW5jZS52MS5NZX'
    'NoUGFja2V0SABSBG1lc2hCBwoFZnJhbWU=');

@$core.Deprecated('Use helloDescriptor instead')
const Hello$json = {
  '1': 'Hello',
  '2': [
    {'1': 'node_pubkey', '3': 1, '4': 1, '5': 12, '10': 'nodePubkey'},
    {'1': 'software_version', '3': 2, '4': 1, '5': 9, '10': 'softwareVersion'},
    {
      '1': 'lamport_high_water',
      '3': 3,
      '4': 1,
      '5': 4,
      '10': 'lamportHighWater'
    },
    {'1': 'known_authors', '3': 4, '4': 3, '5': 12, '10': 'knownAuthors'},
  ],
};

/// Descriptor for `Hello`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List helloDescriptor = $convert.base64Decode(
    'CgVIZWxsbxIfCgtub2RlX3B1YmtleRgBIAEoDFIKbm9kZVB1YmtleRIpChBzb2Z0d2FyZV92ZX'
    'JzaW9uGAIgASgJUg9zb2Z0d2FyZVZlcnNpb24SLAoSbGFtcG9ydF9oaWdoX3dhdGVyGAMgASgE'
    'UhBsYW1wb3J0SGlnaFdhdGVyEiMKDWtub3duX2F1dGhvcnMYBCADKAxSDGtub3duQXV0aG9ycw'
    '==');

@$core.Deprecated('Use haveDigestDescriptor instead')
const HaveDigest$json = {
  '1': 'HaveDigest',
  '2': [
    {
      '1': 'authors',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.resilience.v1.HaveDigest.AuthorHW',
      '10': 'authors'
    },
    {'1': 'bloom', '3': 2, '4': 1, '5': 12, '10': 'bloom'},
    {'1': 'bloom_hashes', '3': 3, '4': 1, '5': 13, '10': 'bloomHashes'},
    {'1': 'bloom_bits', '3': 4, '4': 1, '5': 13, '10': 'bloomBits'},
  ],
  '3': [HaveDigest_AuthorHW$json],
};

@$core.Deprecated('Use haveDigestDescriptor instead')
const HaveDigest_AuthorHW$json = {
  '1': 'AuthorHW',
  '2': [
    {'1': 'author_pubkey', '3': 1, '4': 1, '5': 12, '10': 'authorPubkey'},
    {'1': 'high_water', '3': 2, '4': 1, '5': 4, '10': 'highWater'},
    {'1': 'head_event_id', '3': 3, '4': 1, '5': 12, '10': 'headEventId'},
  ],
};

/// Descriptor for `HaveDigest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List haveDigestDescriptor = $convert.base64Decode(
    'CgpIYXZlRGlnZXN0EjwKB2F1dGhvcnMYASADKAsyIi5yZXNpbGllbmNlLnYxLkhhdmVEaWdlc3'
    'QuQXV0aG9ySFdSB2F1dGhvcnMSFAoFYmxvb20YAiABKAxSBWJsb29tEiEKDGJsb29tX2hhc2hl'
    'cxgDIAEoDVILYmxvb21IYXNoZXMSHQoKYmxvb21fYml0cxgEIAEoDVIJYmxvb21CaXRzGnIKCE'
    'F1dGhvckhXEiMKDWF1dGhvcl9wdWJrZXkYASABKAxSDGF1dGhvclB1YmtleRIdCgpoaWdoX3dh'
    'dGVyGAIgASgEUgloaWdoV2F0ZXISIgoNaGVhZF9ldmVudF9pZBgDIAEoDFILaGVhZEV2ZW50SW'
    'Q=');

@$core.Deprecated('Use wantListDescriptor instead')
const WantList$json = {
  '1': 'WantList',
  '2': [
    {'1': 'event_ids', '3': 1, '4': 3, '5': 12, '10': 'eventIds'},
    {
      '1': 'from',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.resilience.v1.WantList.AuthorFrom',
      '10': 'from'
    },
  ],
  '3': [WantList_AuthorFrom$json],
};

@$core.Deprecated('Use wantListDescriptor instead')
const WantList_AuthorFrom$json = {
  '1': 'AuthorFrom',
  '2': [
    {'1': 'author_pubkey', '3': 1, '4': 1, '5': 12, '10': 'authorPubkey'},
    {'1': 'from_lamport', '3': 2, '4': 1, '5': 4, '10': 'fromLamport'},
  ],
};

/// Descriptor for `WantList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wantListDescriptor = $convert.base64Decode(
    'CghXYW50TGlzdBIbCglldmVudF9pZHMYASADKAxSCGV2ZW50SWRzEjYKBGZyb20YAiADKAsyIi'
    '5yZXNpbGllbmNlLnYxLldhbnRMaXN0LkF1dGhvckZyb21SBGZyb20aVAoKQXV0aG9yRnJvbRIj'
    'Cg1hdXRob3JfcHVia2V5GAEgASgMUgxhdXRob3JQdWJrZXkSIQoMZnJvbV9sYW1wb3J0GAIgAS'
    'gEUgtmcm9tTGFtcG9ydA==');

@$core.Deprecated('Use eventBatchDescriptor instead')
const EventBatch$json = {
  '1': 'EventBatch',
  '2': [
    {
      '1': 'events',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.resilience.v1.SignedEvent',
      '10': 'events'
    },
    {'1': 'more', '3': 2, '4': 1, '5': 8, '10': 'more'},
  ],
};

/// Descriptor for `EventBatch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventBatchDescriptor = $convert.base64Decode(
    'CgpFdmVudEJhdGNoEjIKBmV2ZW50cxgBIAMoCzIaLnJlc2lsaWVuY2UudjEuU2lnbmVkRXZlbn'
    'RSBmV2ZW50cxISCgRtb3JlGAIgASgIUgRtb3Jl');

@$core.Deprecated('Use ackDescriptor instead')
const Ack$json = {
  '1': 'Ack',
  '2': [
    {'1': 'applied', '3': 1, '4': 3, '5': 12, '10': 'applied'},
    {'1': 'rejected', '3': 2, '4': 3, '5': 12, '10': 'rejected'},
  ],
};

/// Descriptor for `Ack`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ackDescriptor = $convert.base64Decode(
    'CgNBY2sSGAoHYXBwbGllZBgBIAMoDFIHYXBwbGllZBIaCghyZWplY3RlZBgCIAMoDFIIcmVqZW'
    'N0ZWQ=');

@$core.Deprecated('Use meshPacketDescriptor instead')
const MeshPacket$json = {
  '1': 'MeshPacket',
  '2': [
    {'1': 'packet_id', '3': 1, '4': 1, '5': 12, '10': 'packetId'},
    {
      '1': 'priority',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.Priority',
      '10': 'priority'
    },
    {'1': 'ttl', '3': 3, '4': 1, '5': 13, '10': 'ttl'},
    {'1': 'dest_hint', '3': 4, '4': 1, '5': 12, '10': 'destHint'},
    {'1': 'payload', '3': 5, '4': 1, '5': 12, '10': 'payload'},
    {'1': 'frag_index', '3': 6, '4': 1, '5': 13, '10': 'fragIndex'},
    {'1': 'frag_total', '3': 7, '4': 1, '5': 13, '10': 'fragTotal'},
  ],
};

/// Descriptor for `MeshPacket`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List meshPacketDescriptor = $convert.base64Decode(
    'CgpNZXNoUGFja2V0EhsKCXBhY2tldF9pZBgBIAEoDFIIcGFja2V0SWQSMwoIcHJpb3JpdHkYAi'
    'ABKA4yFy5yZXNpbGllbmNlLnYxLlByaW9yaXR5Ughwcmlvcml0eRIQCgN0dGwYAyABKA1SA3R0'
    'bBIbCglkZXN0X2hpbnQYBCABKAxSCGRlc3RIaW50EhgKB3BheWxvYWQYBSABKAxSB3BheWxvYW'
    'QSHQoKZnJhZ19pbmRleBgGIAEoDVIJZnJhZ0luZGV4Eh0KCmZyYWdfdG90YWwYByABKA1SCWZy'
    'YWdUb3RhbA==');

@$core.Deprecated('Use pushEventsRequestDescriptor instead')
const PushEventsRequest$json = {
  '1': 'PushEventsRequest',
  '2': [
    {
      '1': 'events',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.resilience.v1.SignedEvent',
      '10': 'events'
    },
  ],
};

/// Descriptor for `PushEventsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pushEventsRequestDescriptor = $convert.base64Decode(
    'ChFQdXNoRXZlbnRzUmVxdWVzdBIyCgZldmVudHMYASADKAsyGi5yZXNpbGllbmNlLnYxLlNpZ2'
    '5lZEV2ZW50UgZldmVudHM=');

@$core.Deprecated('Use pushEventsResponseDescriptor instead')
const PushEventsResponse$json = {
  '1': 'PushEventsResponse',
  '2': [
    {
      '1': 'ack',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.Ack',
      '10': 'ack'
    },
  ],
};

/// Descriptor for `PushEventsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pushEventsResponseDescriptor = $convert.base64Decode(
    'ChJQdXNoRXZlbnRzUmVzcG9uc2USJAoDYWNrGAEgASgLMhIucmVzaWxpZW5jZS52MS5BY2tSA2'
    'Fjaw==');

@$core.Deprecated('Use pullEventsRequestDescriptor instead')
const PullEventsRequest$json = {
  '1': 'PullEventsRequest',
  '2': [
    {
      '1': 'from',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.resilience.v1.PullEventsRequest.AuthorFrom',
      '10': 'from'
    },
    {'1': 'h3_cell', '3': 2, '4': 1, '5': 4, '10': 'h3Cell'},
    {'1': 'limit', '3': 3, '4': 1, '5': 13, '10': 'limit'},
  ],
  '3': [PullEventsRequest_AuthorFrom$json],
};

@$core.Deprecated('Use pullEventsRequestDescriptor instead')
const PullEventsRequest_AuthorFrom$json = {
  '1': 'AuthorFrom',
  '2': [
    {'1': 'author_pubkey', '3': 1, '4': 1, '5': 12, '10': 'authorPubkey'},
    {'1': 'from_lamport', '3': 2, '4': 1, '5': 4, '10': 'fromLamport'},
  ],
};

/// Descriptor for `PullEventsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pullEventsRequestDescriptor = $convert.base64Decode(
    'ChFQdWxsRXZlbnRzUmVxdWVzdBI/CgRmcm9tGAEgAygLMisucmVzaWxpZW5jZS52MS5QdWxsRX'
    'ZlbnRzUmVxdWVzdC5BdXRob3JGcm9tUgRmcm9tEhcKB2gzX2NlbGwYAiABKARSBmgzQ2VsbBIU'
    'CgVsaW1pdBgDIAEoDVIFbGltaXQaVAoKQXV0aG9yRnJvbRIjCg1hdXRob3JfcHVia2V5GAEgAS'
    'gMUgxhdXRob3JQdWJrZXkSIQoMZnJvbV9sYW1wb3J0GAIgASgEUgtmcm9tTGFtcG9ydA==');

@$core.Deprecated('Use pullEventsResponseDescriptor instead')
const PullEventsResponse$json = {
  '1': 'PullEventsResponse',
  '2': [
    {
      '1': 'batch',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.EventBatch',
      '10': 'batch'
    },
  ],
};

/// Descriptor for `PullEventsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pullEventsResponseDescriptor = $convert.base64Decode(
    'ChJQdWxsRXZlbnRzUmVzcG9uc2USLwoFYmF0Y2gYASABKAsyGS5yZXNpbGllbmNlLnYxLkV2ZW'
    '50QmF0Y2hSBWJhdGNo');
