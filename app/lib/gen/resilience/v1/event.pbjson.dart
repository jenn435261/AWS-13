// This is a generated file - do not edit.
//
// Generated from resilience/v1/event.proto.

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

@$core.Deprecated('Use eventTypeDescriptor instead')
const EventType$json = {
  '1': 'EventType',
  '2': [
    {'1': 'EVENT_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'EVENT_TYPE_IDENTITY_CERTIFICATE', '2': 1},
    {'1': 'EVENT_TYPE_KEY_REVOKED', '2': 2},
    {'1': 'EVENT_TYPE_ORG_CERTIFICATE', '2': 3},
    {'1': 'EVENT_TYPE_RESOURCE_CREATED', '2': 10},
    {'1': 'EVENT_TYPE_RESOURCE_UPDATED', '2': 11},
    {'1': 'EVENT_TYPE_RESOURCE_OBSERVED', '2': 12},
    {'1': 'EVENT_TYPE_RESOURCE_CONFIRMED', '2': 13},
    {'1': 'EVENT_TYPE_RESOURCE_DISPUTED', '2': 14},
    {'1': 'EVENT_TYPE_RESOURCE_USEFUL', '2': 15},
    {'1': 'EVENT_TYPE_INVENTORY_SNAPSHOT', '2': 16},
    {'1': 'EVENT_TYPE_RESERVATION', '2': 17},
    {'1': 'EVENT_TYPE_HELP_REQUESTED', '2': 20},
    {'1': 'EVENT_TYPE_HELP_OFFERED', '2': 21},
    {'1': 'EVENT_TYPE_SHELTER_CREATED', '2': 22},
    {'1': 'EVENT_TYPE_TRANSPORT_OFFERED', '2': 23},
    {'1': 'EVENT_TYPE_HELP_REQUEST_CLOSED', '2': 24},
    {'1': 'EVENT_TYPE_MESSAGE_SENT', '2': 30},
    {'1': 'EVENT_TYPE_MESSAGE_DELIVERED', '2': 31},
    {'1': 'EVENT_TYPE_MESSAGE_READ', '2': 32},
    {'1': 'EVENT_TYPE_CHANNEL_CREATED', '2': 33},
    {'1': 'EVENT_TYPE_CHANNEL_MEMBERSHIP', '2': 34},
    {'1': 'EVENT_TYPE_PREKEY_BUNDLE', '2': 35},
    {'1': 'EVENT_TYPE_MISSION_CREATED', '2': 40},
    {'1': 'EVENT_TYPE_MISSION_ACCEPTED', '2': 41},
    {'1': 'EVENT_TYPE_MISSION_MATCHED', '2': 42},
    {'1': 'EVENT_TYPE_PACKAGE_PICKED_UP', '2': 43},
    {'1': 'EVENT_TYPE_PACKAGE_TRANSFERRED', '2': 44},
    {'1': 'EVENT_TYPE_DELIVERY_COMPLETED', '2': 45},
    {'1': 'EVENT_TYPE_CAPABILITY_GRANTED', '2': 46},
    {'1': 'EVENT_TYPE_CAPABILITY_REVOKED', '2': 47},
    {'1': 'EVENT_TYPE_EMERGENCY_ALERT', '2': 50},
    {'1': 'EVENT_TYPE_LOCATION_SHARE', '2': 60},
    {'1': 'EVENT_TYPE_LOCATION_STOP', '2': 61},
  ],
};

/// Descriptor for `EventType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List eventTypeDescriptor = $convert.base64Decode(
    'CglFdmVudFR5cGUSGgoWRVZFTlRfVFlQRV9VTlNQRUNJRklFRBAAEiMKH0VWRU5UX1RZUEVfSU'
    'RFTlRJVFlfQ0VSVElGSUNBVEUQARIaChZFVkVOVF9UWVBFX0tFWV9SRVZPS0VEEAISHgoaRVZF'
    'TlRfVFlQRV9PUkdfQ0VSVElGSUNBVEUQAxIfChtFVkVOVF9UWVBFX1JFU09VUkNFX0NSRUFURU'
    'QQChIfChtFVkVOVF9UWVBFX1JFU09VUkNFX1VQREFURUQQCxIgChxFVkVOVF9UWVBFX1JFU09V'
    'UkNFX09CU0VSVkVEEAwSIQodRVZFTlRfVFlQRV9SRVNPVVJDRV9DT05GSVJNRUQQDRIgChxFVk'
    'VOVF9UWVBFX1JFU09VUkNFX0RJU1BVVEVEEA4SHgoaRVZFTlRfVFlQRV9SRVNPVVJDRV9VU0VG'
    'VUwQDxIhCh1FVkVOVF9UWVBFX0lOVkVOVE9SWV9TTkFQU0hPVBAQEhoKFkVWRU5UX1RZUEVfUk'
    'VTRVJWQVRJT04QERIdChlFVkVOVF9UWVBFX0hFTFBfUkVRVUVTVEVEEBQSGwoXRVZFTlRfVFlQ'
    'RV9IRUxQX09GRkVSRUQQFRIeChpFVkVOVF9UWVBFX1NIRUxURVJfQ1JFQVRFRBAWEiAKHEVWRU'
    '5UX1RZUEVfVFJBTlNQT1JUX09GRkVSRUQQFxIiCh5FVkVOVF9UWVBFX0hFTFBfUkVRVUVTVF9D'
    'TE9TRUQQGBIbChdFVkVOVF9UWVBFX01FU1NBR0VfU0VOVBAeEiAKHEVWRU5UX1RZUEVfTUVTU0'
    'FHRV9ERUxJVkVSRUQQHxIbChdFVkVOVF9UWVBFX01FU1NBR0VfUkVBRBAgEh4KGkVWRU5UX1RZ'
    'UEVfQ0hBTk5FTF9DUkVBVEVEECESIQodRVZFTlRfVFlQRV9DSEFOTkVMX01FTUJFUlNISVAQIh'
    'IcChhFVkVOVF9UWVBFX1BSRUtFWV9CVU5ETEUQIxIeChpFVkVOVF9UWVBFX01JU1NJT05fQ1JF'
    'QVRFRBAoEh8KG0VWRU5UX1RZUEVfTUlTU0lPTl9BQ0NFUFRFRBApEh4KGkVWRU5UX1RZUEVfTU'
    'lTU0lPTl9NQVRDSEVEECoSIAocRVZFTlRfVFlQRV9QQUNLQUdFX1BJQ0tFRF9VUBArEiIKHkVW'
    'RU5UX1RZUEVfUEFDS0FHRV9UUkFOU0ZFUlJFRBAsEiEKHUVWRU5UX1RZUEVfREVMSVZFUllfQ0'
    '9NUExFVEVEEC0SIQodRVZFTlRfVFlQRV9DQVBBQklMSVRZX0dSQU5URUQQLhIhCh1FVkVOVF9U'
    'WVBFX0NBUEFCSUxJVFlfUkVWT0tFRBAvEh4KGkVWRU5UX1RZUEVfRU1FUkdFTkNZX0FMRVJUED'
    'ISHQoZRVZFTlRfVFlQRV9MT0NBVElPTl9TSEFSRRA8EhwKGEVWRU5UX1RZUEVfTE9DQVRJT05f'
    'U1RPUBA9');

