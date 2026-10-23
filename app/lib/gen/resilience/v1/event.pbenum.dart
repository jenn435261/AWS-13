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

import 'package:protobuf/protobuf.dart' as $pb;

class EventType extends $pb.ProtobufEnum {
  static const EventType EVENT_TYPE_UNSPECIFIED =
      EventType._(0, _omitEnumNames ? '' : 'EVENT_TYPE_UNSPECIFIED');

  /// Identity & trust
  static const EventType EVENT_TYPE_IDENTITY_CERTIFICATE =
      EventType._(1, _omitEnumNames ? '' : 'EVENT_TYPE_IDENTITY_CERTIFICATE');
  static const EventType EVENT_TYPE_KEY_REVOKED =
      EventType._(2, _omitEnumNames ? '' : 'EVENT_TYPE_KEY_REVOKED');
  static const EventType EVENT_TYPE_ORG_CERTIFICATE =
      EventType._(3, _omitEnumNames ? '' : 'EVENT_TYPE_ORG_CERTIFICATE');

  /// Resources & observations
  static const EventType EVENT_TYPE_RESOURCE_CREATED =
      EventType._(10, _omitEnumNames ? '' : 'EVENT_TYPE_RESOURCE_CREATED');
  static const EventType EVENT_TYPE_RESOURCE_UPDATED =
      EventType._(11, _omitEnumNames ? '' : 'EVENT_TYPE_RESOURCE_UPDATED');
  static const EventType EVENT_TYPE_RESOURCE_OBSERVED =
      EventType._(12, _omitEnumNames ? '' : 'EVENT_TYPE_RESOURCE_OBSERVED');
  static const EventType EVENT_TYPE_RESOURCE_CONFIRMED =
      EventType._(13, _omitEnumNames ? '' : 'EVENT_TYPE_RESOURCE_CONFIRMED');
  static const EventType EVENT_TYPE_RESOURCE_DISPUTED =
      EventType._(14, _omitEnumNames ? '' : 'EVENT_TYPE_RESOURCE_DISPUTED');
  static const EventType EVENT_TYPE_RESOURCE_USEFUL =
      EventType._(15, _omitEnumNames ? '' : 'EVENT_TYPE_RESOURCE_USEFUL');
  static const EventType EVENT_TYPE_INVENTORY_SNAPSHOT =
      EventType._(16, _omitEnumNames ? '' : 'EVENT_TYPE_INVENTORY_SNAPSHOT');
  static const EventType EVENT_TYPE_RESERVATION =
      EventType._(17, _omitEnumNames ? '' : 'EVENT_TYPE_RESERVATION');

  /// Help flows
  static const EventType EVENT_TYPE_HELP_REQUESTED =
      EventType._(20, _omitEnumNames ? '' : 'EVENT_TYPE_HELP_REQUESTED');
  static const EventType EVENT_TYPE_HELP_OFFERED =
      EventType._(21, _omitEnumNames ? '' : 'EVENT_TYPE_HELP_OFFERED');
  static const EventType EVENT_TYPE_SHELTER_CREATED =
      EventType._(22, _omitEnumNames ? '' : 'EVENT_TYPE_SHELTER_CREATED');
  static const EventType EVENT_TYPE_TRANSPORT_OFFERED =
      EventType._(23, _omitEnumNames ? '' : 'EVENT_TYPE_TRANSPORT_OFFERED');

