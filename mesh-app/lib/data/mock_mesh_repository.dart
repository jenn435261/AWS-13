import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/app_user.dart';
import '../models/event.dart';
import '../models/help.dart';
import '../models/mesh_message.dart';
import '../models/mesh_node.dart';
import '../models/mission.dart';
import '../models/network.dart';
import '../models/resource.dart';
import '../models/role.dart';
import '../models/social.dart';
import '../state/drafts.dart';
import '../state/identity.dart';
import 'demo_area.dart';
import 'mesh_repository.dart';

/// Demo network for building the UI before the transports exist. It plays
/// the other phones, the mesh and the cloud: they, not the screens, decide
/// when something moves to its next stage.
class MockMeshRepository implements MeshRepository {
  MockMeshRepository({
    required this.identity,
    this.simulateTraffic = true,
    this.loadDelay = const Duration(milliseconds: 900),
    this.stageDelay = const Duration(seconds: 1),
  }) {
    _missions.addListener(_updateSharing);
    _load();
    if (simulateTraffic) {
      _timer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
    }
  }

  @override
  final Identity identity;

  final bool simulateTraffic;

  /// How long the first load takes, to show the skeleton loaders.
  final Duration loadDelay;

  /// Base unit for how fast things move through their stages.
  final Duration stageDelay;

  final _loading = ValueNotifier(true);
  final _network = ValueNotifier(_offlineStart());
  final _location = ValueNotifier<LocationFix?>(null);
  final _sharingLocation = ValueNotifier(false);
  final _nodes = ValueNotifier<List<MeshNode>>(const []);
  final _users = ValueNotifier<List<AppUser>>(const []);
  final _requests = ValueNotifier<List<HelpRequest>>(const []);
  final _resources = ValueNotifier<List<Resource>>(const []);
  final _alerts = ValueNotifier<List<EmergencyAlert>>(const []);
  final _offer = ValueNotifier<HelpOffer?>(null);
  final _contacts = ValueNotifier<List<Contact>>(const []);
  final _organizations = ValueNotifier<List<TrustedOrganization>>(const []);
  final _channels = ValueNotifier<List<Channel>>(const []);
  final _messages = ValueNotifier<List<MeshMessage>>(const []);
  final _missions = ValueNotifier<List<Mission>>(const []);
  final _events = ValueNotifier<List<SignedEvent>>(const []);
  final _readiness = ValueNotifier(_packageStart());
  final _notices = StreamController<MeshNotice>.broadcast();

  /// Pending changes per item, so cancel and wipe can stop them.
  final _timers = <String, List<Timer>>{};
  final _random = Random();
  Timer? _timer;
  int _seq = 0;
  bool _disposed = false;

  @override
  ValueListenable<bool> get loading => _loading;
  @override
  ValueListenable<NetworkStatus> get network => _network;
  @override
  ValueListenable<LocationFix?> get location => _location;

  @override
  ValueListenable<bool> get sharingLocation => _sharingLocation;
  @override
  ValueListenable<List<MeshNode>> get nodes => _nodes;
  @override
  ValueListenable<List<AppUser>> get users => _users;
  @override
  ValueListenable<List<HelpRequest>> get requests => _requests;
  @override
  ValueListenable<List<Resource>> get resources => _resources;
  @override
  ValueListenable<List<EmergencyAlert>> get alerts => _alerts;
  @override
  ValueListenable<HelpOffer?> get offer => _offer;
  @override
  ValueListenable<List<Contact>> get contacts => _contacts;
  @override
  ValueListenable<List<TrustedOrganization>> get organizations =>
      _organizations;
  @override
  ValueListenable<List<Channel>> get channels => _channels;
  @override
  ValueListenable<List<MeshMessage>> get messages => _messages;
  @override
  ValueListenable<List<Mission>> get missions => _missions;
  @override
  ValueListenable<List<SignedEvent>> get events => _events;
  @override
  ValueListenable<ReadinessPackage> get readiness => _readiness;
  @override
  Stream<MeshNotice> get notices => _notices.stream;

  static DateTime _ago(Duration d) => DateTime.now().subtract(d);

