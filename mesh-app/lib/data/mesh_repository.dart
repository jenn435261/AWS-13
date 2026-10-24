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

/// Thrown when a request fails the checks the network would also run.
class DraftRejected implements Exception {
  const DraftRejected(this.problems);

  final List<DraftProblem> problems;
}

/// Thrown when an action needs the internet and there is none, such as
/// looking someone up by username.
class NeedsInternet implements Exception {
  const NeedsInternet();
}

/// Something the user should hear about right away (shown as a top toast).
sealed class MeshNotice {
  const MeshNotice();
}

class NearbyRequestNotice extends MeshNotice {
  const NearbyRequestNotice(this.request);

  final HelpRequest request;
}

class HelperFoundNotice extends MeshNotice {
  const HelperFoundNotice(this.request);

  final HelpRequest request;
}

class HandoffConfirmedNotice extends MeshNotice {
  const HandoffConfirmedNotice(this.mission);

  final Mission mission;
}

/// The only thing screens know about the network.
///
/// The phone is the primary computer (Spec section 2): everything is saved
/// and signed here first, shown at once, then distributed when any route
/// exists. Nothing waits on the cloud.
///
/// Implement this once per transport mix:
///  * MockMeshRepository - demo data for building the UI (included)
///  * a local-first repository on SQLite/Drift, fed by Internet, local
///    Wi-Fi, Bluetooth, Meshtastic and Resilience Node transports
abstract class MeshRepository {
  /// This phone's identity; it signs every event.
  Identity get identity;

  /// True until the first load finishes. Screens show skeletons meanwhile.
  ValueListenable<bool> get loading;

  ValueListenable<NetworkStatus> get network;

  /// Null when the phone has no location fix.
  ValueListenable<LocationFix?> get location;

  /// True only while this phone is carrying a delivery: the only time its
  /// location is shared.
  ValueListenable<bool> get sharingLocation;

  ValueListenable<List<MeshNode>> get nodes;

  /// Only meaningful for admins; the backend should refuse it for anyone else.
  ValueListenable<List<AppUser>> get users;

  /// Requests from this phone and open requests nearby, newest first.
  ValueListenable<List<HelpRequest>> get requests;

  ValueListenable<List<Resource>> get resources;

  /// Verified notices from organizations.
  ValueListenable<List<EmergencyAlert>> get alerts;

  /// What this phone's user is offering, or null.
  ValueListenable<HelpOffer?> get offer;

  ValueListenable<List<Contact>> get contacts;

  ValueListenable<List<TrustedOrganization>> get organizations;

  /// Only the channels this phone may read.
  ValueListenable<List<Channel>> get channels;

  /// Oldest first, across all channels.
  ValueListenable<List<MeshMessage>> get messages;

  /// Only missions this phone may see: available ones (for people who can
  /// transport) and ones it is part of.
  ValueListenable<List<Mission>> get missions;

  /// Newest first. The screens are drawn from current state; this is the
  /// signed record of how it got there.
  ValueListenable<List<SignedEvent>> get events;

  ValueListenable<ReadinessPackage> get readiness;

  Stream<MeshNotice> get notices;

  Future<void> sendMessage(String channelId, String text, {required AppUser from});

  /// Validates [draft] again, saves and signs it, then queues it.
  Future<HelpRequest> submitRequest(RequestDraft draft, {required AppUser from});

  /// Sends an SOS with only the location: no questions asked.
  Future<HelpRequest> sendSos({required AppUser from});

  Future<void> cancelRequest(String id);

  /// Puts a cancelled request back, for undo.
  Future<void> restoreRequest(HelpRequest request);

  Future<void> acceptRequest(String id, {required AppUser helper});

  /// Takes back an accepted request, for undo.
  Future<void> releaseRequest(String id);

  Future<void> setOffer(HelpOffer? offer);

  /// Adds a community resource at roughly [point].
  Future<Resource> addResource(ResourceKind kind, LatLng point, {String note = ''});

  Future<void> removeResource(String id);

  /// Records this phone's vote; null withdraws it.
  Future<void> vote(String resourceId, Vote? vote);

  /// Undo for [vote]: puts [before] back exactly as it was, including how
  /// fresh it looked.
  Future<void> restoreVote(Resource before);

  /// Adds someone met in person, from their QR code or typed ID.
  Future<Contact> addContact(String resilienceId, String name);

  /// Looks someone up in the online directory. Throws [NeedsInternet]
  /// offline, and returns null when nobody matches.
  Future<Contact?> findContact({String? username, String? phone});

  Future<void> removeContact(String id);

  /// Undo for [removeContact]: puts [contact] back unchanged, in its old place.
  Future<void> restoreContact(Contact contact);

  Future<void> acceptMission(String id, {required AppUser carrier});

  /// Gives the mission back, for undo.
  Future<void> releaseMission(String id);

  /// The next step: pickup, then delivery.
  Future<void> advanceMission(String id);

  /// Starts a handoff; the next driver scans the package QR.
  Future<void> startHandoff(String id);

  /// Downloads the readiness package from the cloud or a Resilience Node.
  Future<void> downloadReadiness();

  /// Sets where this phone is when GPS can't: typed, or dropped on the map.
  Future<void> setManualLocation(LatLng point, {String label = ''});

  /// DEMO: lets the preview show both offline and online behavior.
  void setInternet(bool on);

  /// Removes old messages and finished requests. Returns how many items.
  Future<int> clearCache();

  /// Deletes everything this phone stored, then reloads public data.
  Future<void> wipe();

  /// Manager and admin action.
  Future<void> setNodeEnabled(String nodeId, bool enabled);

  /// Admin action.
  Future<void> setUserRole(String userId, Role role);

  void dispose();
}