  /// Messaging (ciphertext payloads; relays cannot read)
  static const EventType EVENT_TYPE_MESSAGE_SENT =
      EventType._(30, _omitEnumNames ? '' : 'EVENT_TYPE_MESSAGE_SENT');
  static const EventType EVENT_TYPE_MESSAGE_DELIVERED =
      EventType._(31, _omitEnumNames ? '' : 'EVENT_TYPE_MESSAGE_DELIVERED');
  static const EventType EVENT_TYPE_MESSAGE_READ =
      EventType._(32, _omitEnumNames ? '' : 'EVENT_TYPE_MESSAGE_READ');
  static const EventType EVENT_TYPE_CHANNEL_CREATED =
      EventType._(33, _omitEnumNames ? '' : 'EVENT_TYPE_CHANNEL_CREATED');
  static const EventType EVENT_TYPE_CHANNEL_MEMBERSHIP =
      EventType._(34, _omitEnumNames ? '' : 'EVENT_TYPE_CHANNEL_MEMBERSHIP');
  static const EventType EVENT_TYPE_PREKEY_BUNDLE =
      EventType._(35, _omitEnumNames ? '' : 'EVENT_TYPE_PREKEY_BUNDLE');

  /// Logistics / missions
  static const EventType EVENT_TYPE_MISSION_CREATED =
      EventType._(40, _omitEnumNames ? '' : 'EVENT_TYPE_MISSION_CREATED');
  static const EventType EVENT_TYPE_MISSION_ACCEPTED =
      EventType._(41, _omitEnumNames ? '' : 'EVENT_TYPE_MISSION_ACCEPTED');
  static const EventType EVENT_TYPE_MISSION_MATCHED =
      EventType._(42, _omitEnumNames ? '' : 'EVENT_TYPE_MISSION_MATCHED');
  static const EventType EVENT_TYPE_PACKAGE_PICKED_UP =
      EventType._(43, _omitEnumNames ? '' : 'EVENT_TYPE_PACKAGE_PICKED_UP');
  static const EventType EVENT_TYPE_PACKAGE_TRANSFERRED =
      EventType._(44, _omitEnumNames ? '' : 'EVENT_TYPE_PACKAGE_TRANSFERRED');
  static const EventType EVENT_TYPE_DELIVERY_COMPLETED =
      EventType._(45, _omitEnumNames ? '' : 'EVENT_TYPE_DELIVERY_COMPLETED');
  static const EventType EVENT_TYPE_CAPABILITY_GRANTED =
      EventType._(46, _omitEnumNames ? '' : 'EVENT_TYPE_CAPABILITY_GRANTED');
  static const EventType EVENT_TYPE_CAPABILITY_REVOKED =
      EventType._(47, _omitEnumNames ? '' : 'EVENT_TYPE_CAPABILITY_REVOKED');

  /// Emergency info
  static const EventType EVENT_TYPE_EMERGENCY_ALERT =
      EventType._(50, _omitEnumNames ? '' : 'EVENT_TYPE_EMERGENCY_ALERT');

  static const $core.List<EventType> values = <EventType>[
    EVENT_TYPE_UNSPECIFIED,
    EVENT_TYPE_IDENTITY_CERTIFICATE,
    EVENT_TYPE_KEY_REVOKED,
    EVENT_TYPE_ORG_CERTIFICATE,
    EVENT_TYPE_RESOURCE_CREATED,
    EVENT_TYPE_RESOURCE_UPDATED,
    EVENT_TYPE_RESOURCE_OBSERVED,
    EVENT_TYPE_RESOURCE_CONFIRMED,
    EVENT_TYPE_RESOURCE_DISPUTED,
    EVENT_TYPE_RESOURCE_USEFUL,
    EVENT_TYPE_INVENTORY_SNAPSHOT,
    EVENT_TYPE_RESERVATION,
    EVENT_TYPE_HELP_REQUESTED,
    EVENT_TYPE_HELP_OFFERED,
    EVENT_TYPE_SHELTER_CREATED,
    EVENT_TYPE_TRANSPORT_OFFERED,
    EVENT_TYPE_MESSAGE_SENT,
    EVENT_TYPE_MESSAGE_DELIVERED,
    EVENT_TYPE_MESSAGE_READ,
    EVENT_TYPE_CHANNEL_CREATED,
    EVENT_TYPE_CHANNEL_MEMBERSHIP,
    EVENT_TYPE_PREKEY_BUNDLE,
    EVENT_TYPE_MISSION_CREATED,
    EVENT_TYPE_MISSION_ACCEPTED,
    EVENT_TYPE_MISSION_MATCHED,
    EVENT_TYPE_PACKAGE_PICKED_UP,
    EVENT_TYPE_PACKAGE_TRANSFERRED,
    EVENT_TYPE_DELIVERY_COMPLETED,
    EVENT_TYPE_CAPABILITY_GRANTED,
    EVENT_TYPE_CAPABILITY_REVOKED,
    EVENT_TYPE_EMERGENCY_ALERT,
  ];