  static NetworkStatus _offlineStart() => NetworkStatus(
        internet: false,
        peers: 3,
        node: true,
        lora: true,
        gatewayOnline: true,
        lastSync: _ago(const Duration(minutes: 18)),
        lastGlobalSync: _ago(const Duration(hours: 2, minutes: 18)),
      );

  static ReadinessPackage _packageStart() => ReadinessPackage(
        region: 'San Jose',
        sizeMb: 47,
        version: 52,
        publishedAt: _ago(const Duration(hours: 3)),
        downloadedVersion: 51,
        downloadedAt: _ago(const Duration(days: 6)),
      );

  LatLng _at(double north, double east) =>
      offsetMeters(demoCenter, north, east);

  bool get _hasRoute => _network.value.hasRoute;

  /// Loads every kind of data at the same time, never one after another.
  Future<void> _load() async {
    _loading.value = true;
    await Future.wait([
      _after(0.4, _seedLocation),
      _after(0.6, _seedNodes),
      _after(0.8, _seedResources),
      _after(1.0, _seedRequests),
      _after(0.5, _seedSocial),
      _after(0.7, _seedMissions),
      _after(0.3, _seedUsers),
    ]);
    if (!_disposed) _loading.value = false;
  }

  Future<void> _after(double fraction, VoidCallback seed) async {
    await Future<void>.delayed(loadDelay * fraction);
    if (!_disposed) seed();
  }

  void _seedLocation() => _location.value =
      LocationFix(_at(-90, -60), 25, source: LocationSource.demo);

  void _seedNodes() {
    final now = DateTime.now();
    _nodes.value = [
      MeshNode(
        id: '!a1b2',
        name: 'Library Resilience Node',
        lastHeard: now,
        rssi: -62,
        snr: 9.5,
        location: _at(60, -40),
      ),
      MeshNode(
        id: '!c3d4',
        name: 'Ridge Relay',
        lastHeard: now.subtract(const Duration(minutes: 3)),
        battery: 81,
        rssi: -97,
        snr: 4.25,
        hops: 1,
        location: _at(-380, 520),
      ),
      MeshNode(
        id: '!e5f6',
        name: 'Field Unit 1',
        lastHeard: now.subtract(const Duration(minutes: 9)),
        battery: 54,
        rssi: -110,
        snr: -2.0,
        hops: 2,
        location: _at(420, -300),
      ),
      MeshNode(
        id: '!0789',
        name: 'Field Unit 2',
        lastHeard: now.subtract(const Duration(hours: 2)),
        battery: 12,
        rssi: -118,
        snr: -7.5,
        hops: 3,
        location: _at(-520, -480),
      ),
    ];
  }

