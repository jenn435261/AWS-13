import 'package:flutter/material.dart';

import '../gen/resilience/v1/event.pbenum.dart';
import '../l10n/strings.dart';

/// The Round-2 supplies/needs picker list. It is a UI-facing vocabulary that is
/// richer than the proto [ResourceCategory] enum: it adds fuel, hygiene, comms,
/// baby and pets. Rather than grow the proto enum (and force a wire change +
/// node/gen resync), each extra UI item maps to an existing [ResourceCategory]
/// plus a free-text item label. See docs/DECISIONS.md (Round 2 / FEAT-003) for
/// the mapping rationale.
///
///   fuel      -> POWER         (generators/vehicles need fuel; grouped w/ power)
///   hygiene   -> MEDICINE      (sanitation/first-aid adjacent)
///   comms     -> COMMUNICATION (direct match)
///   baby      -> FOOD          (formula/diapers are consumables)
///   pets      -> FOOD          (pet food/supplies are consumables)
///
/// The picked item's label (e.g. "Fuel") is seeded into the free-text item name
/// so the real meaning is never lost even though the stored category is coarser.
class SupplyItem {
  const SupplyItem({
    required this.key,
    required this.labelKey,
    required this.category,
    required this.icon,
  });

  /// Stable id used in forms/tests (not localized).
  final String key;

  /// l10n key for the human label.
  final String labelKey;

  /// The proto category this item is stored as.
  final ResourceCategory category;

  final IconData icon;

  String label(L10n l) => l.t(labelKey);
}

/// The fixed picker order (spec §3.1):
/// water, food, medical, shelter, power, fuel, transport, hygiene, comms,
/// tools, baby, pets, other.
const List<SupplyItem> kSupplyItems = <SupplyItem>[
  SupplyItem(
      key: 'water',
      labelKey: 'cat_water',
      category: ResourceCategory.RESOURCE_CATEGORY_WATER,
      icon: Icons.water_drop_rounded),
  SupplyItem(
      key: 'food',
      labelKey: 'cat_food',
      category: ResourceCategory.RESOURCE_CATEGORY_FOOD,
      icon: Icons.restaurant_rounded),
  SupplyItem(
      key: 'medical',
      labelKey: 'cat_medicine',
      category: ResourceCategory.RESOURCE_CATEGORY_MEDICINE,
      icon: Icons.medication_rounded),
  SupplyItem(
      key: 'shelter',
      labelKey: 'cat_shelter',
      category: ResourceCategory.RESOURCE_CATEGORY_SHELTER,
      icon: Icons.home_rounded),
  SupplyItem(
      key: 'power',
      labelKey: 'cat_power',
      category: ResourceCategory.RESOURCE_CATEGORY_POWER,
      icon: Icons.bolt_rounded),
  SupplyItem(
      key: 'fuel',
      labelKey: 'item_fuel',
      category: ResourceCategory.RESOURCE_CATEGORY_POWER,
      icon: Icons.local_gas_station_rounded),
  SupplyItem(
      key: 'transport',
      labelKey: 'cat_transportation',
      category: ResourceCategory.RESOURCE_CATEGORY_TRANSPORTATION,
      icon: Icons.directions_car_rounded),
  SupplyItem(
      key: 'hygiene',
      labelKey: 'item_hygiene',
      category: ResourceCategory.RESOURCE_CATEGORY_MEDICINE,
      icon: Icons.soap_rounded),
  SupplyItem(
      key: 'comms',
      labelKey: 'cat_communication',
      category: ResourceCategory.RESOURCE_CATEGORY_COMMUNICATION,
      icon: Icons.cell_tower_rounded),
  SupplyItem(
      key: 'tools',
      labelKey: 'cat_tools',
      category: ResourceCategory.RESOURCE_CATEGORY_TOOLS,
      icon: Icons.build_rounded),
  SupplyItem(
      key: 'baby',
      labelKey: 'item_baby',
      category: ResourceCategory.RESOURCE_CATEGORY_FOOD,
      icon: Icons.child_friendly_rounded),
  SupplyItem(
      key: 'pets',
      labelKey: 'item_pets',
      category: ResourceCategory.RESOURCE_CATEGORY_FOOD,
      icon: Icons.pets_rounded),
  SupplyItem(
      key: 'other',
      labelKey: 'cat_other',
      category: ResourceCategory.RESOURCE_CATEGORY_OTHER,
      icon: Icons.category_rounded),
];

/// Lookup by stable [SupplyItem.key].
SupplyItem? supplyItemByKey(String key) {
  for (final it in kSupplyItems) {
    if (it.key == key) return it;
  }
  return null;
}