  static final $core.Map<$core.int, EventType> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static EventType? valueOf($core.int value) => _byValue[value];

  const EventType._(super.value, super.name);
}

class ResourceCategory extends $pb.ProtobufEnum {
  static const ResourceCategory RESOURCE_CATEGORY_UNSPECIFIED =
      ResourceCategory._(
          0, _omitEnumNames ? '' : 'RESOURCE_CATEGORY_UNSPECIFIED');
  static const ResourceCategory RESOURCE_CATEGORY_WATER =
      ResourceCategory._(1, _omitEnumNames ? '' : 'RESOURCE_CATEGORY_WATER');
  static const ResourceCategory RESOURCE_CATEGORY_FOOD =
      ResourceCategory._(2, _omitEnumNames ? '' : 'RESOURCE_CATEGORY_FOOD');
  static const ResourceCategory RESOURCE_CATEGORY_MEDICINE =
      ResourceCategory._(3, _omitEnumNames ? '' : 'RESOURCE_CATEGORY_MEDICINE');
  static const ResourceCategory RESOURCE_CATEGORY_SHELTER =
      ResourceCategory._(4, _omitEnumNames ? '' : 'RESOURCE_CATEGORY_SHELTER');
  static const ResourceCategory RESOURCE_CATEGORY_POWER =
      ResourceCategory._(5, _omitEnumNames ? '' : 'RESOURCE_CATEGORY_POWER');
  static const ResourceCategory RESOURCE_CATEGORY_TRANSPORTATION =
      ResourceCategory._(
          6, _omitEnumNames ? '' : 'RESOURCE_CATEGORY_TRANSPORTATION');
  static const ResourceCategory RESOURCE_CATEGORY_MEDICAL_HELP =
      ResourceCategory._(
          7, _omitEnumNames ? '' : 'RESOURCE_CATEGORY_MEDICAL_HELP');
  static const ResourceCategory RESOURCE_CATEGORY_COMMUNICATION =
      ResourceCategory._(
          8, _omitEnumNames ? '' : 'RESOURCE_CATEGORY_COMMUNICATION');
  static const ResourceCategory RESOURCE_CATEGORY_BLANKETS =
      ResourceCategory._(9, _omitEnumNames ? '' : 'RESOURCE_CATEGORY_BLANKETS');
  static const ResourceCategory RESOURCE_CATEGORY_BATTERIES =
      ResourceCategory._(
          10, _omitEnumNames ? '' : 'RESOURCE_CATEGORY_BATTERIES');
  static const ResourceCategory RESOURCE_CATEGORY_CHARGING = ResourceCategory._(
      11, _omitEnumNames ? '' : 'RESOURCE_CATEGORY_CHARGING');
  static const ResourceCategory RESOURCE_CATEGORY_TOOLS =
      ResourceCategory._(12, _omitEnumNames ? '' : 'RESOURCE_CATEGORY_TOOLS');
  static const ResourceCategory RESOURCE_CATEGORY_OTHER =
      ResourceCategory._(99, _omitEnumNames ? '' : 'RESOURCE_CATEGORY_OTHER');