@$core.Deprecated('Use resourceCategoryDescriptor instead')
const ResourceCategory$json = {
  '1': 'ResourceCategory',
  '2': [
    {'1': 'RESOURCE_CATEGORY_UNSPECIFIED', '2': 0},
    {'1': 'RESOURCE_CATEGORY_WATER', '2': 1},
    {'1': 'RESOURCE_CATEGORY_FOOD', '2': 2},
    {'1': 'RESOURCE_CATEGORY_MEDICINE', '2': 3},
    {'1': 'RESOURCE_CATEGORY_SHELTER', '2': 4},
    {'1': 'RESOURCE_CATEGORY_POWER', '2': 5},
    {'1': 'RESOURCE_CATEGORY_TRANSPORTATION', '2': 6},
    {'1': 'RESOURCE_CATEGORY_MEDICAL_HELP', '2': 7},
    {'1': 'RESOURCE_CATEGORY_COMMUNICATION', '2': 8},
    {'1': 'RESOURCE_CATEGORY_BLANKETS', '2': 9},
    {'1': 'RESOURCE_CATEGORY_BATTERIES', '2': 10},
    {'1': 'RESOURCE_CATEGORY_CHARGING', '2': 11},
    {'1': 'RESOURCE_CATEGORY_TOOLS', '2': 12},
    {'1': 'RESOURCE_CATEGORY_OTHER', '2': 99},
  ],
};

/// Descriptor for `ResourceCategory`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List resourceCategoryDescriptor = $convert.base64Decode(
    'ChBSZXNvdXJjZUNhdGVnb3J5EiEKHVJFU09VUkNFX0NBVEVHT1JZX1VOU1BFQ0lGSUVEEAASGw'
    'oXUkVTT1VSQ0VfQ0FURUdPUllfV0FURVIQARIaChZSRVNPVVJDRV9DQVRFR09SWV9GT09EEAIS'
    'HgoaUkVTT1VSQ0VfQ0FURUdPUllfTUVESUNJTkUQAxIdChlSRVNPVVJDRV9DQVRFR09SWV9TSE'
    'VMVEVSEAQSGwoXUkVTT1VSQ0VfQ0FURUdPUllfUE9XRVIQBRIkCiBSRVNPVVJDRV9DQVRFR09S'
    'WV9UUkFOU1BPUlRBVElPThAGEiIKHlJFU09VUkNFX0NBVEVHT1JZX01FRElDQUxfSEVMUBAHEi'
    'MKH1JFU09VUkNFX0NBVEVHT1JZX0NPTU1VTklDQVRJT04QCBIeChpSRVNPVVJDRV9DQVRFR09S'
    'WV9CTEFOS0VUUxAJEh8KG1JFU09VUkNFX0NBVEVHT1JZX0JBVFRFUklFUxAKEh4KGlJFU09VUk'
    'NFX0NBVEVHT1JZX0NIQVJHSU5HEAsSGwoXUkVTT1VSQ0VfQ0FURUdPUllfVE9PTFMQDBIbChdS'
    'RVNPVVJDRV9DQVRFR09SWV9PVEhFUhBj');

@$core.Deprecated('Use amountBandDescriptor instead')
const AmountBand$json = {
  '1': 'AmountBand',
  '2': [
    {'1': 'AMOUNT_BAND_UNSPECIFIED', '2': 0},
    {'1': 'AMOUNT_BAND_PLENTY', '2': 1},
    {'1': 'AMOUNT_BAND_SOME', '2': 2},
    {'1': 'AMOUNT_BAND_LOW', '2': 3},
  ],
};

/// Descriptor for `AmountBand`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List amountBandDescriptor = $convert.base64Decode(
    'CgpBbW91bnRCYW5kEhsKF0FNT1VOVF9CQU5EX1VOU1BFQ0lGSUVEEAASFgoSQU1PVU5UX0JBTk'
    'RfUExFTlRZEAESFAoQQU1PVU5UX0JBTkRfU09NRRACEhMKD0FNT1VOVF9CQU5EX0xPVxAD');

@$core.Deprecated('Use availabilityDescriptor instead')
const Availability$json = {
  '1': 'Availability',
  '2': [
    {'1': 'AVAILABILITY_UNSPECIFIED', '2': 0},
    {'1': 'AVAILABILITY_NOW', '2': 1},
    {'1': 'AVAILABILITY_TODAY', '2': 2},
    {'1': 'AVAILABILITY_CUSTOM', '2': 3},
  ],
};

/// Descriptor for `Availability`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List availabilityDescriptor = $convert.base64Decode(
    'CgxBdmFpbGFiaWxpdHkSHAoYQVZBSUxBQklMSVRZX1VOU1BFQ0lGSUVEEAASFAoQQVZBSUxBQk'
    'lMSVRZX05PVxABEhYKEkFWQUlMQUJJTElUWV9UT0RBWRACEhcKE0FWQUlMQUJJTElUWV9DVVNU'
    'T00QAw==');

@$core.Deprecated('Use provenanceKindDescriptor instead')
const ProvenanceKind$json = {
  '1': 'ProvenanceKind',
  '2': [
    {'1': 'PROVENANCE_KIND_UNSPECIFIED', '2': 0},
    {'1': 'PROVENANCE_KIND_COMMUNITY', '2': 1},
    {'1': 'PROVENANCE_KIND_VERIFIED_ORG', '2': 2},
  ],
};

/// Descriptor for `ProvenanceKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List provenanceKindDescriptor = $convert.base64Decode(
    'Cg5Qcm92ZW5hbmNlS2luZBIfChtQUk9WRU5BTkNFX0tJTkRfVU5TUEVDSUZJRUQQABIdChlQUk'
    '9WRU5BTkNFX0tJTkRfQ09NTVVOSVRZEAESIAocUFJPVkVOQU5DRV9LSU5EX1ZFUklGSUVEX09S'
    'RxAC');

@$core.Deprecated('Use priorityDescriptor instead')
const Priority$json = {
  '1': 'Priority',
  '2': [
    {'1': 'PRIORITY_UNSPECIFIED', '2': 0},
    {'1': 'PRIORITY_LOW', '2': 1},
    {'1': 'PRIORITY_NORMAL', '2': 2},
    {'1': 'PRIORITY_HIGH', '2': 3},
    {'1': 'PRIORITY_CRITICAL', '2': 4},
  ],
};

/// Descriptor for `Priority`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List priorityDescriptor = $convert.base64Decode(
    'CghQcmlvcml0eRIYChRQUklPUklUWV9VTlNQRUNJRklFRBAAEhAKDFBSSU9SSVRZX0xPVxABEh'
    'MKD1BSSU9SSVRZX05PUk1BTBACEhEKDVBSSU9SSVRZX0hJR0gQAxIVChFQUklPUklUWV9DUklU'
    'SUNBTBAE');

@$core.Deprecated('Use transportModeDescriptor instead')
const TransportMode$json = {
  '1': 'TransportMode',
  '2': [
    {'1': 'TRANSPORT_MODE_UNSPECIFIED', '2': 0},
    {'1': 'TRANSPORT_MODE_WALKING', '2': 1},
    {'1': 'TRANSPORT_MODE_BICYCLE', '2': 2},
    {'1': 'TRANSPORT_MODE_CAR', '2': 3},
    {'1': 'TRANSPORT_MODE_TRUCK', '2': 4},
    {'1': 'TRANSPORT_MODE_VAN', '2': 5},
  ],
};

/// Descriptor for `TransportMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List transportModeDescriptor = $convert.base64Decode(
    'Cg1UcmFuc3BvcnRNb2RlEh4KGlRSQU5TUE9SVF9NT0RFX1VOU1BFQ0lGSUVEEAASGgoWVFJBTl'
    'NQT1JUX01PREVfV0FMS0lORxABEhoKFlRSQU5TUE9SVF9NT0RFX0JJQ1lDTEUQAhIWChJUUkFO'
    'U1BPUlRfTU9ERV9DQVIQAxIYChRUUkFOU1BPUlRfTU9ERV9UUlVDSxAEEhYKElRSQU5TUE9SVF'
    '9NT0RFX1ZBThAF');

