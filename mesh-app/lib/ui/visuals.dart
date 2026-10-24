import 'package:flutter/material.dart';

import '../models/event.dart';
import '../models/help.dart';
import '../models/mesh_message.dart';
import '../models/mission.dart';
import '../models/resource.dart';
import '../models/social.dart';

/// Icons and colors for the app's fixed choices, defined once.
/// Color is never the only signal: every state also has its own icon.

/// The SOS red stays the same in light and dark themes, so the button is
/// always recognizable. White text on it meets 4.5:1 contrast.
const sosRed = Color(0xFFD7263D);

/// Each kind of need or place has its own color, the same in every list,
/// card and map pin. Each also has its own icon, so color is never the only
/// signal. White icons on these colors meet 3:1 contrast.
abstract final class Hues {
  static const water = Color(0xFF1C6FE8);
  static const food = Color(0xFFD9480F);
  static const medicine = Color(0xFFC2255C);
  static const medical = Color(0xFFE03131);
  static const shelter = Color(0xFF6741D9);
  static const power = Color(0xFFE67700);
  static const transport = Color(0xFF0C8599);
  static const communication = Color(0xFF3B5BDB);
  static const police = Color(0xFF364FC7);
  static const fire = Color(0xFFE8590C);
  static const caution = Color(0xFFF59F00);

  /// Caution, dark enough for an icon on white.
  static const cautionInk = Color(0xFFB35C00);
  static const other = Color(0xFF5C677D);
  static const tools = Color(0xFF7950F2);
}

Color helpKindHue(HelpKind kind) => switch (kind) {
      HelpKind.water => Hues.water,
      HelpKind.food => Hues.food,
      HelpKind.medicine => Hues.medicine,
      HelpKind.shelter => Hues.shelter,
      HelpKind.power => Hues.power,
      HelpKind.transportation => Hues.transport,
      HelpKind.medical => Hues.medical,
      HelpKind.communication => Hues.communication,
      HelpKind.other => Hues.other,
    };

Color requestHue(HelpRequest r) => r.sos ? sosRed : helpKindHue(r.kind);

Color supplyHue(SupplyKind k) => switch (k) {
      SupplyKind.water => Hues.water,
      SupplyKind.food => Hues.food,
      SupplyKind.blankets => Hues.shelter,
      SupplyKind.batteries => Hues.power,
      SupplyKind.charging => Hues.power,
      SupplyKind.medicine => Hues.medicine,
      SupplyKind.transportation => Hues.transport,
      SupplyKind.shelter => Hues.shelter,
      SupplyKind.tools => Hues.tools,
      SupplyKind.other => Hues.other,
    };

Color resourceHue(ResourceKind k) => switch (k) {
      ResourceKind.hospital => Hues.medical,
      ResourceKind.pharmacy => Hues.medicine,
      ResourceKind.police => Hues.police,
      ResourceKind.fire => Hues.fire,
      ResourceKind.water => Hues.water,
      ResourceKind.food => Hues.food,
      ResourceKind.shelter => Hues.shelter,
      ResourceKind.charging => Hues.power,
      ResourceKind.transportation => Hues.transport,
      ResourceKind.roadProblem => Hues.caution,
    };

/// A stable color for a person, from their name, for avatars.
Color personHue(String name) {
  const hues = [
    Hues.water, Hues.shelter, Hues.transport, Hues.medicine,
    Hues.communication, Hues.food, Hues.tools, Hues.police,
  ];
  return hues[name.codeUnits.fold(0, (a, b) => a + b) % hues.length];
}

IconData helpKindIcon(HelpKind kind) => switch (kind) {
      HelpKind.water => Icons.water_drop_outlined,
      HelpKind.food => Icons.restaurant_outlined,
      HelpKind.medicine => Icons.medication_outlined,
      HelpKind.shelter => Icons.night_shelter_outlined,
      HelpKind.power => Icons.battery_charging_full,
      HelpKind.transportation => Icons.directions_car_outlined,
      HelpKind.medical => Icons.medical_services_outlined,
      HelpKind.communication => Icons.forum_outlined,
      HelpKind.other => Icons.more_horiz,
    };

IconData requestIcon(HelpRequest r) => r.sos ? Icons.sos : helpKindIcon(r.kind);

IconData urgencyIcon(Urgency u) => switch (u) {
      Urgency.now => Icons.priority_high,
      Urgency.soon => Icons.schedule,
      Urgency.later => Icons.hourglass_empty,
    };

/// Background and foreground for an urgency badge.
(Color, Color) urgencyColors(Urgency u, ColorScheme c) => switch (u) {
      Urgency.now => (sosRed, Colors.white),
      Urgency.soon => (c.tertiaryContainer, c.onTertiaryContainer),
      Urgency.later => (c.secondaryContainer, c.onSecondaryContainer),
    };

/// One color per urgency, for dots and rings.
Color urgencyHue(Urgency u) => switch (u) {
      Urgency.now => sosRed,
      Urgency.soon => Hues.caution,
      Urgency.later => Hues.other,
    };

