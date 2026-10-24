import 'package:intl/intl.dart' show NumberFormat;

import '../models/event.dart';
import '../models/help.dart';
import '../models/mesh_message.dart';
import '../models/mission.dart';
import '../models/resource.dart';
import '../models/role.dart';
import '../models/social.dart';
import '../state/drafts.dart';
import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';

/// Words for the app's fixed choices, in one place for every language.
extension Labels on AppLocalizations {
  String helpKind(HelpKind k) => switch (k) {
        HelpKind.water => kindWater,
        HelpKind.food => kindFood,
        HelpKind.medicine => kindMedicine,
        HelpKind.shelter => kindShelter,
        HelpKind.power => kindPower,
        HelpKind.transportation => kindTransportation,
        HelpKind.medical => kindMedical,
        HelpKind.communication => kindCommunication,
        HelpKind.other => kindOther,
      };

  String helpKindSub(HelpKind k) => switch (k) {
        HelpKind.water => kindWaterSub,
        HelpKind.food => kindFoodSub,
        HelpKind.medicine => kindMedicineSub,
        HelpKind.shelter => kindShelterSub,
        HelpKind.power => kindPowerSub,
        HelpKind.transportation => kindTransportationSub,
        HelpKind.medical => kindMedicalSub,
        HelpKind.communication => kindCommunicationSub,
        HelpKind.other => kindOtherSub,
      };

  String requestTitle(HelpRequest r) => r.sos ? kindSos : helpKind(r.kind);

  String urgency(Urgency u) => switch (u) {
        Urgency.now => urgencyNow,
        Urgency.soon => urgencySoon,
        Urgency.later => urgencyLater,
      };

  String urgencySub(Urgency u) => switch (u) {
        Urgency.now => urgencyNowSub,
        Urgency.soon => urgencySoonSub,
        Urgency.later => urgencyLaterSub,
      };

  String supply(SupplyKind k) => switch (k) {
        SupplyKind.water => supplyWater,
        SupplyKind.food => supplyFood,
        SupplyKind.blankets => supplyBlankets,
        SupplyKind.batteries => supplyBatteries,
        SupplyKind.charging => supplyCharging,
        SupplyKind.medicine => supplyMedicine,
        SupplyKind.transportation => supplyTransportation,
        SupplyKind.shelter => supplyShelter,
        SupplyKind.tools => supplyTools,
        SupplyKind.other => supplyOther,
      };

  String supplies(Iterable<SupplyKind> kinds) =>
      [for (final k in SupplyKind.values) if (kinds.contains(k)) supply(k)]
          .join(', ');

  String amount(Amount a) => switch (a) {
        Amount.plenty => amountPlenty,
        Amount.some => amountSome,
        Amount.low => amountLow,
      };

  String availability(Availability a) => switch (a) {
        Availability.now => availabilityNow,
        Availability.today => availabilityToday,
        Availability.custom => availabilityCustom,
      };

  String transport(TransportMode t) => switch (t) {
        TransportMode.walking => transportWalking,
        TransportMode.bicycle => transportBicycle,
        TransportMode.car => transportCar,
        TransportMode.truck => transportTruck,
        TransportMode.van => transportVan,
      };

  String capacity(Capacity c) => switch (c) {
        Capacity.small => capacitySmall,
        Capacity.medium => capacityMedium,
        Capacity.large => capacityLarge,
      };

  String resourceKind(ResourceKind k) => switch (k) {
        ResourceKind.hospital => resHospital,
        ResourceKind.pharmacy => resPharmacy,
        ResourceKind.police => resPolice,
        ResourceKind.fire => resFire,
        ResourceKind.water => resWater,
        ResourceKind.food => resFood,
        ResourceKind.shelter => resShelter,
        ResourceKind.charging => resCharging,
        ResourceKind.transportation => resTransportation,
        ResourceKind.roadProblem => resRoadProblem,
      };

  /// Community resources added from the map have no name of their own.
  String resourceTitle(Resource r) =>
      r.name.isEmpty ? resourceKind(r.kind) : r.name;

  String confidence(Confidence c) => switch (c) {
        Confidence.unconfirmed => unconfirmed,
        Confidence.low => confidenceLow,
        Confidence.medium => confidenceMedium,
        Confidence.high => confidenceHigh,
      };

  /// One line for a resource: who says so, and how many agree.
  String provenance(Resource r) => [
        r.verified ? verifiedOrg : communityResource,
        if (r.confirmations == 0 && !r.verified) oneReport
        else confirmationsCount(r.confirmations),
      ].join('  ·  ');