  static const $core.List<ResourceCategory> values = <ResourceCategory>[
    RESOURCE_CATEGORY_UNSPECIFIED,
    RESOURCE_CATEGORY_WATER,
    RESOURCE_CATEGORY_FOOD,
    RESOURCE_CATEGORY_MEDICINE,
    RESOURCE_CATEGORY_SHELTER,
    RESOURCE_CATEGORY_POWER,
    RESOURCE_CATEGORY_TRANSPORTATION,
    RESOURCE_CATEGORY_MEDICAL_HELP,
    RESOURCE_CATEGORY_COMMUNICATION,
    RESOURCE_CATEGORY_BLANKETS,
    RESOURCE_CATEGORY_BATTERIES,
    RESOURCE_CATEGORY_CHARGING,
    RESOURCE_CATEGORY_TOOLS,
    RESOURCE_CATEGORY_OTHER,
  ];

  static final $core.Map<$core.int, ResourceCategory> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static ResourceCategory? valueOf($core.int value) => _byValue[value];

  const ResourceCategory._(super.value, super.name);
}

class AmountBand extends $pb.ProtobufEnum {
  static const AmountBand AMOUNT_BAND_UNSPECIFIED =
      AmountBand._(0, _omitEnumNames ? '' : 'AMOUNT_BAND_UNSPECIFIED');
  static const AmountBand AMOUNT_BAND_PLENTY =
      AmountBand._(1, _omitEnumNames ? '' : 'AMOUNT_BAND_PLENTY');
  static const AmountBand AMOUNT_BAND_SOME =
      AmountBand._(2, _omitEnumNames ? '' : 'AMOUNT_BAND_SOME');
  static const AmountBand AMOUNT_BAND_LOW =
      AmountBand._(3, _omitEnumNames ? '' : 'AMOUNT_BAND_LOW');

  static const $core.List<AmountBand> values = <AmountBand>[
    AMOUNT_BAND_UNSPECIFIED,
    AMOUNT_BAND_PLENTY,
    AMOUNT_BAND_SOME,
    AMOUNT_BAND_LOW,
  ];

  static final $core.List<AmountBand?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static AmountBand? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AmountBand._(super.value, super.name);
}

class Availability extends $pb.ProtobufEnum {
  static const Availability AVAILABILITY_UNSPECIFIED =
      Availability._(0, _omitEnumNames ? '' : 'AVAILABILITY_UNSPECIFIED');
  static const Availability AVAILABILITY_NOW =
      Availability._(1, _omitEnumNames ? '' : 'AVAILABILITY_NOW');
  static const Availability AVAILABILITY_TODAY =
      Availability._(2, _omitEnumNames ? '' : 'AVAILABILITY_TODAY');
  static const Availability AVAILABILITY_CUSTOM =
      Availability._(3, _omitEnumNames ? '' : 'AVAILABILITY_CUSTOM');

  static const $core.List<Availability> values = <Availability>[
    AVAILABILITY_UNSPECIFIED,
    AVAILABILITY_NOW,
    AVAILABILITY_TODAY,
    AVAILABILITY_CUSTOM,
  ];

  static final $core.List<Availability?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static Availability? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Availability._(super.value, super.name);
}

class ProvenanceKind extends $pb.ProtobufEnum {
  static const ProvenanceKind PROVENANCE_KIND_UNSPECIFIED =
      ProvenanceKind._(0, _omitEnumNames ? '' : 'PROVENANCE_KIND_UNSPECIFIED');
  static const ProvenanceKind PROVENANCE_KIND_COMMUNITY =
      ProvenanceKind._(1, _omitEnumNames ? '' : 'PROVENANCE_KIND_COMMUNITY');
  static const ProvenanceKind PROVENANCE_KIND_VERIFIED_ORG =
      ProvenanceKind._(2, _omitEnumNames ? '' : 'PROVENANCE_KIND_VERIFIED_ORG');

  static const $core.List<ProvenanceKind> values = <ProvenanceKind>[
    PROVENANCE_KIND_UNSPECIFIED,
    PROVENANCE_KIND_COMMUNITY,
    PROVENANCE_KIND_VERIFIED_ORG,
  ];

  static final $core.List<ProvenanceKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ProvenanceKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ProvenanceKind._(super.value, super.name);
}