  void _seedResources() {
    Duration m(int minutes) => Duration(minutes: minutes);
    _resources.value = [
      Resource(
        id: 'f1',
        kind: ResourceKind.hospital,
        name: 'Valley Medical Center',
        location: _at(-430, 620),
        organization: 'Santa Clara Valley Healthcare',
        officialUpdate: _ago(m(35)),
        confirmations: 7,
        lastObserved: _ago(m(12)),
        approximate: false,
      ),
      Resource(
        id: 'f2',
        kind: ResourceKind.pharmacy,
        name: 'Campus Pharmacy',
        location: _at(130, 160),
        organization: 'SJSU Student Health',
        officialUpdate: _ago(m(47)),
        confirmations: 12,
        lastObserved: _ago(m(3)),
        approximate: false,
      ),
      Resource(
        id: 'f3',
        kind: ResourceKind.police,
        name: 'University Police',
        location: _at(-250, -200),
        organization: 'SJSU Police Department',
        officialUpdate: _ago(m(90)),
        lastObserved: _ago(m(90)),
        approximate: false,
      ),
      Resource(
        id: 'f4',
        kind: ResourceKind.fire,
        name: 'Fire Station 1',
        location: _at(330, 480),
        organization: 'San Jose Fire Department',
        officialUpdate: _ago(m(120)),
        lastObserved: _ago(m(120)),
        approximate: false,
      ),
      Resource(
        id: 'w1',
        kind: ResourceKind.water,
        name: 'Water Station 2',
        location: _at(210, -260),
        organization: 'City of San Jose',
        officialUpdate: _ago(m(52)),
        officialStock: 50,
        reserved: 20,
        reservedFor: '2193',
        observations: [
          Observation('Low', _ago(m(14))),
          Observation('Almost empty', _ago(m(8))),
        ],
        confirmations: 18,
        disputes: 1,
        useful: 9,
        lastObserved: _ago(m(4)),
        approximate: false,
      ),
      Resource(
        id: 's1',
        kind: ResourceKind.shelter,
        name: 'Event Center Shelter',
        location: _at(-250, 330),
        organization: 'American Red Cross',
        officialUpdate: _ago(m(25)),
        confirmations: 22,
        useful: 14,
        lastObserved: _ago(m(6)),
        approximate: false,
      ),
      Resource(
        id: 'c1',
        kind: ResourceKind.charging,
        name: 'Library charging table',
        location: _at(150, -120),
        confirmations: 6,
        useful: 4,
        lastObserved: _ago(m(20)),
      ),
      Resource(
        id: 'c2',
        kind: ResourceKind.charging,
        name: 'Generator charging',
        location: _at(-380, -160),
        confirmations: 2,
        lastObserved: _ago(const Duration(hours: 9)),
      ),
      Resource(
        id: 'd1',
        kind: ResourceKind.food,
        name: 'Hot meals',
        location: _at(-60, 260),
        confirmations: 3,
        useful: 2,
        lastObserved: _ago(m(55)),
      ),
      Resource(
        id: 'x1',
        kind: ResourceKind.roadProblem,
        name: 'Possible road obstruction',
        location: _at(330, 60),
        lastObserved: _ago(m(2)),
        note: 'Fallen tree across the road.',
      ),
    ];
    _alerts.value = [
      EmergencyAlert(
        id: 'a1',
        title: 'Boil water notice',
        body: 'Boil tap water for 1 minute before drinking in zones 3 and 4.',
        organization: 'City of San Jose',
        at: _ago(m(25)),
        urgent: true,
      ),
      EmergencyAlert(
        id: 'a2',
        title: 'Shelter open',
        body: 'Event Center Shelter is open with 120 beds.',
        organization: 'American Red Cross',
        at: _ago(const Duration(hours: 1)),
      ),
    ];
  }

  void _seedRequests() {
    final now = DateTime.now();
    HelpRequest other(
      String id,
      HelpKind kind,
      Urgency urgency,
      int people,
      String name,
      int minutesAgo,
      LatLng location, {
      RequestStage stage = RequestStage.verified,
      int hops = 1,
      String note = '',
    }) {
      final created = now.subtract(Duration(minutes: minutesAgo));
      return HelpRequest(
        id: id,
        kind: kind,
        urgency: urgency,
        people: people,
        createdAt: created,
        senderName: name,
        location: location,
        note: note,
        stage: stage,
        hops: hops,
        stageTimes: {
          for (final s in RequestStage.values.take(stage.index + 1)) s: created,
        },
      );
    }

    _requests.value = [
      other('r3', HelpKind.medical, Urgency.now, 1, 'Ana', 2, _at(-460, 90),
          stage: RequestStage.mesh, hops: 3, note: 'Leg stuck under a shelf.'),
      other('r1', HelpKind.medicine, Urgency.soon, 1, 'Maria', 6,
          _at(60, 300),
          note: 'Need somewhere refrigerated for insulin for one person.'),
      other('r4', HelpKind.power, Urgency.later, 1, 'Sam', 11, _at(260, 30)),
      other('r2', HelpKind.water, Urgency.soon, 5, 'Duc', 18, _at(-20, -330)),
    ];
  }