  /// Someone else's request was saved on their phone, not this one.
  String stage(RequestStage s, {bool mine = true}) => switch (s) {
        RequestStage.saved => mine ? stageSaved : stageSavedTheirs,
        RequestStage.mesh => stageMesh,
        RequestStage.verified => stageVerified,
        RequestStage.assigned => stageAssigned,
        RequestStage.onTheWay => stageOnTheWay,
        RequestStage.resolved => stageResolved,
      };

  String stageDetail(RequestStage s, HelpRequest r) => switch (s) {
        RequestStage.saved => r.mine ? stageSavedSub : stageSavedTheirsSub,
        RequestStage.mesh => stageMeshSub(r.hops),
        RequestStage.verified => stageVerifiedSub,
        RequestStage.assigned => stageAssignedSub(r.helperName ?? ''),
        RequestStage.onTheWay => stageOnTheWaySub(r.helperName ?? ''),
        RequestStage.resolved => stageResolvedSub,
      };

  String missionStage(MissionStage s) => switch (s) {
        MissionStage.available => mStageAvailable,
        MissionStage.assigned => mStageAssigned,
        MissionStage.inTransit => mStageInTransit,
        MissionStage.awaitingHandoff => mStageHandoff,
        MissionStage.delivered => mStageDelivered,
      };

  String priority(Priority p) => switch (p) {
        Priority.high => priorityHigh,
        Priority.normal => priorityNormal,
        Priority.low => priorityLow,
      };

  String channelType(ChannelType t) => switch (t) {
        ChannelType.direct => channelDirect,
        ChannelType.public => channelPublic,
        ChannelType.community => channelCommunity,
        ChannelType.restricted => channelRestricted,
        ChannelType.mission => channelMission,
      };

  String contactSource(Contact c) => c.verifiedOrganization
      ? verifiedOrg
      : switch (c.source) {
          ContactSource.qr => metInPerson,
          ContactSource.username => addedByUsername,
          ContactSource.phone => addedByPhone,
          ContactSource.directory => verifiedOrg,
        };

  String event(EventType t) => switch (t) {
        EventType.helpRequested => evHelpRequested,
        EventType.helpCancelled => evHelpCancelled,
        EventType.helpAccepted => evHelpAccepted,
        EventType.helpReleased => evHelpReleased,
        EventType.helpOffered => evHelpOffered,
        EventType.offerWithdrawn => evOfferWithdrawn,
        EventType.resourceCreated => evResourceCreated,
        EventType.resourceRemoved => evResourceRemoved,
        EventType.resourceConfirmed => evResourceConfirmed,
        EventType.resourceDisputed => evResourceDisputed,
        EventType.resourceUseful => evResourceUseful,
        EventType.voteWithdrawn => evVoteWithdrawn,
        EventType.contactAdded => evContactAdded,
        EventType.contactRemoved => evContactRemoved,
        EventType.messageSent => evMessageSent,
        EventType.missionAccepted => evMissionAccepted,
        EventType.missionReleased => evMissionReleased,
        EventType.packagePickedUp => evPackagePickedUp,
        EventType.packageTransferred => evPackageTransferred,
        EventType.deliveryCompleted => evDeliveryCompleted,
      };

  String role(Role r) => switch (r) {
        Role.client => roleClient,
        Role.manager => roleManager,
        Role.admin => roleAdmin,
      };

  String delivery(DeliveryStatus s) => switch (s) {
        DeliveryStatus.queued => deliveryQueued,
        DeliveryStatus.propagating => deliveryPropagating,
        DeliveryStatus.delivered => deliveryDelivered,
        DeliveryStatus.read => deliveryRead,
      };

  String problem(DraftProblem p) => switch (p) {
        DraftProblem.missingKind => problemMissingKind,
        DraftProblem.peopleOutOfRange => problemPeople(maxPeople),
        DraftProblem.noteTooLong => problemNoteTooLong(maxNoteLength),
        DraftProblem.missingLocation => problemLocation,
        DraftProblem.missingSupplies => problemSupplies,
        DraftProblem.missingTransport => problemTransport,
      };

  String timeAgo(DateTime time, {DateTime? now}) {
    final d = (now ?? DateTime.now()).difference(time);
    if (d.inSeconds < 60) return justNow;
    if (d.inMinutes < 60) return minutesAgo(d.inMinutes);
    if (d.inHours < 24) return hoursAgo(d.inHours);
    return daysAgo(d.inDays);
  }

  String distance(double meters) => meters < 1000
      ? distanceMeters(((meters / 10).round() * 10).clamp(10, 990))
      : distanceKm(NumberFormat('0.0', localeName).format(meters / 1000));
}
