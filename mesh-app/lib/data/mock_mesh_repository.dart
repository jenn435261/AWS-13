import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/app_user.dart';
import '../models/envelope.dart';
import '../models/event.dart';
import '../models/help.dart';
import '../models/mesh_message.dart';
import '../models/mesh_node.dart';
import '../models/mission.dart';
import '../models/network.dart';
import '../models/resource.dart';
import '../models/role.dart';
import '../models/social.dart';
import '../services/location_service.dart';
import '../state/drafts.dart';
import '../state/identity.dart';
import 'demo_area.dart';
import 'mesh_repository.dart';
import 'transport/location_policy.dart';
import 'transport/lora_transport.dart';
import 'transport/mesh_transport.dart';
import 'transport/outbox.dart';
import 'transport/router.dart';
import 'transport/simulated_transport.dart';

/// Demo network for building the UI before every transport exists. It
/// plays the other phones, the mesh and the cloud: they, not the screens,
/// decide when something moves to its next stage.
///
/// Everything that leaves the phone goes through a real [Outbox] and
/// [TransportRouter]. By default every link is simulated; pass
/// [transports] (a real Resilience Node, say) to use them in place of the
/// simulated link of the same kind, and [locationProvider] to use the
/// phone's GPS instead of the demo point.
class MockMeshRepository implements MeshRepository {
  MockMeshRepository({
    required this.identity,
    this.simulateTraffic = true,
    this.loadDelay = const Duration(milliseconds: 900),
    this.stageDelay = const Duration(seconds: 1),
    LocationProvider? locationProvider,
    List<MeshTransport> transports = const [],
  }) : _locationProvider = locationProvider {
    final real = {for (final t in transports) t.kind};
    _simulated = {
      for (final kind in LinkKind.values)
        if (!real.contains(kind))
          kind: SimulatedTransport(
            kind,
            latency: stageDelay * 0.3,
            accepts: kind == LinkKind.lora ? LoraTransport.carries : null,
          ),
    };
    router = TransportRouter([...transports, ..._simulated.values]);
    outbox = Outbox(
      router: router,
      policy: LocationPolicy(_sharingLocation),
      retryDelay: stageDelay * 5,
    );
    _applySimulated(_offlineStart());
    router.changes.addListener(_publishNetwork);
    outbox.held.addListener(_publishNetwork);
    _subscriptions.add(outbox.delivered.listen(_onDelivered));
    for (final t in transports) {
      _subscriptions.add(t.received.listen(_onReceived));
      t.start();
    }

    _missions.addListener(_updateSharing);
    _location.addListener(_shareLivePosition);
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

  /// Picks a route for everything that leaves the phone.
  late final TransportRouter router;

  /// Holds each message and event until a route confirms it.
  late final Outbox outbox;

  late final Map<LinkKind, SimulatedTransport> _simulated;
  final LocationProvider? _locationProvider;
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// What the person typed or dropped on the map, while it stands.
  LocationFix? _manual;

  /// The latest reading from GPS (or the demo point).
  LocationFix? _device;

  /// The delivery this phone is carrying, while it shares its position.
  String? _carrying;
  int _liveSeq = 0;

  /// The newest signed copy of each of this phone's requests, so only it
  /// starts the request on its way.
  final _requestEnvelope = <String, String>{};

  DateTime _lastSync = DateTime.now();
  DateTime _lastGlobalSync = DateTime.now();

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

  /// Without a [LocationProvider] the demo point stands in for GPS, so the
  /// demo works anywhere. With one, GPS starts with the first load (and
  /// asks for permission then), and keeps running after a wipe.
  void _seedLocation() {
    final provider = _locationProvider;
    if (provider == null) {
      _onReading(LocationFix(_at(-90, -60), 25, source: LocationSource.demo));
    } else {
      _gps ??= provider.watch().listen(_onReading);
    }
  }

  StreamSubscription<LocationFix?>? _gps;

  /// A new reading: shown unless a manual location stands (see
  /// [chooseLocation] for when GPS takes over again).
  void _onReading(LocationFix? reading) {
    if (_disposed) return;
    _device = reading;
    final choice = chooseLocation(manual: _manual, device: reading);
    _manual = choice.manual;
    _location.value = choice.shown;
  }

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

  /// Signs and stores an event. Every change on this phone goes through
  /// here. With [send], it is also queued to leave the phone as that kind
  /// of envelope, about [about] (default: [subject]); without, it stays
  /// here (contacts, for example). Returns the event id.
  Future<String> _record(
    EventType type,
    String subject, {
    EnvelopeKind? send,
    String? about,
    Map<String, Object?> fields = const {},
    LatLng? location,
  }) async {
    final id = 'e${_seq++}';
    final event = await identity.sign(id, type, subject);
    if (_disposed) return id;
    _events.value = [event, ..._events.value];
    if (send != null) {
      _send(Envelope(
        id: id,
        kind: send,
        subject: about ?? subject,
        author: identity.resilienceId,
        createdAt: event.at,
        fields: fields,
        location: location,
      ));
    }
    return id;
  }

  void _send(Envelope envelope) => outbox.add(envelope);

  /// The id another phone knows something by: this phone's own requests
  /// and reports get its Resilience ID in front, so ids never collide.
  String _ref(String id, {required bool mine}) =>
      mine ? '${identity.resilienceId}-$id' : id;

  /// A route confirmed an envelope: the mesh and the server take it from
  /// here.
  void _onDelivered(Delivery delivery) {
    if (_disposed) return;
    _lastSync = DateTime.now();
    if (delivery.via == LinkKind.cloud) _lastGlobalSync = _lastSync;
    final e = delivery.envelope;
    switch (e.kind) {
      case EnvelopeKind.helpRequest || EnvelopeKind.sos:
        // An older copy (from before a cancel and undo) doesn't count.
        if (_requestEnvelope[e.subject] != e.id) break;
        final request = _requests.value.where((r) => r.id == e.subject).firstOrNull;
        if (request != null && !_timers.containsKey(request.id)) {
          _scheduleStages(request);
        }
      case EnvelopeKind.message:
        _messageLeft(e.fields['messageId'] as String? ?? '', e.subject);
      default:
        break;
    }
    _publishNetwork();
  }

  /// Plays the far side of a message once it left the phone.
  void _messageLeft(String id, String channelId) {
    void set(DeliveryStatus s) => _messages.value = [
          for (final m in _messages.value) m.id == id ? m.copyWith(status: s) : m,
        ];
    set(DeliveryStatus.propagating);
    _later(id, 1.7, () => set(DeliveryStatus.delivered));
    if (channelId.startsWith('dm-')) {
      _later(id, 4.2, () => set(DeliveryStatus.read));
    }
  }

  /// Something another phone sent, through a real transport.
  void _onReceived(Envelope e) {
    if (_disposed) return;
    final from = e.author.length > 8 ? e.author.substring(0, 8) : e.author;
    switch (e.kind) {
      case EnvelopeKind.helpRequest || EnvelopeKind.sos:
        if (e.subject.isEmpty || _requests.value.any((r) => r.id == e.subject)) return;
        final now = DateTime.now();
        final request = HelpRequest(
          id: e.subject,
          kind: HelpKind.values.asNameMap()[e.fields['kind']] ?? HelpKind.other,
          urgency: Urgency.values.asNameMap()[e.fields['urgency']] ?? Urgency.now,
          people: 1,
          createdAt: e.createdAt,
          senderName: from,
          location: e.location,
          locationNote: e.fields['locationNote'] as String? ?? '',
          note: e.fields['note'] as String? ?? '',
          sos: e.kind == EnvelopeKind.sos,
          stage: RequestStage.mesh,
          hops: 1,
          stageTimes: {RequestStage.saved: e.createdAt, RequestStage.mesh: now},
        );
        _requests.value = [request, ..._requests.value];
        _notices.add(NearbyRequestNotice(request));
      case EnvelopeKind.message:
        final id = e.fields['ref'] as String? ?? e.id;
        final channel = e.fields['channelId'] as String? ?? e.subject;
        if (!_channels.value.any((c) => c.id == channel) ||
            _messages.value.any((m) => m.id == id)) {
          return;
        }
        _messages.value = [
          ..._messages.value,
          MeshMessage(
            id: id,
            channelId: channel,
            senderId: e.author,
            senderName: from,
            text: e.fields['text'] as String? ?? '',
            timestamp: e.createdAt,
          ),
        ];
      default:
        break;
    }
  }

  /// The network as the screens see it, from the links and the outbox.
  void _publishNetwork() {
    if (_disposed) return;
    _network.value = router.status(
      queued: outbox.held.value,
      lastSync: _lastSync,
      lastGlobalSync: _lastGlobalSync,
      lastAcks: outbox.lastAcks,
    );
  }

  /// Sets the simulated links to match [s]. Real links are left alone.
  void _applySimulated(NetworkStatus s) {
    _lastSync = s.lastSync;
    _lastGlobalSync = s.lastGlobalSync;
    // Nearby phones: two over Bluetooth for every one over Wi-Fi.
    final wifi = s.peers ~/ 3;
    final bluetooth = s.peers - wifi;
    _simulated[LinkKind.cloud]?.set(up: s.internet, reachesCloud: true);
    _simulated[LinkKind.node]?.set(up: s.node, reachesCloud: s.gatewayOnline);
    _simulated[LinkKind.lora]?.set(up: s.lora, reachesCloud: s.gatewayOnline);
    _simulated[LinkKind.bluetooth]?.set(up: bluetooth > 0, peers: bluetooth);
    _simulated[LinkKind.wifi]?.set(up: wifi > 0, peers: wifi);
    _publishNetwork();
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
    _lastSync = now;
    _publishNetwork();

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

  /// Location leaves the phone only while it carries a delivery. When the
  /// delivery ends, positions still waiting are dropped, and the people
  /// on it are told to stop showing this phone.
  void _updateSharing() {
    final active = _missions.value
        .where((m) =>
            m.carrierIsMe &&
            m.stage != MissionStage.available &&
            m.stage != MissionStage.delivered)
        .firstOrNull;
    final was = _carrying;
    _carrying = active?.id;
    _sharingLocation.value = active != null;
    if (was != null && was != _carrying) {
      outbox.purge((e) => e.kind == EnvelopeKind.liveLocation);
      _send(Envelope(
        id: 'stop${_seq++}',
        kind: EnvelopeKind.locationStopped,
        subject: was,
        author: identity.resilienceId,
        createdAt: DateTime.now(),
      ));
    }
    if (_carrying != null && _carrying != was) _shareLivePosition();
  }

  /// The carrier's position, for the people on the delivery. The outbox
  /// keeps only the newest one waiting.
  void _shareLivePosition() {
    final mission = _carrying;
    final fix = _location.value;
    if (_disposed || mission == null || fix == null || !_sharingLocation.value) return;
    _send(Envelope(
      id: 'live${_seq++}',
      kind: EnvelopeKind.liveLocation,
      subject: mission,
      author: identity.resilienceId,
      createdAt: DateTime.now(),
      fields: {'seq': ++_liveSeq, 'meters': fix.accuracyMeters.round()},
      location: fix.point,
    ));
  }

  @override
  Future<void> setManualLocation(LatLng point, {String label = ''}) async {
    _manual = LocationFix(
      point,
      50,
      source: LocationSource.manual,
      label: label.trim(),
    );
    _location.value = _manual;
  }

  @override
  Future<void> clearManualLocation() async {
    _manual = null;
    _location.value = _device;
  }

  /// Lets tests start from any mix of routes, e.g. no route at all.
  @visibleForTesting
  void debugSetNetwork(NetworkStatus status) => _applySimulated(status);

  /// The simulated link of [kind], for tests and previews; null when a
  /// real transport took its place.
  SimulatedTransport? simulatedLink(LinkKind kind) => _simulated[kind];

  @override
  void setInternet(bool on) {
    if (on) _lastGlobalSync = DateTime.now();
    _simulated[LinkKind.cloud]?.set(up: on);
    _publishNetwork();
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
    final channel = _channels.value.where((c) => c.id == channelId).firstOrNull;
    // It waits in the outbox until a route takes it; then it moves on.
    await _record(
      EventType.messageSent,
      message.id,
      send: EnvelopeKind.message,
      about: channelId,
      fields: {
        'messageId': message.id,
        'ref': _ref(message.id, mine: true),
        'channelId': channelId,
        'channelType':
            (channel?.type ?? (channelId.startsWith('dm-') ? ChannelType.direct : ChannelType.public)).name,
        'text': text,
      },
    );
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

  /// Saved and shown at once, signed, then handed to the outbox. The
  /// stages start when a route confirms it left the phone.
  Future<HelpRequest> _queue(HelpRequest request) async {
    _requests.value = [request, ..._requests.value];
    await _sendRequest(request);
    return request;
  }

  /// Queues [request] to leave the phone, with the place it carries.
  Future<void> _sendRequest(HelpRequest request) async {
    final id = await _record(
      EventType.helpRequested,
      request.id,
      send: request.sos ? EnvelopeKind.sos : EnvelopeKind.helpRequest,
      fields: {
        'ref': _ref(request.id, mine: true),
        'kind': request.kind.name,
        'urgency': request.urgency.name,
        'people': request.people,
        if (request.note.isNotEmpty) 'note': request.note,
        if (request.locationNote.isNotEmpty) 'locationNote': request.locationNote,
      },
      location: request.location,
    );
    _requestEnvelope[request.id] = id;
  }

  /// Plays the mesh and the server: moves a request through its stages,
  /// from the moment a route took it.
  void _scheduleStages(HelpRequest request) {
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
    final request = _requests.value.where((r) => r.id == id).firstOrNull;
    _requests.value = [
      for (final r in _requests.value)
        if (r.id != id) r,
    ];
    // Cancelled before it left the phone: take it back, and nothing is
    // sent at all. Otherwise the network hears it was cancelled.
    final waiting = _requestEnvelope[id];
    final mine = request?.mine ?? false;
    final unsent = waiting != null && outbox.withdraw(waiting);
    await _record(
      EventType.helpCancelled,
      id,
      send: mine && !unsent ? EnvelopeKind.helpCancelled : null,
      fields: {'ref': _ref(id, mine: mine)},
    );
  }

  @override
  Future<void> restoreRequest(HelpRequest request) async {
    if (_requests.value.any((r) => r.id == request.id)) return;
    _requests.value = [request, ..._requests.value];
    if (request.mine) {
      await _sendRequest(request);
    } else {
      await _record(EventType.helpRequested, request.id);
    }
  }

  /// The id of someone else's request as the network knows it.
  String _requestRef(String id) => _ref(
        id,
        mine: _requests.value.any((r) => r.id == id && r.mine),
      );

  @override
  Future<void> acceptRequest(String id, {required AppUser helper}) async {
    _requests.value = [
      for (final r in _requests.value)
        r.id == id && r.isOpen ? r.acceptedByMe(helper.name) : r,
    ];
    await _record(
      EventType.helpAccepted,
      id,
      send: EnvelopeKind.helpAccepted,
      fields: {'ref': _requestRef(id)},
    );
  }

  @override
  Future<void> releaseRequest(String id) async {
    _requests.value = [
      for (final r in _requests.value)
        r.id == id && r.helpingIsMe ? r.released() : r,
    ];
    await _record(
      EventType.helpReleased,
      id,
      send: EnvelopeKind.helpReleased,
      fields: {'ref': _requestRef(id)},
    );
  }

  @override
  Future<void> setOffer(HelpOffer? offer) async {
    _offer.value = offer;
    // An offer says what, never where.
    await _record(
      offer == null ? EventType.offerWithdrawn : EventType.helpOffered,
      'offer',
      send: offer == null ? EnvelopeKind.offerWithdrawn : EnvelopeKind.offer,
      fields: {
        'ref': _ref('offer', mine: true),
        if (offer != null) ...{
          'kinds': [for (final k in offer.kinds) k.name],
          'amount': offer.amount.name,
          'availability': offer.availability.name,
          if (offer.availabilityNote.isNotEmpty) 'availabilityNote': offer.availabilityNote,
          if (offer.note.isNotEmpty) 'note': offer.note,
          if (offer.transport != null) 'transport': offer.transport!.name,
          if (offer.capacity != null) 'capacity': offer.capacity!.name,
        },
      },
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
    // The place the person put it on the map is the report itself.
    await _record(
      EventType.resourceCreated,
      resource.id,
      send: EnvelopeKind.resourceCreated,
      fields: {
        'ref': _ref(resource.id, mine: true),
        'kind': kind.name,
        if (resource.note.isNotEmpty) 'note': resource.note,
      },
      location: point,
    );
    return resource;
  }

  /// The id of a resource as the network knows it.
  String _resourceRef(String id) => _ref(
        id,
        mine: _resources.value.any((r) => r.id == id && r.mine),
      );

  @override
  Future<void> removeResource(String id) async {
    final ref = _resourceRef(id);
    _resources.value = [
      for (final r in _resources.value)
        if (r.id != id) r,
    ];
    await _record(
      EventType.resourceRemoved,
      id,
      send: EnvelopeKind.resourceRemoved,
      fields: {'ref': ref},
    );
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
      send: EnvelopeKind.vote,
      fields: {'ref': _resourceRef(resourceId), 'vote': vote?.name},
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
      send: EnvelopeKind.vote,
      fields: {'ref': _resourceRef(before.id), 'vote': before.myVote?.name},
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
    await _record(EventType.missionAccepted, id, send: EnvelopeKind.missionAccepted);
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
    await _record(EventType.missionReleased, id, send: EnvelopeKind.missionReleased);
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
    await _record(
      event,
      id,
      send: event == EventType.packagePickedUp
          ? EnvelopeKind.packagePickedUp
          : EnvelopeKind.deliveryCompleted,
      fields: {'packageId': mission.packageId},
    );
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
      await _record(
        EventType.packageTransferred,
        id,
        send: EnvelopeKind.packageTransferred,
        fields: {'packageId': _missions.value.firstWhere((m) => m.id == id).packageId},
      );
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
    // Unsent items are on this phone too: they go with everything else.
    outbox.clear();
    _requestEnvelope.clear();
    _manual = null;
    _applySimulated(_offlineStart());
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
    _gps?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    router.changes.removeListener(_publishNetwork);
    outbox.held.removeListener(_publishNetwork);
    outbox.dispose();
    router.dispose();
    _missions.removeListener(_updateSharing);
    _location.removeListener(_shareLivePosition);
    _notices.close();
    for (final n in <ChangeNotifier>[
      _loading,
      _network,
      _location,
      _sharingLocation,
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