  void _seedSocial() {
    Contact person(String id, String name, ContactSource source) =>
        Contact(id: id, name: name, kind: ContactKind.person, source: source);
    Contact org(String id, String name) => Contact(
          id: id,
          name: name,
          kind: ContactKind.organization,
          source: ContactSource.directory,
          verifiedOrganization: true,
        );
    _contacts.value = [
      person('3a9e41c07b22d5f8', 'Maria', ContactSource.qr),
      person('8fd19a2c44e1b703', 'Jordan', ContactSource.qr),
      person('c51d07e9a3f26b48', 'Duc', ContactSource.username),
      org('0be4c9d2716a5f30', 'City of San Jose'),
      org('6d2f8a1e0c93b574', 'American Red Cross'),
      org('e7a3105bd8c42f96', 'Santa Clara Valley Healthcare'),
    ];

    const oes = "California Governor's Office of Emergency Services";
    final checked = _ago(const Duration(hours: 2));
    TrustedOrganization trusted(String name, String category, String by) =>
        TrustedOrganization(
          name: name,
          category: category,
          certifiedBy: by,
          checkedAt: checked,
        );
    _organizations.value = [
      trusted(oes, 'Government', 'Root'),
      trusted('City of San Jose', 'Government', oes),
      trusted('San Jose Fire Department', 'Government', 'City of San Jose'),
      trusted('SJSU Police Department', 'Government', 'City of San Jose'),
      trusted('Santa Clara Valley Healthcare', 'Hospital', 'Root'),
      trusted('SJSU Student Health', 'Pharmacy', 'Santa Clara Valley Healthcare'),
      trusted('American Red Cross', 'Response organization', 'Root'),
    ];

    _channels.value = const [
      Channel(id: 'dm-maria', name: 'Maria', type: ChannelType.direct),
      Channel(id: 'dm-jordan', name: 'Jordan', type: ChannelType.direct),
      Channel(
        id: 'emergency-alerts',
        name: 'emergency-alerts',
        type: ChannelType.public,
        readOnly: true,
      ),
      Channel(id: 'water', name: 'water', type: ChannelType.public),
      Channel(id: 'roads', name: 'roads', type: ChannelType.public),
      Channel(
        id: 'neighborhood',
        name: 'neighborhood',
        type: ChannelType.community,
      ),
      Channel(
        id: 'shelter-community',
        name: 'shelter-community',
        type: ChannelType.community,
      ),
      Channel(
        id: 'shelter-staff',
        name: 'shelter-staff',
        type: ChannelType.restricted,
      ),
    ];

    MeshMessage msg(
      String channel,
      String from,
      String text,
      int minutesAgo, {
      bool mine = false,
    }) =>
        MeshMessage(
          id: 'seed${_seq++}',
          channelId: channel,
          senderId: mine ? identity.resilienceId : from,
          senderName: from,
          text: text,
          timestamp: _ago(Duration(minutes: minutesAgo)),
          status: mine ? DeliveryStatus.read : DeliveryStatus.delivered,
        );
    _messages.value = [
      msg('emergency-alerts', 'City of San Jose',
          'Boil water notice for zones 3 and 4. Boil tap water for 1 minute before drinking.', 25),
      msg('water', 'Duc', 'Water Station 2 is running low. Bring your own jugs.', 14),
      msg('roads', 'Ana', 'Tree down near the north avenue. Go around by the park.', 3),
      msg('neighborhood', 'Jordan', 'Checking on the seniors on our block at 3.', 40),
      msg('shelter-community', 'American Red Cross',
          'Volunteers needed for the evening meal shift.', 60),
      msg('shelter-staff', 'American Red Cross',
          'Insulin cooler arrives with Mission 2195.', 90),
      msg('dm-maria', 'Maria', 'Are you still near the library?', 12),
      msg('dm-maria', 'Guest', 'Yes, by the charging table.', 10, mine: true),
      msg('dm-jordan', 'Jordan', 'I have room in my car for 3.', 30),
    ];
  }

  void _seedMissions() {
    _missions.value = [
      const Mission(
        id: '2193',
        item: 'Water',
        quantity: '20 cases',
        pickup: 'Community Center',
        pickupExact: '1250 Example Avenue, loading dock',
        destination: 'Shelter 18',
        destinationExact: '742 Example Street, rear entrance',
        packageId: '8192',
        priority: Priority.high,
      ),
      const Mission(
        id: '2196',
        item: 'Blankets',
        quantity: '40',
        pickup: 'Red Cross depot',
        pickupExact: '88 Example Road, door 2',
        destination: 'Event Center Shelter',
        destinationExact: '290 Example Plaza, side entrance',
        packageId: '8204',
        priority: Priority.normal,
      ),
    ];
  }