IconData supplyIcon(SupplyKind k) => switch (k) {
      SupplyKind.water => Icons.water_drop_outlined,
      SupplyKind.food => Icons.restaurant_outlined,
      SupplyKind.blankets => Icons.bed_outlined,
      SupplyKind.batteries => Icons.battery_full,
      SupplyKind.charging => Icons.power_outlined,
      SupplyKind.medicine => Icons.medication_outlined,
      SupplyKind.transportation => Icons.local_shipping_outlined,
      SupplyKind.shelter => Icons.night_shelter_outlined,
      SupplyKind.tools => Icons.handyman_outlined,
      SupplyKind.other => Icons.more_horiz,
    };

IconData transportIcon(TransportMode t) => switch (t) {
      TransportMode.walking => Icons.directions_walk,
      TransportMode.bicycle => Icons.pedal_bike,
      TransportMode.car => Icons.directions_car,
      TransportMode.truck => Icons.local_shipping,
      TransportMode.van => Icons.airport_shuttle,
    };

IconData resourceIcon(ResourceKind k) => switch (k) {
      ResourceKind.hospital => Icons.local_hospital,
      ResourceKind.pharmacy => Icons.local_pharmacy,
      ResourceKind.police => Icons.local_police,
      ResourceKind.fire => Icons.fire_truck,
      ResourceKind.water => Icons.water_drop,
      ResourceKind.food => Icons.restaurant,
      ResourceKind.shelter => Icons.night_shelter,
      ResourceKind.charging => Icons.ev_station,
      ResourceKind.transportation => Icons.directions_car,
      ResourceKind.roadProblem => Icons.warning_amber,
    };

/// Verified: a filled check. Community: an open circle. Unconfirmed: a
/// warning. Spec sections 7 and 10.
IconData provenanceIcon(Resource r) => r.verified
    ? Icons.verified
    : r.confidence == Confidence.unconfirmed
        ? Icons.warning_amber
        : Icons.radio_button_unchecked;

IconData stageIcon(RequestStage s) => switch (s) {
      RequestStage.saved => Icons.smartphone,
      RequestStage.mesh => Icons.cell_tower,
      RequestStage.verified => Icons.verified_outlined,
      RequestStage.assigned => Icons.person_pin_circle_outlined,
      RequestStage.onTheWay => Icons.directions_run,
      RequestStage.resolved => Icons.task_alt,
    };

IconData missionStageIcon(MissionStage s) => switch (s) {
      MissionStage.available => Icons.inventory_2_outlined,
      MissionStage.assigned => Icons.assignment_ind_outlined,
      MissionStage.inTransit => Icons.local_shipping_outlined,
      MissionStage.awaitingHandoff => Icons.swap_horiz,
      MissionStage.delivered => Icons.task_alt,
    };

/// Spec section 16: queued, propagating, delivered, read.
IconData deliveryIcon(DeliveryStatus s) => switch (s) {
      DeliveryStatus.queued => Icons.schedule,
      DeliveryStatus.propagating => Icons.north_east,
      DeliveryStatus.delivered => Icons.check,
      DeliveryStatus.read => Icons.done_all,
    };

Color channelHue(ChannelType t) => switch (t) {
      ChannelType.direct => Hues.communication,
      ChannelType.public => Hues.medical,
      ChannelType.community => Hues.communication,
      ChannelType.restricted => Hues.shelter,
      ChannelType.mission => Hues.transport,
    };

IconData channelIcon(ChannelType t) => switch (t) {
      ChannelType.direct => Icons.person_outline,
      ChannelType.public => Icons.campaign_outlined,
      ChannelType.community => Icons.groups_outlined,
      ChannelType.restricted => Icons.lock_outline,
      ChannelType.mission => Icons.local_shipping_outlined,
    };

IconData eventIcon(EventType t) => switch (t) {
      EventType.helpRequested => Icons.sos,
      EventType.helpCancelled => Icons.cancel_outlined,
      EventType.helpAccepted || EventType.missionAccepted => Icons.handshake_outlined,
      EventType.helpReleased || EventType.missionReleased => Icons.undo,
      EventType.helpOffered => Icons.volunteer_activism_outlined,
      EventType.offerWithdrawn => Icons.remove_circle_outline,
      EventType.resourceCreated => Icons.add_location_alt_outlined,
      EventType.resourceRemoved => Icons.wrong_location_outlined,
      EventType.resourceConfirmed => Icons.check_circle_outline,
      EventType.resourceDisputed => Icons.report_outlined,
      EventType.resourceUseful => Icons.thumb_up_outlined,
      EventType.voteWithdrawn => Icons.undo,
      EventType.contactAdded => Icons.person_add_outlined,
      EventType.contactRemoved => Icons.person_remove_outlined,
      EventType.messageSent => Icons.send_outlined,
      EventType.packagePickedUp => Icons.inventory_2_outlined,
      EventType.packageTransferred => Icons.swap_horiz,
      EventType.deliveryCompleted => Icons.task_alt,
    };