@$core.Deprecated('Use capacityBandDescriptor instead')
const CapacityBand$json = {
  '1': 'CapacityBand',
  '2': [
    {'1': 'CAPACITY_BAND_UNSPECIFIED', '2': 0},
    {'1': 'CAPACITY_BAND_SMALL', '2': 1},
    {'1': 'CAPACITY_BAND_MEDIUM', '2': 2},
    {'1': 'CAPACITY_BAND_LARGE', '2': 3},
  ],
};

/// Descriptor for `CapacityBand`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List capacityBandDescriptor = $convert.base64Decode(
    'CgxDYXBhY2l0eUJhbmQSHQoZQ0FQQUNJVFlfQkFORF9VTlNQRUNJRklFRBAAEhcKE0NBUEFDSV'
    'RZX0JBTkRfU01BTEwQARIYChRDQVBBQ0lUWV9CQU5EX01FRElVTRACEhcKE0NBUEFDSVRZX0JB'
    'TkRfTEFSR0UQAw==');

@$core.Deprecated('Use channelTypeDescriptor instead')
const ChannelType$json = {
  '1': 'ChannelType',
  '2': [
    {'1': 'CHANNEL_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'CHANNEL_TYPE_DIRECT', '2': 1},
    {'1': 'CHANNEL_TYPE_PUBLIC', '2': 2},
    {'1': 'CHANNEL_TYPE_COMMUNITY', '2': 3},
    {'1': 'CHANNEL_TYPE_RESTRICTED', '2': 4},
    {'1': 'CHANNEL_TYPE_MISSION', '2': 5},
  ],
};

/// Descriptor for `ChannelType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List channelTypeDescriptor = $convert.base64Decode(
    'CgtDaGFubmVsVHlwZRIcChhDSEFOTkVMX1RZUEVfVU5TUEVDSUZJRUQQABIXChNDSEFOTkVMX1'
    'RZUEVfRElSRUNUEAESFwoTQ0hBTk5FTF9UWVBFX1BVQkxJQxACEhoKFkNIQU5ORUxfVFlQRV9D'
    'T01NVU5JVFkQAxIbChdDSEFOTkVMX1RZUEVfUkVTVFJJQ1RFRBAEEhgKFENIQU5ORUxfVFlQRV'
    '9NSVNTSU9OEAU=');

@$core.Deprecated('Use signedEventDescriptor instead')
const SignedEvent$json = {
  '1': 'SignedEvent',
  '2': [
    {
      '1': 'header',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.EventHeader',
      '10': 'header'
    },
    {'1': 'body', '3': 2, '4': 1, '5': 12, '10': 'body'},
    {'1': 'signature', '3': 3, '4': 1, '5': 12, '10': 'signature'},
  ],
};

/// Descriptor for `SignedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signedEventDescriptor = $convert.base64Decode(
    'CgtTaWduZWRFdmVudBIyCgZoZWFkZXIYASABKAsyGi5yZXNpbGllbmNlLnYxLkV2ZW50SGVhZG'
    'VyUgZoZWFkZXISEgoEYm9keRgCIAEoDFIEYm9keRIcCglzaWduYXR1cmUYAyABKAxSCXNpZ25h'
    'dHVyZQ==');

@$core.Deprecated('Use eventHeaderDescriptor instead')
const EventHeader$json = {
  '1': 'EventHeader',
  '2': [
    {'1': 'event_id', '3': 1, '4': 1, '5': 12, '10': 'eventId'},
    {
      '1': 'type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.EventType',
      '10': 'type'
    },
    {'1': 'author_pubkey', '3': 3, '4': 1, '5': 12, '10': 'authorPubkey'},
    {'1': 'lamport', '3': 4, '4': 1, '5': 4, '10': 'lamport'},
    {'1': 'prev_event_id', '3': 5, '4': 1, '5': 12, '10': 'prevEventId'},
    {'1': 'depends_on', '3': 6, '4': 3, '5': 12, '10': 'dependsOn'},
    {'1': 'created_at_ms', '3': 7, '4': 1, '5': 3, '10': 'createdAtMs'},
    {'1': 'schema_version', '3': 8, '4': 1, '5': 13, '10': 'schemaVersion'},
    {'1': 'h3_cell', '3': 9, '4': 1, '5': 4, '10': 'h3Cell'},
  ],
};

/// Descriptor for `EventHeader`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventHeaderDescriptor = $convert.base64Decode(
    'CgtFdmVudEhlYWRlchIZCghldmVudF9pZBgBIAEoDFIHZXZlbnRJZBIsCgR0eXBlGAIgASgOMh'
    'gucmVzaWxpZW5jZS52MS5FdmVudFR5cGVSBHR5cGUSIwoNYXV0aG9yX3B1YmtleRgDIAEoDFIM'
    'YXV0aG9yUHVia2V5EhgKB2xhbXBvcnQYBCABKARSB2xhbXBvcnQSIgoNcHJldl9ldmVudF9pZB'
    'gFIAEoDFILcHJldkV2ZW50SWQSHQoKZGVwZW5kc19vbhgGIAMoDFIJZGVwZW5kc09uEiIKDWNy'
    'ZWF0ZWRfYXRfbXMYByABKANSC2NyZWF0ZWRBdE1zEiUKDnNjaGVtYV92ZXJzaW9uGAggASgNUg'
    '1zY2hlbWFWZXJzaW9uEhcKB2gzX2NlbGwYCSABKARSBmgzQ2VsbA==');

@$core.Deprecated('Use geoPointDescriptor instead')
const GeoPoint$json = {
  '1': 'GeoPoint',
  '2': [
    {'1': 'h3_cell', '3': 1, '4': 1, '5': 4, '10': 'h3Cell'},
    {'1': 'approx_lat', '3': 2, '4': 1, '5': 1, '10': 'approxLat'},
    {'1': 'approx_lon', '3': 3, '4': 1, '5': 1, '10': 'approxLon'},
    {'1': 'exact_lat', '3': 4, '4': 1, '5': 1, '10': 'exactLat'},
    {'1': 'exact_lon', '3': 5, '4': 1, '5': 1, '10': 'exactLon'},
    {'1': 'has_exact', '3': 6, '4': 1, '5': 8, '10': 'hasExact'},
    {'1': 'address', '3': 7, '4': 1, '5': 9, '10': 'address'},
  ],
};

/// Descriptor for `GeoPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List geoPointDescriptor = $convert.base64Decode(
    'CghHZW9Qb2ludBIXCgdoM19jZWxsGAEgASgEUgZoM0NlbGwSHQoKYXBwcm94X2xhdBgCIAEoAV'
    'IJYXBwcm94TGF0Eh0KCmFwcHJveF9sb24YAyABKAFSCWFwcHJveExvbhIbCglleGFjdF9sYXQY'
    'BCABKAFSCGV4YWN0TGF0EhsKCWV4YWN0X2xvbhgFIAEoAVIIZXhhY3RMb24SGwoJaGFzX2V4YW'
    'N0GAYgASgIUghoYXNFeGFjdBIYCgdhZGRyZXNzGAcgASgJUgdhZGRyZXNz');

@$core.Deprecated('Use identityCertificateBodyDescriptor instead')
const IdentityCertificateBody$json = {
  '1': 'IdentityCertificateBody',
  '2': [
    {'1': 'signing_pubkey', '3': 1, '4': 1, '5': 12, '10': 'signingPubkey'},
    {
      '1': 'key_agreement_pubkey',
      '3': 2,
      '4': 1,
      '5': 12,
      '10': 'keyAgreementPubkey'
    },
    {'1': 'display_name', '3': 3, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'resilience_id', '3': 4, '4': 1, '5': 9, '10': 'resilienceId'},
    {'1': 'valid_from_ms', '3': 5, '4': 1, '5': 3, '10': 'validFromMs'},
    {'1': 'valid_until_ms', '3': 6, '4': 1, '5': 3, '10': 'validUntilMs'},
  ],
};