  void _seedUsers() {
    _users.value = const [
      AppUser(id: 'u1', name: 'Avery', role: Role.admin),
      AppUser(id: 'u2', name: 'Jordan', role: Role.manager),
      AppUser(id: 'u3', name: 'Sam', role: Role.client),
      AppUser(id: 'u4', name: 'Riley', role: Role.client),
    ];
  }

  /// Signs and stores an event. Every change on this phone goes through here.
  Future<void> _record(EventType type, String subject) async {
    final event = await identity.sign('e${_seq++}', type, subject);
    if (_disposed) return;
    _events.value = [event, ..._events.value];
  }

  void _later(String key, double units, VoidCallback run) {
    final timer = Timer(stageDelay * units, () {
      if (!_disposed) run();
    });
    (_timers[key] ??= []).add(timer);
  }

  void _stop(String key) {
    for (final t in _timers.remove(key) ?? const <Timer>[]) {
      t.cancel();
    }
  }

  /// A radio checks in, and now and then someone nearby asks for help.
  void _tick() {
    final remote = _nodes.value.where((n) => n.enabled && n.hops > 0).toList();
    if (remote.isEmpty) return;
    final node = remote[_random.nextInt(remote.length)];
    final now = DateTime.now();

    _nodes.value = [
      for (final n in _nodes.value)
        n.id == node.id
            ? n.copyWith(lastHeard: now, rssi: -90 - _random.nextInt(30))
            : n,
    ];
    _network.value = _network.value.copyWith(lastSync: now);

    final openNearby = _requests.value.where((r) => !r.mine && r.isOpen);
    if (openNearby.length < 6 && _random.nextDouble() < 0.2) {
      final request = HelpRequest(
        id: 'n${_seq++}',
        kind: HelpKind.values[_random.nextInt(HelpKind.values.length)],
        urgency: Urgency.values[_random.nextInt(Urgency.values.length)],
        people: 1 + _random.nextInt(4),
        createdAt: now,
        senderName: node.name,
        location: _at(
          _random.nextDouble() * 800 - 400,
          _random.nextDouble() * 800 - 400,
        ),
        stage: RequestStage.verified,
        hops: node.hops,
        stageTimes: {for (final s in RequestStage.values.take(3)) s: now},
      );
      _requests.value = [request, ..._requests.value];
      _notices.add(NearbyRequestNotice(request));
    }
  }

  /// Location leaves the phone only while it carries a delivery.
  void _updateSharing() => _sharingLocation.value = _missions.value.any(
        (m) =>
            m.carrierIsMe &&
            m.stage != MissionStage.available &&
            m.stage != MissionStage.delivered,
      );

  @override
  Future<void> setManualLocation(LatLng point, {String label = ''}) async {
    _location.value = LocationFix(
      point,
      50,
      source: LocationSource.manual,
      label: label.trim(),
    );
  }

  /// Lets tests start from any mix of routes, e.g. no route at all.
  @visibleForTesting
  void debugSetNetwork(NetworkStatus status) => _network.value = status;

  @override
  void setInternet(bool on) {
    _network.value = _network.value.copyWith(internet: on);
  }

  @override
  Future<void> sendMessage(
    String channelId,
    String text, {
    required AppUser from,
  }) async {
    final message = MeshMessage(
      id: 'out${_seq++}',
      channelId: channelId,
      senderId: identity.resilienceId,
      senderName: from.name,
      text: text,
      timestamp: DateTime.now(),
      status: DeliveryStatus.queued,
    );
    _messages.value = [..._messages.value, message];
    await _record(EventType.messageSent, message.id);
    if (!_hasRoute) return;

    void set(DeliveryStatus s) => _messages.value = [
          for (final m in _messages.value)
            m.id == message.id ? m.copyWith(status: s) : m,
        ];
    _later(message.id, 0.8, () => set(DeliveryStatus.propagating));
    _later(message.id, 2.5, () => set(DeliveryStatus.delivered));
    if (channelId.startsWith('dm-')) {
      _later(message.id, 5, () => set(DeliveryStatus.read));
    }
  }

