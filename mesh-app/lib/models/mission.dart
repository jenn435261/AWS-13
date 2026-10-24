// Moving supplies: SUPPLY, REQUEST, MATCH, MISSION, PICKUP, TRANSPORT,
// HANDOFF, DELIVERY (Spec sections 19 to 30).

enum MissionStage { available, assigned, inTransit, awaitingHandoff, delivered }

enum Priority { high, normal, low }

class Mission {
  const Mission({
    required this.id,
    required this.item,
    required this.quantity,
    required this.pickup,
    required this.pickupExact,
    required this.destination,
    required this.destinationExact,
    required this.packageId,
    required this.priority,
    this.stage = MissionStage.available,
    this.carrier,
    this.carrierIsMe = false,
    this.handedOff = false,
    this.stageTimes = const {},
  });

  final String id;
  final String item;
  final String quantity;

  /// Everyone sees the place name. The exact address is only for the
  /// carrier, who holds this mission's capability (Spec sections 23, 28).
  final String pickup;
  final String pickupExact;
  final String destination;
  final String destinationExact;

  final String packageId;
  final Priority priority;
  final MissionStage stage;
  final String? carrier;
  final bool carrierIsMe;

  /// This phone carried it and passed it to another driver.
  final bool handedOff;
  final Map<MissionStage, DateTime> stageTimes;

  /// The capability that unlocks the mission's details, e.g. MISSION_2193_DRIVER.
  String get driverCapability => 'MISSION_${id}_DRIVER';

  Mission copyWith({
    MissionStage? stage,
    String? carrier,
    bool? carrierIsMe,
    bool? handedOff,
  }) =>
      Mission(
        id: id,
        item: item,
        quantity: quantity,
        pickup: pickup,
        pickupExact: pickupExact,
        destination: destination,
        destinationExact: destinationExact,
        packageId: packageId,
        priority: priority,
        stage: stage ?? this.stage,
        carrier: carrier ?? this.carrier,
        carrierIsMe: carrierIsMe ?? this.carrierIsMe,
        handedOff: handedOff ?? this.handedOff,
        stageTimes: stage == null || stage == this.stage
            ? stageTimes
            : {...stageTimes, stage: DateTime.now()},
      );
}