class Priority extends $pb.ProtobufEnum {
  static const Priority PRIORITY_UNSPECIFIED =
      Priority._(0, _omitEnumNames ? '' : 'PRIORITY_UNSPECIFIED');
  static const Priority PRIORITY_LOW =
      Priority._(1, _omitEnumNames ? '' : 'PRIORITY_LOW');
  static const Priority PRIORITY_NORMAL =
      Priority._(2, _omitEnumNames ? '' : 'PRIORITY_NORMAL');
  static const Priority PRIORITY_HIGH =
      Priority._(3, _omitEnumNames ? '' : 'PRIORITY_HIGH');
  static const Priority PRIORITY_CRITICAL =
      Priority._(4, _omitEnumNames ? '' : 'PRIORITY_CRITICAL');

  static const $core.List<Priority> values = <Priority>[
    PRIORITY_UNSPECIFIED,
    PRIORITY_LOW,
    PRIORITY_NORMAL,
    PRIORITY_HIGH,
    PRIORITY_CRITICAL,
  ];

  static final $core.List<Priority?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static Priority? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Priority._(super.value, super.name);
}

class TransportMode extends $pb.ProtobufEnum {
  static const TransportMode TRANSPORT_MODE_UNSPECIFIED =
      TransportMode._(0, _omitEnumNames ? '' : 'TRANSPORT_MODE_UNSPECIFIED');
  static const TransportMode TRANSPORT_MODE_WALKING =
      TransportMode._(1, _omitEnumNames ? '' : 'TRANSPORT_MODE_WALKING');
  static const TransportMode TRANSPORT_MODE_BICYCLE =
      TransportMode._(2, _omitEnumNames ? '' : 'TRANSPORT_MODE_BICYCLE');
  static const TransportMode TRANSPORT_MODE_CAR =
      TransportMode._(3, _omitEnumNames ? '' : 'TRANSPORT_MODE_CAR');
  static const TransportMode TRANSPORT_MODE_TRUCK =
      TransportMode._(4, _omitEnumNames ? '' : 'TRANSPORT_MODE_TRUCK');
  static const TransportMode TRANSPORT_MODE_VAN =
      TransportMode._(5, _omitEnumNames ? '' : 'TRANSPORT_MODE_VAN');

  static const $core.List<TransportMode> values = <TransportMode>[
    TRANSPORT_MODE_UNSPECIFIED,
    TRANSPORT_MODE_WALKING,
    TRANSPORT_MODE_BICYCLE,
    TRANSPORT_MODE_CAR,
    TRANSPORT_MODE_TRUCK,
    TRANSPORT_MODE_VAN,
  ];

  static final $core.List<TransportMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static TransportMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TransportMode._(super.value, super.name);
}

class CapacityBand extends $pb.ProtobufEnum {
  static const CapacityBand CAPACITY_BAND_UNSPECIFIED =
      CapacityBand._(0, _omitEnumNames ? '' : 'CAPACITY_BAND_UNSPECIFIED');
  static const CapacityBand CAPACITY_BAND_SMALL =
      CapacityBand._(1, _omitEnumNames ? '' : 'CAPACITY_BAND_SMALL');
  static const CapacityBand CAPACITY_BAND_MEDIUM =
      CapacityBand._(2, _omitEnumNames ? '' : 'CAPACITY_BAND_MEDIUM');
  static const CapacityBand CAPACITY_BAND_LARGE =
      CapacityBand._(3, _omitEnumNames ? '' : 'CAPACITY_BAND_LARGE');

  static const $core.List<CapacityBand> values = <CapacityBand>[
    CAPACITY_BAND_UNSPECIFIED,
    CAPACITY_BAND_SMALL,
    CAPACITY_BAND_MEDIUM,
    CAPACITY_BAND_LARGE,
  ];

  static final $core.List<CapacityBand?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static CapacityBand? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CapacityBand._(super.value, super.name);
}