  @override
  Future<HelpRequest> submitRequest(
    RequestDraft draft, {
    required AppUser from,
  }) async {
    final fix = _location.value;
    final problems = draft.problems(hasLocation: fix != null);
    if (problems.isNotEmpty) throw DraftRejected(problems);

    return _queue(HelpRequest(
      id: 'req${_seq++}',
      kind: draft.kind!,
      urgency: draft.urgency,
      people: draft.people,
      createdAt: DateTime.now(),
      senderName: from.name,
      location: fix?.point,
      locationNote: draft.locationNote.trim(),
      note: draft.note.trim(),
      mine: true,
      stageTimes: {RequestStage.saved: DateTime.now()},
    ));
  }

  @override
  Future<HelpRequest> sendSos({required AppUser from}) => _queue(
        HelpRequest(
          id: 'sos${_seq++}',
          kind: HelpKind.medical,
          urgency: Urgency.now,
          people: 1,
          createdAt: DateTime.now(),
          senderName: from.name,
          location: _location.value?.point,
          mine: true,
          sos: true,
          stageTimes: {RequestStage.saved: DateTime.now()},
        ),
      );

  /// Saved and shown at once, signed, then handed to the network.
  Future<HelpRequest> _queue(HelpRequest request) async {
    _requests.value = [request, ..._requests.value];
    await _record(EventType.helpRequested, request.id);
    _scheduleStages(request);
    return request;
  }

  /// Plays the mesh and the server: moves a request through its stages.
  void _scheduleStages(HelpRequest request) {
    if (!_hasRoute) return;
    final gateway = _network.value.gatewayOnline;
    final steps = <(RequestStage, double, String?)>[
      (RequestStage.mesh, 2.5, null),
      if (gateway) (RequestStage.verified, 4.5, null),
      if (gateway) (RequestStage.assigned, 8, 'Jordan'),
      if (gateway) (RequestStage.onTheWay, 14, 'Jordan'),
    ].where((s) => s.$1.index > request.stage.index);

    for (final (stage, at, helper) in steps) {
      _later(request.id, at, () => _advance(request.id, stage, helper));
    }
  }

  void _advance(String id, RequestStage stage, String? helper) {
    final index = _requests.value.indexWhere((r) => r.id == id);
    if (index < 0) return;
    final moved = _requests.value[index].advance(
      stage,
      hops: stage == RequestStage.mesh ? 2 : null,
      helperName: helper,
    );
    _requests.value = [..._requests.value]..[index] = moved;
    if (stage == RequestStage.assigned) _notices.add(HelperFoundNotice(moved));
  }

  @override
  Future<void> cancelRequest(String id) async {
    _stop(id);
    _requests.value = [
      for (final r in _requests.value)
        if (r.id != id) r,
    ];
    await _record(EventType.helpCancelled, id);
  }

  @override
  Future<void> restoreRequest(HelpRequest request) async {
    if (_requests.value.any((r) => r.id == request.id)) return;
    _requests.value = [request, ..._requests.value];
    await _record(EventType.helpRequested, request.id);
    if (request.mine) _scheduleStages(request);
  }

  @override
  Future<void> acceptRequest(String id, {required AppUser helper}) async {
    _requests.value = [
      for (final r in _requests.value)
        r.id == id && r.isOpen ? r.acceptedByMe(helper.name) : r,
    ];
    await _record(EventType.helpAccepted, id);
  }

  @override
  Future<void> releaseRequest(String id) async {
    _requests.value = [
      for (final r in _requests.value)
        r.id == id && r.helpingIsMe ? r.released() : r,
    ];
    await _record(EventType.helpReleased, id);
  }

  @override
  Future<void> setOffer(HelpOffer? offer) async {
    _offer.value = offer;
    await _record(
      offer == null ? EventType.offerWithdrawn : EventType.helpOffered,
      'offer',
    );
  }

  @override
  Future<Resource> addResource(
    ResourceKind kind,
    LatLng point, {
    String note = '',
  }) async {
    final resource = Resource(
      id: 'res${_seq++}',
      kind: kind,
      name: '',
      location: point,
      lastObserved: DateTime.now(),
      mine: true,
      note: note.trim(),
    );
    _resources.value = [..._resources.value, resource];
    await _record(EventType.resourceCreated, resource.id);
    return resource;
  }

  @override
  Future<void> removeResource(String id) async {
    _resources.value = [
      for (final r in _resources.value)
        if (r.id != id) r,
    ];
    await _record(EventType.resourceRemoved, id);
  }