/// Descriptor for `IdentityCertificateBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List identityCertificateBodyDescriptor = $convert.base64Decode(
    'ChdJZGVudGl0eUNlcnRpZmljYXRlQm9keRIlCg5zaWduaW5nX3B1YmtleRgBIAEoDFINc2lnbm'
    'luZ1B1YmtleRIwChRrZXlfYWdyZWVtZW50X3B1YmtleRgCIAEoDFISa2V5QWdyZWVtZW50UHVi'
    'a2V5EiEKDGRpc3BsYXlfbmFtZRgDIAEoCVILZGlzcGxheU5hbWUSIwoNcmVzaWxpZW5jZV9pZB'
    'gEIAEoCVIMcmVzaWxpZW5jZUlkEiIKDXZhbGlkX2Zyb21fbXMYBSABKANSC3ZhbGlkRnJvbU1z'
    'EiQKDnZhbGlkX3VudGlsX21zGAYgASgDUgx2YWxpZFVudGlsTXM=');

@$core.Deprecated('Use orgCertificateBodyDescriptor instead')
const OrgCertificateBody$json = {
  '1': 'OrgCertificateBody',
  '2': [
    {'1': 'org_root_pubkey', '3': 1, '4': 1, '5': 12, '10': 'orgRootPubkey'},
    {'1': 'subject_pubkey', '3': 2, '4': 1, '5': 12, '10': 'subjectPubkey'},
    {'1': 'org_name', '3': 3, '4': 1, '5': 9, '10': 'orgName'},
    {'1': 'facility_name', '3': 4, '4': 1, '5': 9, '10': 'facilityName'},
    {
      '1': 'provenance',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.ProvenanceKind',
      '10': 'provenance'
    },
    {'1': 'valid_from_ms', '3': 6, '4': 1, '5': 3, '10': 'validFromMs'},
    {'1': 'valid_until_ms', '3': 7, '4': 1, '5': 3, '10': 'validUntilMs'},
  ],
};

/// Descriptor for `OrgCertificateBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List orgCertificateBodyDescriptor = $convert.base64Decode(
    'ChJPcmdDZXJ0aWZpY2F0ZUJvZHkSJgoPb3JnX3Jvb3RfcHVia2V5GAEgASgMUg1vcmdSb290UH'
    'Via2V5EiUKDnN1YmplY3RfcHVia2V5GAIgASgMUg1zdWJqZWN0UHVia2V5EhkKCG9yZ19uYW1l'
    'GAMgASgJUgdvcmdOYW1lEiMKDWZhY2lsaXR5X25hbWUYBCABKAlSDGZhY2lsaXR5TmFtZRI9Cg'
    'pwcm92ZW5hbmNlGAUgASgOMh0ucmVzaWxpZW5jZS52MS5Qcm92ZW5hbmNlS2luZFIKcHJvdmVu'
    'YW5jZRIiCg12YWxpZF9mcm9tX21zGAYgASgDUgt2YWxpZEZyb21NcxIkCg52YWxpZF91bnRpbF'
    '9tcxgHIAEoA1IMdmFsaWRVbnRpbE1z');

@$core.Deprecated('Use keyRevokedBodyDescriptor instead')
const KeyRevokedBody$json = {
  '1': 'KeyRevokedBody',
  '2': [
    {'1': 'revoked_pubkey', '3': 1, '4': 1, '5': 12, '10': 'revokedPubkey'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'revoked_at_ms', '3': 3, '4': 1, '5': 3, '10': 'revokedAtMs'},
  ],
};

/// Descriptor for `KeyRevokedBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyRevokedBodyDescriptor = $convert.base64Decode(
    'Cg5LZXlSZXZva2VkQm9keRIlCg5yZXZva2VkX3B1YmtleRgBIAEoDFINcmV2b2tlZFB1YmtleR'
    'IWCgZyZWFzb24YAiABKAlSBnJlYXNvbhIiCg1yZXZva2VkX2F0X21zGAMgASgDUgtyZXZva2Vk'
    'QXRNcw==');

@$core.Deprecated('Use resourceBodyDescriptor instead')
const ResourceBody$json = {
  '1': 'ResourceBody',
  '2': [
    {'1': 'resource_id', '3': 1, '4': 1, '5': 9, '10': 'resourceId'},
    {
      '1': 'category',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.ResourceCategory',
      '10': 'category'
    },
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {'1': 'notes', '3': 4, '4': 1, '5': 9, '10': 'notes'},
    {
      '1': 'amount',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.AmountBand',
      '10': 'amount'
    },
    {
      '1': 'availability',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.Availability',
      '10': 'availability'
    },
    {
      '1': 'available_until_ms',
      '3': 7,
      '4': 1,
      '5': 3,
      '10': 'availableUntilMs'
    },
    {
      '1': 'location',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.GeoPoint',
      '10': 'location'
    },
    {
      '1': 'provenance',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.ProvenanceKind',
      '10': 'provenance'
    },
    {'1': 'is_shelter', '3': 10, '4': 1, '5': 8, '10': 'isShelter'},
  ],
};

/// Descriptor for `ResourceBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resourceBodyDescriptor = $convert.base64Decode(
    'CgxSZXNvdXJjZUJvZHkSHwoLcmVzb3VyY2VfaWQYASABKAlSCnJlc291cmNlSWQSOwoIY2F0ZW'
    'dvcnkYAiABKA4yHy5yZXNpbGllbmNlLnYxLlJlc291cmNlQ2F0ZWdvcnlSCGNhdGVnb3J5EhQK'
    'BXRpdGxlGAMgASgJUgV0aXRsZRIUCgVub3RlcxgEIAEoCVIFbm90ZXMSMQoGYW1vdW50GAUgAS'
    'gOMhkucmVzaWxpZW5jZS52MS5BbW91bnRCYW5kUgZhbW91bnQSPwoMYXZhaWxhYmlsaXR5GAYg'
    'ASgOMhsucmVzaWxpZW5jZS52MS5BdmFpbGFiaWxpdHlSDGF2YWlsYWJpbGl0eRIsChJhdmFpbG'
    'FibGVfdW50aWxfbXMYByABKANSEGF2YWlsYWJsZVVudGlsTXMSMwoIbG9jYXRpb24YCCABKAsy'
    'Fy5yZXNpbGllbmNlLnYxLkdlb1BvaW50Ughsb2NhdGlvbhI9Cgpwcm92ZW5hbmNlGAkgASgOMh'
    '0ucmVzaWxpZW5jZS52MS5Qcm92ZW5hbmNlS2luZFIKcHJvdmVuYW5jZRIdCgppc19zaGVsdGVy'
    'GAogASgIUglpc1NoZWx0ZXI=');

@$core.Deprecated('Use resourceUpdateBodyDescriptor instead')
const ResourceUpdateBody$json = {
  '1': 'ResourceUpdateBody',
  '2': [
    {'1': 'resource_id', '3': 1, '4': 1, '5': 9, '10': 'resourceId'},
    {
      '1': 'amount',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.AmountBand',
      '10': 'amount'
    },
    {
      '1': 'availability',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.Availability',
      '10': 'availability'
    },
    {'1': 'notes', '3': 4, '4': 1, '5': 9, '10': 'notes'},
    {'1': 'withdrawn', '3': 5, '4': 1, '5': 8, '10': 'withdrawn'},
  ],
};