class ChannelType extends $pb.ProtobufEnum {
  static const ChannelType CHANNEL_TYPE_UNSPECIFIED =
      ChannelType._(0, _omitEnumNames ? '' : 'CHANNEL_TYPE_UNSPECIFIED');
  static const ChannelType CHANNEL_TYPE_DIRECT =
      ChannelType._(1, _omitEnumNames ? '' : 'CHANNEL_TYPE_DIRECT');
  static const ChannelType CHANNEL_TYPE_PUBLIC =
      ChannelType._(2, _omitEnumNames ? '' : 'CHANNEL_TYPE_PUBLIC');
  static const ChannelType CHANNEL_TYPE_COMMUNITY =
      ChannelType._(3, _omitEnumNames ? '' : 'CHANNEL_TYPE_COMMUNITY');
  static const ChannelType CHANNEL_TYPE_RESTRICTED =
      ChannelType._(4, _omitEnumNames ? '' : 'CHANNEL_TYPE_RESTRICTED');
  static const ChannelType CHANNEL_TYPE_MISSION =
      ChannelType._(5, _omitEnumNames ? '' : 'CHANNEL_TYPE_MISSION');

  static const $core.List<ChannelType> values = <ChannelType>[
    CHANNEL_TYPE_UNSPECIFIED,
    CHANNEL_TYPE_DIRECT,
    CHANNEL_TYPE_PUBLIC,
    CHANNEL_TYPE_COMMUNITY,
    CHANNEL_TYPE_RESTRICTED,
    CHANNEL_TYPE_MISSION,
  ];

  static final $core.List<ChannelType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static ChannelType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ChannelType._(super.value, super.name);
}

class ObservationBody_Kind extends $pb.ProtobufEnum {
  static const ObservationBody_Kind KIND_UNSPECIFIED =
      ObservationBody_Kind._(0, _omitEnumNames ? '' : 'KIND_UNSPECIFIED');
  static const ObservationBody_Kind KIND_OBSERVED =
      ObservationBody_Kind._(1, _omitEnumNames ? '' : 'KIND_OBSERVED');
  static const ObservationBody_Kind KIND_CONFIRMED =
      ObservationBody_Kind._(2, _omitEnumNames ? '' : 'KIND_CONFIRMED');
  static const ObservationBody_Kind KIND_DISPUTED =
      ObservationBody_Kind._(3, _omitEnumNames ? '' : 'KIND_DISPUTED');
  static const ObservationBody_Kind KIND_USEFUL =
      ObservationBody_Kind._(4, _omitEnumNames ? '' : 'KIND_USEFUL');

  static const $core.List<ObservationBody_Kind> values = <ObservationBody_Kind>[
    KIND_UNSPECIFIED,
    KIND_OBSERVED,
    KIND_CONFIRMED,
    KIND_DISPUTED,
    KIND_USEFUL,
  ];

  static final $core.List<ObservationBody_Kind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static ObservationBody_Kind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ObservationBody_Kind._(super.value, super.name);
}

class PackageEventBody_Stage extends $pb.ProtobufEnum {
  static const PackageEventBody_Stage STAGE_UNSPECIFIED =
      PackageEventBody_Stage._(0, _omitEnumNames ? '' : 'STAGE_UNSPECIFIED');
  static const PackageEventBody_Stage STAGE_PICKED_UP =
      PackageEventBody_Stage._(1, _omitEnumNames ? '' : 'STAGE_PICKED_UP');
  static const PackageEventBody_Stage STAGE_TRANSFERRED =
      PackageEventBody_Stage._(2, _omitEnumNames ? '' : 'STAGE_TRANSFERRED');
  static const PackageEventBody_Stage STAGE_DELIVERED =
      PackageEventBody_Stage._(3, _omitEnumNames ? '' : 'STAGE_DELIVERED');

  static const $core.List<PackageEventBody_Stage> values =
      <PackageEventBody_Stage>[
    STAGE_UNSPECIFIED,
    STAGE_PICKED_UP,
    STAGE_TRANSFERRED,
    STAGE_DELIVERED,
  ];

  static final $core.List<PackageEventBody_Stage?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static PackageEventBody_Stage? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PackageEventBody_Stage._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