  @override
  Future<void> vote(String resourceId, Vote? vote) async {
    _resources.value = [
      for (final r in _resources.value)
        r.id == resourceId ? r.withVote(vote) : r,
    ];
    await _record(
      switch (vote) {
        Vote.useful => EventType.resourceUseful,
        Vote.confirm => EventType.resourceConfirmed,
        Vote.dispute => EventType.resourceDisputed,
        null => EventType.voteWithdrawn,
      },
      resourceId,
    );
  }

  @override
  Future<void> restoreVote(Resource before) async {
    _resources.value = [
      for (final r in _resources.value) r.id == before.id ? before : r,
    ];
    await _record(
      switch (before.myVote) {
        Vote.useful => EventType.resourceUseful,
        Vote.confirm => EventType.resourceConfirmed,
        Vote.dispute => EventType.resourceDisputed,
        null => EventType.voteWithdrawn,
      },
      before.id,
    );
  }

  @override
  Future<Contact> addContact(String resilienceId, String name) async {
    final existing = _contacts.value.where((c) => c.id == resilienceId);
    if (existing.isNotEmpty) return existing.first;
    final contact = Contact(
      id: resilienceId,
      name: name,
      kind: ContactKind.person,
      source: ContactSource.qr,
    );
    _contacts.value = [..._contacts.value, contact];
    await _record(EventType.contactAdded, resilienceId);
    return contact;
  }

  /// The online directory: usernames and phone numbers map to public
  /// identities. The phone number is never the identity itself.
  static const _directory = {
    'riley': ('2c7e9b04f1a6d358', 'Riley'),
    'sam': ('91f04ab7c2e85d63', 'Sam'),
    '4085550123': ('2c7e9b04f1a6d358', 'Riley'),
  };

  @override
  Future<Contact?> findContact({String? username, String? phone}) async {
    if (!_network.value.internet) throw const NeedsInternet();
    final key = username != null
        ? username.trim().toLowerCase().replaceFirst('@', '')
        : phone!
            .replaceAll(RegExp(r'\D'), '')
            .replaceFirst(RegExp(r'^1(?=\d{10}$)'), '');
    final match = _directory[key];
    if (match == null) return null;
    final contact = Contact(
      id: match.$1,
      name: match.$2,
      kind: ContactKind.person,
      source: username != null ? ContactSource.username : ContactSource.phone,
    );
    if (!_contacts.value.any((c) => c.id == contact.id)) {
      _contacts.value = [..._contacts.value, contact];
      await _record(EventType.contactAdded, contact.id);
    }
    return contact;
  }

  @override
  Future<void> removeContact(String id) async {
    final index = _contacts.value.indexWhere((c) => c.id == id);
    if (index >= 0) _removedContactAt[id] = index;
    _contacts.value = [
      for (final c in _contacts.value)
        if (c.id != id) c,
    ];
    await _record(EventType.contactRemoved, id);
  }

  /// Where each removed contact was, so Undo puts it back in the same place.
  final _removedContactAt = <String, int>{};

  @override
  Future<void> restoreContact(Contact contact) async {
    if (_contacts.value.any((c) => c.id == contact.id)) return;
    final list = [..._contacts.value];
    final at = (_removedContactAt.remove(contact.id) ?? list.length)
        .clamp(0, list.length);
    _contacts.value = list..insert(at, contact);
    await _record(EventType.contactAdded, contact.id);
  }

  void _setMission(String id, Mission Function(Mission m) change) {
    _missions.value = [
      for (final m in _missions.value) m.id == id ? change(m) : m,
    ];
  }

  @override
  Future<void> acceptMission(String id, {required AppUser carrier}) async {
    _setMission(
      id,
      (m) => m.copyWith(
        stage: MissionStage.assigned,
        carrier: carrier.name,
        carrierIsMe: true,
      ),
    );
    if (!_channels.value.any((c) => c.id == 'mission-$id')) {
      _channels.value = [
        ..._channels.value,
        Channel(
          id: 'mission-$id',
          name: 'Delivery #$id',
          type: ChannelType.mission,
        ),
      ];
    }
    await _record(EventType.missionAccepted, id);
  }