/// Descriptor for `ResourceUpdateBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resourceUpdateBodyDescriptor = $convert.base64Decode(
    'ChJSZXNvdXJjZVVwZGF0ZUJvZHkSHwoLcmVzb3VyY2VfaWQYASABKAlSCnJlc291cmNlSWQSMQ'
    'oGYW1vdW50GAIgASgOMhkucmVzaWxpZW5jZS52MS5BbW91bnRCYW5kUgZhbW91bnQSPwoMYXZh'
    'aWxhYmlsaXR5GAMgASgOMhsucmVzaWxpZW5jZS52MS5BdmFpbGFiaWxpdHlSDGF2YWlsYWJpbG'
    'l0eRIUCgVub3RlcxgEIAEoCVIFbm90ZXMSHAoJd2l0aGRyYXduGAUgASgIUgl3aXRoZHJhd24=');

@$core.Deprecated('Use observationBodyDescriptor instead')
const ObservationBody$json = {
  '1': 'ObservationBody',
  '2': [
    {'1': 'resource_id', '3': 1, '4': 1, '5': 9, '10': 'resourceId'},
    {
      '1': 'kind',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.ObservationBody.Kind',
      '10': 'kind'
    },
    {'1': 'note', '3': 3, '4': 1, '5': 9, '10': 'note'},
    {
      '1': 'observed_amount',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.AmountBand',
      '10': 'observedAmount'
    },
  ],
  '4': [ObservationBody_Kind$json],
};

@$core.Deprecated('Use observationBodyDescriptor instead')
const ObservationBody_Kind$json = {
  '1': 'Kind',
  '2': [
    {'1': 'KIND_UNSPECIFIED', '2': 0},
    {'1': 'KIND_OBSERVED', '2': 1},
    {'1': 'KIND_CONFIRMED', '2': 2},
    {'1': 'KIND_DISPUTED', '2': 3},
    {'1': 'KIND_USEFUL', '2': 4},
  ],
};

/// Descriptor for `ObservationBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List observationBodyDescriptor = $convert.base64Decode(
    'Cg9PYnNlcnZhdGlvbkJvZHkSHwoLcmVzb3VyY2VfaWQYASABKAlSCnJlc291cmNlSWQSNwoEa2'
    'luZBgCIAEoDjIjLnJlc2lsaWVuY2UudjEuT2JzZXJ2YXRpb25Cb2R5LktpbmRSBGtpbmQSEgoE'
    'bm90ZRgDIAEoCVIEbm90ZRJCCg9vYnNlcnZlZF9hbW91bnQYBCABKA4yGS5yZXNpbGllbmNlLn'
    'YxLkFtb3VudEJhbmRSDm9ic2VydmVkQW1vdW50ImcKBEtpbmQSFAoQS0lORF9VTlNQRUNJRklF'
    'RBAAEhEKDUtJTkRfT0JTRVJWRUQQARISCg5LSU5EX0NPTkZJUk1FRBACEhEKDUtJTkRfRElTUF'
    'VURUQQAxIPCgtLSU5EX1VTRUZVTBAE');

@$core.Deprecated('Use inventorySnapshotBodyDescriptor instead')
const InventorySnapshotBody$json = {
  '1': 'InventorySnapshotBody',
  '2': [
    {'1': 'resource_id', '3': 1, '4': 1, '5': 9, '10': 'resourceId'},
    {'1': 'quantity', '3': 2, '4': 1, '5': 3, '10': 'quantity'},
    {'1': 'unit', '3': 3, '4': 1, '5': 9, '10': 'unit'},
    {'1': 'as_of_ms', '3': 4, '4': 1, '5': 3, '10': 'asOfMs'},
  ],
};

/// Descriptor for `InventorySnapshotBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inventorySnapshotBodyDescriptor = $convert.base64Decode(
    'ChVJbnZlbnRvcnlTbmFwc2hvdEJvZHkSHwoLcmVzb3VyY2VfaWQYASABKAlSCnJlc291cmNlSW'
    'QSGgoIcXVhbnRpdHkYAiABKANSCHF1YW50aXR5EhIKBHVuaXQYAyABKAlSBHVuaXQSGAoIYXNf'
    'b2ZfbXMYBCABKANSBmFzT2ZNcw==');

@$core.Deprecated('Use reservationBodyDescriptor instead')
const ReservationBody$json = {
  '1': 'ReservationBody',
  '2': [
    {'1': 'resource_id', '3': 1, '4': 1, '5': 9, '10': 'resourceId'},
    {'1': 'quantity', '3': 2, '4': 1, '5': 3, '10': 'quantity'},
    {'1': 'mission_id', '3': 3, '4': 1, '5': 9, '10': 'missionId'},
    {'1': 'reserved_until_ms', '3': 4, '4': 1, '5': 3, '10': 'reservedUntilMs'},
  ],
};

/// Descriptor for `ReservationBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reservationBodyDescriptor = $convert.base64Decode(
    'Cg9SZXNlcnZhdGlvbkJvZHkSHwoLcmVzb3VyY2VfaWQYASABKAlSCnJlc291cmNlSWQSGgoIcX'
    'VhbnRpdHkYAiABKANSCHF1YW50aXR5Eh0KCm1pc3Npb25faWQYAyABKAlSCW1pc3Npb25JZBIq'
    'ChFyZXNlcnZlZF91bnRpbF9tcxgEIAEoA1IPcmVzZXJ2ZWRVbnRpbE1z');

@$core.Deprecated('Use helpRequestBodyDescriptor instead')
const HelpRequestBody$json = {
  '1': 'HelpRequestBody',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {
      '1': 'categories',
      '3': 2,
      '4': 3,
      '5': 14,
      '6': '.resilience.v1.ResourceCategory',
      '10': 'categories'
    },
    {'1': 'freeform', '3': 3, '4': 1, '5': 9, '10': 'freeform'},
    {
      '1': 'priority',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.Priority',
      '10': 'priority'
    },
    {
      '1': 'location',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.GeoPoint',
      '10': 'location'
    },
    {'1': 'needed_by_ms', '3': 6, '4': 1, '5': 3, '10': 'neededByMs'},
  ],
};

/// Descriptor for `HelpRequestBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List helpRequestBodyDescriptor = $convert.base64Decode(
    'Cg9IZWxwUmVxdWVzdEJvZHkSHQoKcmVxdWVzdF9pZBgBIAEoCVIJcmVxdWVzdElkEj8KCmNhdG'
    'Vnb3JpZXMYAiADKA4yHy5yZXNpbGllbmNlLnYxLlJlc291cmNlQ2F0ZWdvcnlSCmNhdGVnb3Jp'
    'ZXMSGgoIZnJlZWZvcm0YAyABKAlSCGZyZWVmb3JtEjMKCHByaW9yaXR5GAQgASgOMhcucmVzaW'
    'xpZW5jZS52MS5Qcmlvcml0eVIIcHJpb3JpdHkSMwoIbG9jYXRpb24YBSABKAsyFy5yZXNpbGll'
    'bmNlLnYxLkdlb1BvaW50Ughsb2NhdGlvbhIgCgxuZWVkZWRfYnlfbXMYBiABKANSCm5lZWRlZE'
    'J5TXM=');

@$core.Deprecated('Use helpOfferBodyDescriptor instead')
const HelpOfferBody$json = {
  '1': 'HelpOfferBody',
  '2': [
    {'1': 'offer_id', '3': 1, '4': 1, '5': 9, '10': 'offerId'},
    {
      '1': 'categories',
      '3': 2,
      '4': 3,
      '5': 14,
      '6': '.resilience.v1.ResourceCategory',
      '10': 'categories'
    },
    {
      '1': 'amount',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.AmountBand',
      '10': 'amount'
    },
    {
      '1': 'availability',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.Availability',
      '10': 'availability'
    },
    {'1': 'notes', '3': 5, '4': 1, '5': 9, '10': 'notes'},
    {
      '1': 'location',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.GeoPoint',
      '10': 'location'
    },
  ],
};

