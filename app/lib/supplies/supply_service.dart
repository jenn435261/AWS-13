import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart' show GeneratedMessage;
import 'package:uuid/uuid.dart';

import '../core/event_factory.dart';
import '../core/event_store.dart';
import '../core/lamport_clock.dart';
import '../core/signing.dart';
import '../gen/resilience/v1/event.pb.dart';

/// What the user types into the supply form.
class SupplyDraft {
  /// Null => a new supply; otherwise the id of the supply being edited.
  final String? resourceId;
  final ResourceCategory category;
  final String title;
  final String notes;

  /// Optional authoritative count and its unit ("cases", "gallons").
  final int? quantity;
  final String unit;
  final AmountBand amount;
  final Availability availability;

  /// When the supply stops being available. Null => no end date.
  final DateTime? availableUntil;
  final GeoPoint? location;
  final bool isShelter;

  const SupplyDraft({
    this.resourceId,
    required this.category,
    required this.title,
    this.notes = '',
    this.quantity,
    this.unit = '',
    this.amount = AmountBand.AMOUNT_BAND_UNSPECIFIED,
    this.availability = Availability.AVAILABILITY_NOW,
    this.availableUntil,
    this.location,
    this.isShelter = false,
  });
}

/// Publishes the signed events that create and maintain a supply.
///
/// The log is append-only, so "edit" re-publishes the supply under the same id
/// (latest wins, owner only), "update quantity" publishes an inventory
/// snapshot, and "delete" is a take-down: the supply is marked withdrawn and
/// disappears from the map but the history stays verifiable.
class SupplyService {
  SupplyService({
    required this.store,
    required this.factory,
    required this.clock,
    required this.keyPair,
    this.provenance = ProvenanceKind.PROVENANCE_KIND_COMMUNITY,
  });

  final EventStore store;
  final EventFactory factory;
  final LamportClock clock;
  final KeyPairData keyPair;
  final ProvenanceKind provenance;

  /// Creates or edits a supply. Returns its resource id.
  Future<String> save(SupplyDraft d) async {
    final id = d.resourceId ?? const Uuid().v4();
    final body = ResourceBody(
      resourceId: id,
      category: d.category,
      title: d.title.trim(),
      notes: d.notes.trim(),
      amount: d.amount,
      availability: d.availability,
      provenance: provenance,
      isShelter: d.isShelter,
    );
    if (d.availableUntil != null) {
      body.availableUntilMs = Int64(d.availableUntil!.millisecondsSinceEpoch);
    }
    if (d.location != null) body.location = d.location!;
    await _apply(EventType.EVENT_TYPE_RESOURCE_CREATED, body);
    if (d.quantity != null) {
      await setQuantity(id, d.quantity!, d.unit);
    }
    return id;
  }

  /// Puts a taken-down supply back up. A proto3 `withdrawn: false` update is
  /// indistinguishable from "no change" on the wire, so relisting re-publishes
  /// the supply itself; the fold treats an owner's re-publish as relisted.
  Future<void> relist(ResourceBody current) =>
      _apply(EventType.EVENT_TYPE_RESOURCE_CREATED, current);

  /// Publishes the authoritative count ("restock" or "adjust").
  Future<void> setQuantity(String id, int quantity, String unit) =>
      _apply(
          EventType.EVENT_TYPE_INVENTORY_SNAPSHOT,
          InventorySnapshotBody(
            resourceId: id,
            quantity: Int64(quantity < 0 ? 0 : quantity),
            unit: unit,
            asOfMs: Int64(DateTime.now().millisecondsSinceEpoch),
          ));

  /// Out of stock: count goes to zero and the supply stays listed as "Low" so
  /// people know it existed and may be restocked.
  Future<void> markRanOut(String id, String unit) async {
    await setQuantity(id, 0, unit);
    await _apply(
        EventType.EVENT_TYPE_RESOURCE_UPDATED,
        ResourceUpdateBody(
            resourceId: id, amount: AmountBand.AMOUNT_BAND_LOW));
  }

  /// Takes the supply down. It leaves the map but the history stays verifiable.
  Future<void> takeDown(String id) => _apply(
      EventType.EVENT_TYPE_RESOURCE_UPDATED,
      ResourceUpdateBody(resourceId: id, withdrawn: true));

  Future<void> _apply(EventType type, GeneratedMessage body) async {
    final event = await factory.buildFromMessage(
        keyPair: keyPair, clock: clock, type: type, body: body);
    await store.apply(event);
  }
}