  @override
  Future<void> releaseMission(String id) async {
    _stop('mission-$id');
    _setMission(
      id,
      (m) => Mission(
        id: m.id,
        item: m.item,
        quantity: m.quantity,
        pickup: m.pickup,
        pickupExact: m.pickupExact,
        destination: m.destination,
        destinationExact: m.destinationExact,
        packageId: m.packageId,
        priority: m.priority,
      ),
    );
    _channels.value = [
      for (final c in _channels.value)
        if (c.id != 'mission-$id') c,
    ];
    await _record(EventType.missionReleased, id);
  }

  @override
  Future<void> advanceMission(String id) async {
    final mission = _missions.value.firstWhere((m) => m.id == id);
    final (next, event) = switch (mission.stage) {
      MissionStage.assigned => (
          MissionStage.inTransit,
          EventType.packagePickedUp,
        ),
      MissionStage.inTransit => (
          MissionStage.delivered,
          EventType.deliveryCompleted,
        ),
      _ => (mission.stage, null),
    };
    if (event == null) return;
    _setMission(id, (m) => m.copyWith(stage: next));
    await _record(event, id);
  }

  @override
  Future<void> startHandoff(String id) async {
    _setMission(id, (m) => m.copyWith(stage: MissionStage.awaitingHandoff));
    // The next driver scans the package QR on their phone.
    _later('mission-$id', 4, () async {
      _setMission(
        id,
        (m) => m.copyWith(
          stage: MissionStage.inTransit,
          carrier: 'Riley',
          carrierIsMe: false,
          handedOff: true,
        ),
      );
      await _record(EventType.packageTransferred, id);
      _notices.add(
        HandoffConfirmedNotice(_missions.value.firstWhere((m) => m.id == id)),
      );
    });
  }

  @override
  Future<void> downloadReadiness() async {
    final n = _network.value;
    if (!n.internet && !n.node) throw const NeedsInternet();
    if (_readiness.value.downloading) return;
    _readiness.value = _readiness.value.copyWith(progress: 0);
    for (var i = 1; i <= 10; i++) {
      _later('readiness', i * 0.3, () {
        _readiness.value = i < 10
            ? _readiness.value.copyWith(progress: i / 10)
            : _readiness.value.copyWith(
                clearProgress: true,
                downloadedVersion: _readiness.value.version,
                downloadedAt: DateTime.now(),
              );
      });
    }
  }

  @override
  Future<int> clearCache() async {
    final finished =
        _requests.value.where((r) => r.stage == RequestStage.resolved).length;
    // Messages still on their way are not cache: keep them until delivered.
    bool unsent(MeshMessage m) =>
        m.senderId == identity.resilienceId &&
        m.status.index < DeliveryStatus.delivered.index;
    final kept = [for (final m in _messages.value) if (unsent(m)) m];
    final count = _messages.value.length - kept.length + finished;
    _messages.value = kept;
    _requests.value = [
      for (final r in _requests.value)
        if (r.stage != RequestStage.resolved) r,
    ];
    return count;
  }

  @override
  Future<void> wipe() async {
    for (final key in _timers.keys.toList()) {
      _stop(key);
    }
    _messages.value = const [];
    _requests.value = const [];
    _contacts.value = const [];
    _events.value = const [];
    _channels.value = const [];
    _missions.value = const [];
    _resources.value = const [];
    _offer.value = null;
    _network.value = _offlineStart();
    _readiness.value = _packageStart();
    await _load();
  }

  @override
  Future<void> setNodeEnabled(String nodeId, bool enabled) async {
    _nodes.value = [
      for (final n in _nodes.value)
        n.id == nodeId ? n.copyWith(enabled: enabled) : n,
    ];
  }

  @override
  Future<void> setUserRole(String userId, Role role) async {
    _users.value = [
      for (final u in _users.value) u.id == userId ? u.copyWith(role: role) : u,
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final key in _timers.keys.toList()) {
      _stop(key);
    }
    _notices.close();
    for (final n in <ChangeNotifier>[
      _loading,
      _network,
      _location,
      _nodes,
      _users,
      _requests,
      _resources,
      _alerts,
      _offer,
      _contacts,
      _organizations,
      _channels,
      _messages,
      _missions,
      _events,
      _readiness,
    ]) {
      n.dispose();
    }
  }
}