/// Descriptor for `HelpOfferBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List helpOfferBodyDescriptor = $convert.base64Decode(
    'Cg1IZWxwT2ZmZXJCb2R5EhkKCG9mZmVyX2lkGAEgASgJUgdvZmZlcklkEj8KCmNhdGVnb3JpZX'
    'MYAiADKA4yHy5yZXNpbGllbmNlLnYxLlJlc291cmNlQ2F0ZWdvcnlSCmNhdGVnb3JpZXMSMQoG'
    'YW1vdW50GAMgASgOMhkucmVzaWxpZW5jZS52MS5BbW91bnRCYW5kUgZhbW91bnQSPwoMYXZhaW'
    'xhYmlsaXR5GAQgASgOMhsucmVzaWxpZW5jZS52MS5BdmFpbGFiaWxpdHlSDGF2YWlsYWJpbGl0'
    'eRIUCgVub3RlcxgFIAEoCVIFbm90ZXMSMwoIbG9jYXRpb24YBiABKAsyFy5yZXNpbGllbmNlLn'
    'YxLkdlb1BvaW50Ughsb2NhdGlvbg==');

@$core.Deprecated('Use helpRequestClosedBodyDescriptor instead')
const HelpRequestClosedBody$json = {
  '1': 'HelpRequestClosedBody',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'closed_at_ms', '3': 3, '4': 1, '5': 3, '10': 'closedAtMs'},
  ],
};

/// Descriptor for `HelpRequestClosedBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List helpRequestClosedBodyDescriptor = $convert.base64Decode(
    'ChVIZWxwUmVxdWVzdENsb3NlZEJvZHkSHQoKcmVxdWVzdF9pZBgBIAEoCVIJcmVxdWVzdElkEh'
    'YKBnJlYXNvbhgCIAEoCVIGcmVhc29uEiAKDGNsb3NlZF9hdF9tcxgDIAEoA1IKY2xvc2VkQXRN'
    'cw==');

@$core.Deprecated('Use transportOfferBodyDescriptor instead')
const TransportOfferBody$json = {
  '1': 'TransportOfferBody',
  '2': [
    {'1': 'offer_id', '3': 1, '4': 1, '5': 9, '10': 'offerId'},
    {
      '1': 'mode',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.TransportMode',
      '10': 'mode'
    },
    {
      '1': 'capacity',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.CapacityBand',
      '10': 'capacity'
    },
    {
      '1': 'availability',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.Availability',
      '10': 'availability'
    },
    {
      '1': 'location',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.GeoPoint',
      '10': 'location'
    },
  ],
};

/// Descriptor for `TransportOfferBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transportOfferBodyDescriptor = $convert.base64Decode(
    'ChJUcmFuc3BvcnRPZmZlckJvZHkSGQoIb2ZmZXJfaWQYASABKAlSB29mZmVySWQSMAoEbW9kZR'
    'gCIAEoDjIcLnJlc2lsaWVuY2UudjEuVHJhbnNwb3J0TW9kZVIEbW9kZRI3CghjYXBhY2l0eRgD'
    'IAEoDjIbLnJlc2lsaWVuY2UudjEuQ2FwYWNpdHlCYW5kUghjYXBhY2l0eRI/CgxhdmFpbGFiaW'
    'xpdHkYBCABKA4yGy5yZXNpbGllbmNlLnYxLkF2YWlsYWJpbGl0eVIMYXZhaWxhYmlsaXR5EjMK'
    'CGxvY2F0aW9uGAUgASgLMhcucmVzaWxpZW5jZS52MS5HZW9Qb2ludFIIbG9jYXRpb24=');

@$core.Deprecated('Use channelCreatedBodyDescriptor instead')
const ChannelCreatedBody$json = {
  '1': 'ChannelCreatedBody',
  '2': [
    {'1': 'channel_id', '3': 1, '4': 1, '5': 9, '10': 'channelId'},
    {
      '1': 'type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.ChannelType',
      '10': 'type'
    },
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'initial_members', '3': 4, '4': 3, '5': 12, '10': 'initialMembers'},
  ],
};

/// Descriptor for `ChannelCreatedBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List channelCreatedBodyDescriptor = $convert.base64Decode(
    'ChJDaGFubmVsQ3JlYXRlZEJvZHkSHQoKY2hhbm5lbF9pZBgBIAEoCVIJY2hhbm5lbElkEi4KBH'
    'R5cGUYAiABKA4yGi5yZXNpbGllbmNlLnYxLkNoYW5uZWxUeXBlUgR0eXBlEhIKBG5hbWUYAyAB'
    'KAlSBG5hbWUSJwoPaW5pdGlhbF9tZW1iZXJzGAQgAygMUg5pbml0aWFsTWVtYmVycw==');

@$core.Deprecated('Use channelMembershipBodyDescriptor instead')
const ChannelMembershipBody$json = {
  '1': 'ChannelMembershipBody',
  '2': [
    {'1': 'channel_id', '3': 1, '4': 1, '5': 9, '10': 'channelId'},
    {'1': 'added', '3': 2, '4': 3, '5': 12, '10': 'added'},
    {'1': 'removed', '3': 3, '4': 3, '5': 12, '10': 'removed'},
    {'1': 'epoch', '3': 4, '4': 1, '5': 4, '10': 'epoch'},
  ],
};

/// Descriptor for `ChannelMembershipBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List channelMembershipBodyDescriptor = $convert.base64Decode(
    'ChVDaGFubmVsTWVtYmVyc2hpcEJvZHkSHQoKY2hhbm5lbF9pZBgBIAEoCVIJY2hhbm5lbElkEh'
    'QKBWFkZGVkGAIgAygMUgVhZGRlZBIYCgdyZW1vdmVkGAMgAygMUgdyZW1vdmVkEhQKBWVwb2No'
    'GAQgASgEUgVlcG9jaA==');

@$core.Deprecated('Use messageBodyDescriptor instead')
const MessageBody$json = {
  '1': 'MessageBody',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'channel_id', '3': 2, '4': 1, '5': 9, '10': 'channelId'},
    {'1': 'recipient_hint', '3': 3, '4': 1, '5': 12, '10': 'recipientHint'},
    {'1': 'ciphertext', '3': 4, '4': 1, '5': 12, '10': 'ciphertext'},
    {'1': 'group_epoch', '3': 5, '4': 1, '5': 13, '10': 'groupEpoch'},
    {
      '1': 'priority',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.Priority',
      '10': 'priority'
    },
  ],
};

/// Descriptor for `MessageBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageBodyDescriptor = $convert.base64Decode(
    'CgtNZXNzYWdlQm9keRIdCgptZXNzYWdlX2lkGAEgASgJUgltZXNzYWdlSWQSHQoKY2hhbm5lbF'
    '9pZBgCIAEoCVIJY2hhbm5lbElkEiUKDnJlY2lwaWVudF9oaW50GAMgASgMUg1yZWNpcGllbnRI'
    'aW50Eh4KCmNpcGhlcnRleHQYBCABKAxSCmNpcGhlcnRleHQSHwoLZ3JvdXBfZXBvY2gYBSABKA'
    '1SCmdyb3VwRXBvY2gSMwoIcHJpb3JpdHkYBiABKA4yFy5yZXNpbGllbmNlLnYxLlByaW9yaXR5'
    'Ughwcmlvcml0eQ==');

@$core.Deprecated('Use receiptBodyDescriptor instead')
const ReceiptBody$json = {
  '1': 'ReceiptBody',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'by_pubkey', '3': 2, '4': 1, '5': 12, '10': 'byPubkey'},
  ],
};

/// Descriptor for `ReceiptBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List receiptBodyDescriptor = $convert.base64Decode(
    'CgtSZWNlaXB0Qm9keRIdCgptZXNzYWdlX2lkGAEgASgJUgltZXNzYWdlSWQSGwoJYnlfcHVia2'
    'V5GAIgASgMUghieVB1YmtleQ==');

@$core.Deprecated('Use prekeyBundleBodyDescriptor instead')
const PrekeyBundleBody$json = {
  '1': 'PrekeyBundleBody',
  '2': [
    {'1': 'identity_pubkey', '3': 1, '4': 1, '5': 12, '10': 'identityPubkey'},
    {'1': 'registration_id', '3': 2, '4': 1, '5': 13, '10': 'registrationId'},
    {'1': 'signed_prekey_id', '3': 3, '4': 1, '5': 13, '10': 'signedPrekeyId'},
    {
      '1': 'signed_prekey_pub',
      '3': 4,
      '4': 1,
      '5': 12,
      '10': 'signedPrekeyPub'
    },
    {
      '1': 'signed_prekey_sig',
      '3': 5,
      '4': 1,
      '5': 12,
      '10': 'signedPrekeySig'
    },
    {'1': 'prekey_id', '3': 6, '4': 1, '5': 13, '10': 'prekeyId'},
    {'1': 'prekey_pub', '3': 7, '4': 1, '5': 12, '10': 'prekeyPub'},
  ],
};

/// Descriptor for `PrekeyBundleBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List prekeyBundleBodyDescriptor = $convert.base64Decode(
    'ChBQcmVrZXlCdW5kbGVCb2R5EicKD2lkZW50aXR5X3B1YmtleRgBIAEoDFIOaWRlbnRpdHlQdW'
    'JrZXkSJwoPcmVnaXN0cmF0aW9uX2lkGAIgASgNUg5yZWdpc3RyYXRpb25JZBIoChBzaWduZWRf'
    'cHJla2V5X2lkGAMgASgNUg5zaWduZWRQcmVrZXlJZBIqChFzaWduZWRfcHJla2V5X3B1YhgEIA'
    'EoDFIPc2lnbmVkUHJla2V5UHViEioKEXNpZ25lZF9wcmVrZXlfc2lnGAUgASgMUg9zaWduZWRQ'
    'cmVrZXlTaWcSGwoJcHJla2V5X2lkGAYgASgNUghwcmVrZXlJZBIdCgpwcmVrZXlfcHViGAcgAS'
    'gMUglwcmVrZXlQdWI=');

@$core.Deprecated('Use missionBodyDescriptor instead')
const MissionBody$json = {
  '1': 'MissionBody',
  '2': [
    {'1': 'mission_id', '3': 1, '4': 1, '5': 9, '10': 'missionId'},
    {
      '1': 'cargo_category',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.ResourceCategory',
      '10': 'cargoCategory'
    },
    {
      '1': 'cargo_description',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'cargoDescription'
    },
    {'1': 'cargo_quantity', '3': 4, '4': 1, '5': 3, '10': 'cargoQuantity'},
    {'1': 'pickup_name', '3': 5, '4': 1, '5': 9, '10': 'pickupName'},
    {
      '1': 'pickup_location',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.GeoPoint',
      '10': 'pickupLocation'
    },
    {'1': 'destination_name', '3': 7, '4': 1, '5': 9, '10': 'destinationName'},
    {
      '1': 'destination_location',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.GeoPoint',
      '10': 'destinationLocation'
    },
    {
      '1': 'priority',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.Priority',
      '10': 'priority'
    },
    {'1': 'channel_id', '3': 10, '4': 1, '5': 9, '10': 'channelId'},
  ],
};

/// Descriptor for `MissionBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List missionBodyDescriptor = $convert.base64Decode(
    'CgtNaXNzaW9uQm9keRIdCgptaXNzaW9uX2lkGAEgASgJUgltaXNzaW9uSWQSRgoOY2FyZ29fY2'
    'F0ZWdvcnkYAiABKA4yHy5yZXNpbGllbmNlLnYxLlJlc291cmNlQ2F0ZWdvcnlSDWNhcmdvQ2F0'
    'ZWdvcnkSKwoRY2FyZ29fZGVzY3JpcHRpb24YAyABKAlSEGNhcmdvRGVzY3JpcHRpb24SJQoOY2'
    'FyZ29fcXVhbnRpdHkYBCABKANSDWNhcmdvUXVhbnRpdHkSHwoLcGlja3VwX25hbWUYBSABKAlS'
    'CnBpY2t1cE5hbWUSQAoPcGlja3VwX2xvY2F0aW9uGAYgASgLMhcucmVzaWxpZW5jZS52MS5HZW'
    '9Qb2ludFIOcGlja3VwTG9jYXRpb24SKQoQZGVzdGluYXRpb25fbmFtZRgHIAEoCVIPZGVzdGlu'
    'YXRpb25OYW1lEkoKFGRlc3RpbmF0aW9uX2xvY2F0aW9uGAggASgLMhcucmVzaWxpZW5jZS52MS'
    '5HZW9Qb2ludFITZGVzdGluYXRpb25Mb2NhdGlvbhIzCghwcmlvcml0eRgJIAEoDjIXLnJlc2ls'
    'aWVuY2UudjEuUHJpb3JpdHlSCHByaW9yaXR5Eh0KCmNoYW5uZWxfaWQYCiABKAlSCWNoYW5uZW'
    'xJZA==');

@$core.Deprecated('Use missionAcceptBodyDescriptor instead')
const MissionAcceptBody$json = {
  '1': 'MissionAcceptBody',
  '2': [
    {'1': 'mission_id', '3': 1, '4': 1, '5': 9, '10': 'missionId'},
    {'1': 'carrier_pubkey', '3': 2, '4': 1, '5': 12, '10': 'carrierPubkey'},
  ],
};

/// Descriptor for `MissionAcceptBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List missionAcceptBodyDescriptor = $convert.base64Decode(
    'ChFNaXNzaW9uQWNjZXB0Qm9keRIdCgptaXNzaW9uX2lkGAEgASgJUgltaXNzaW9uSWQSJQoOY2'
    'Fycmllcl9wdWJrZXkYAiABKAxSDWNhcnJpZXJQdWJrZXk=');

@$core.Deprecated('Use missionMatchBodyDescriptor instead')
const MissionMatchBody$json = {
  '1': 'MissionMatchBody',
  '2': [
    {'1': 'mission_id', '3': 1, '4': 1, '5': 9, '10': 'missionId'},
    {'1': 'request_id', '3': 2, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'offer_id', '3': 3, '4': 1, '5': 9, '10': 'offerId'},
  ],
};

/// Descriptor for `MissionMatchBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List missionMatchBodyDescriptor = $convert.base64Decode(
    'ChBNaXNzaW9uTWF0Y2hCb2R5Eh0KCm1pc3Npb25faWQYASABKAlSCW1pc3Npb25JZBIdCgpyZX'
    'F1ZXN0X2lkGAIgASgJUglyZXF1ZXN0SWQSGQoIb2ZmZXJfaWQYAyABKAlSB29mZmVySWQ=');

@$core.Deprecated('Use packageEventBodyDescriptor instead')
const PackageEventBody$json = {
  '1': 'PackageEventBody',
  '2': [
    {'1': 'package_id', '3': 1, '4': 1, '5': 9, '10': 'packageId'},
    {'1': 'mission_id', '3': 2, '4': 1, '5': 9, '10': 'missionId'},
    {'1': 'actor_pubkey', '3': 3, '4': 1, '5': 12, '10': 'actorPubkey'},
    {
      '1': 'counterparty_pubkey',
      '3': 4,
      '4': 1,
      '5': 12,
      '10': 'counterpartyPubkey'
    },
    {
      '1': 'stage',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.PackageEventBody.Stage',
      '10': 'stage'
    },
    {'1': 'at_ms', '3': 6, '4': 1, '5': 3, '10': 'atMs'},
  ],
  '4': [PackageEventBody_Stage$json],
};

@$core.Deprecated('Use packageEventBodyDescriptor instead')
const PackageEventBody_Stage$json = {
  '1': 'Stage',
  '2': [
    {'1': 'STAGE_UNSPECIFIED', '2': 0},
    {'1': 'STAGE_PICKED_UP', '2': 1},
    {'1': 'STAGE_TRANSFERRED', '2': 2},
    {'1': 'STAGE_DELIVERED', '2': 3},
  ],
};

/// Descriptor for `PackageEventBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List packageEventBodyDescriptor = $convert.base64Decode(
    'ChBQYWNrYWdlRXZlbnRCb2R5Eh0KCnBhY2thZ2VfaWQYASABKAlSCXBhY2thZ2VJZBIdCgptaX'
    'NzaW9uX2lkGAIgASgJUgltaXNzaW9uSWQSIQoMYWN0b3JfcHVia2V5GAMgASgMUgthY3RvclB1'
    'YmtleRIvChNjb3VudGVycGFydHlfcHVia2V5GAQgASgMUhJjb3VudGVycGFydHlQdWJrZXkSOw'
    'oFc3RhZ2UYBSABKA4yJS5yZXNpbGllbmNlLnYxLlBhY2thZ2VFdmVudEJvZHkuU3RhZ2VSBXN0'
    'YWdlEhMKBWF0X21zGAYgASgDUgRhdE1zIl8KBVN0YWdlEhUKEVNUQUdFX1VOU1BFQ0lGSUVEEA'
    'ASEwoPU1RBR0VfUElDS0VEX1VQEAESFQoRU1RBR0VfVFJBTlNGRVJSRUQQAhITCg9TVEFHRV9E'
    'RUxJVkVSRUQQAw==');

@$core.Deprecated('Use capabilityBodyDescriptor instead')
const CapabilityBody$json = {
  '1': 'CapabilityBody',
  '2': [
    {'1': 'capability_id', '3': 1, '4': 1, '5': 9, '10': 'capabilityId'},
    {'1': 'subject_pubkey', '3': 2, '4': 1, '5': 12, '10': 'subjectPubkey'},
    {'1': 'issuer_pubkey', '3': 3, '4': 1, '5': 12, '10': 'issuerPubkey'},
    {'1': 'scope', '3': 4, '4': 1, '5': 9, '10': 'scope'},
    {'1': 'actions', '3': 5, '4': 3, '5': 9, '10': 'actions'},
    {'1': 'valid_until_ms', '3': 6, '4': 1, '5': 3, '10': 'validUntilMs'},
  ],
};

/// Descriptor for `CapabilityBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List capabilityBodyDescriptor = $convert.base64Decode(
    'Cg5DYXBhYmlsaXR5Qm9keRIjCg1jYXBhYmlsaXR5X2lkGAEgASgJUgxjYXBhYmlsaXR5SWQSJQ'
    'oOc3ViamVjdF9wdWJrZXkYAiABKAxSDXN1YmplY3RQdWJrZXkSIwoNaXNzdWVyX3B1YmtleRgD'
    'IAEoDFIMaXNzdWVyUHVia2V5EhQKBXNjb3BlGAQgASgJUgVzY29wZRIYCgdhY3Rpb25zGAUgAy'
    'gJUgdhY3Rpb25zEiQKDnZhbGlkX3VudGlsX21zGAYgASgDUgx2YWxpZFVudGlsTXM=');

@$core.Deprecated('Use emergencyAlertBodyDescriptor instead')
const EmergencyAlertBody$json = {
  '1': 'EmergencyAlertBody',
  '2': [
    {'1': 'alert_id', '3': 1, '4': 1, '5': 9, '10': 'alertId'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'detail', '3': 3, '4': 1, '5': 9, '10': 'detail'},
    {
      '1': 'priority',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.resilience.v1.Priority',
      '10': 'priority'
    },
    {
      '1': 'area',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.GeoPoint',
      '10': 'area'
    },
    {'1': 'expires_ms', '3': 6, '4': 1, '5': 3, '10': 'expiresMs'},
  ],
};

/// Descriptor for `EmergencyAlertBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emergencyAlertBodyDescriptor = $convert.base64Decode(
    'ChJFbWVyZ2VuY3lBbGVydEJvZHkSGQoIYWxlcnRfaWQYASABKAlSB2FsZXJ0SWQSFAoFdGl0bG'
    'UYAiABKAlSBXRpdGxlEhYKBmRldGFpbBgDIAEoCVIGZGV0YWlsEjMKCHByaW9yaXR5GAQgASgO'
    'MhcucmVzaWxpZW5jZS52MS5Qcmlvcml0eVIIcHJpb3JpdHkSKwoEYXJlYRgFIAEoCzIXLnJlc2'
    'lsaWVuY2UudjEuR2VvUG9pbnRSBGFyZWESHQoKZXhwaXJlc19tcxgGIAEoA1IJZXhwaXJlc01z');

@$core.Deprecated('Use locationShareBodyDescriptor instead')
const LocationShareBody$json = {
  '1': 'LocationShareBody',
  '2': [
    {'1': 'share_id', '3': 1, '4': 1, '5': 9, '10': 'shareId'},
    {'1': 'scope', '3': 2, '4': 1, '5': 9, '10': 'scope'},
    {'1': 'h3_cell', '3': 3, '4': 1, '5': 4, '10': 'h3Cell'},
    {
      '1': 'public_point',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.resilience.v1.GeoPoint',
      '10': 'publicPoint'
    },
    {'1': 'encrypted_point', '3': 5, '4': 1, '5': 12, '10': 'encryptedPoint'},
    {'1': 'expires_ms', '3': 6, '4': 1, '5': 3, '10': 'expiresMs'},
    {'1': 'note', '3': 7, '4': 1, '5': 9, '10': 'note'},
    {'1': 'seq', '3': 8, '4': 1, '5': 4, '10': 'seq'},
  ],
};

/// Descriptor for `LocationShareBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List locationShareBodyDescriptor = $convert.base64Decode(
    'ChFMb2NhdGlvblNoYXJlQm9keRIZCghzaGFyZV9pZBgBIAEoCVIHc2hhcmVJZBIUCgVzY29wZR'
    'gCIAEoCVIFc2NvcGUSFwoHaDNfY2VsbBgDIAEoBFIGaDNDZWxsEjoKDHB1YmxpY19wb2ludBgE'
    'IAEoCzIXLnJlc2lsaWVuY2UudjEuR2VvUG9pbnRSC3B1YmxpY1BvaW50EicKD2VuY3J5cHRlZF'
    '9wb2ludBgFIAEoDFIOZW5jcnlwdGVkUG9pbnQSHQoKZXhwaXJlc19tcxgGIAEoA1IJZXhwaXJl'
    'c01zEhIKBG5vdGUYByABKAlSBG5vdGUSEAoDc2VxGAggASgEUgNzZXE=');

@$core.Deprecated('Use locationStopBodyDescriptor instead')
const LocationStopBody$json = {
  '1': 'LocationStopBody',
  '2': [
    {'1': 'share_id', '3': 1, '4': 1, '5': 9, '10': 'shareId'},
    {'1': 'stopped_at_ms', '3': 2, '4': 1, '5': 3, '10': 'stoppedAtMs'},
  ],
};

/// Descriptor for `LocationStopBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List locationStopBodyDescriptor = $convert.base64Decode(
    'ChBMb2NhdGlvblN0b3BCb2R5EhkKCHNoYXJlX2lkGAEgASgJUgdzaGFyZUlkEiIKDXN0b3BwZW'
    'RfYXRfbXMYAiABKANSC3N0b3BwZWRBdE1z');
