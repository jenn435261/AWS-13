import 'package:flutter/material.dart';

import '../../gen/resilience/v1/event.pbenum.dart';
import '../../l10n/strings.dart';
import '../../trust/trust_engine.dart';
import '../theme/app_theme.dart';

/// Widgets that render the THREE trust dimensions (source / corroboration /
/// freshness) separately — never collapsed into a single score (spec §9).
/// No emojis; provenance uses a verified check vs a community circle icon.

/// Source provenance: verified organization (check) vs community (circle).
class ProvenanceBadge extends StatelessWidget {
  final Provenance provenance;
  const ProvenanceBadge({super.key, required this.provenance});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final verified = provenance.isVerifiedOrg && !provenance.revoked;
    final color = verified ? AppTheme.verified : AppTheme.communityAccent;
    final icon = verified
        ? Icons.verified_rounded
        : Icons.radio_button_unchecked_rounded;
    final label =
        verified ? l.t('verified_organization') : l.t('community_resource');
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Corroboration: confirm / dispute counts (distinct observers).
class CorroborationBadge extends StatelessWidget {
  final Corroboration corroboration;
  const CorroborationBadge({super.key, required this.corroboration});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 20),
        const SizedBox(width: 4),
        Text('${corroboration.confirmCount} ${l.t('confirmations')}',
            style: const TextStyle(fontSize: 16)),
        if (corroboration.disputeCount > 0) ...[
          const SizedBox(width: 12),
          const Icon(Icons.report_problem_outlined, size: 20),
          const SizedBox(width: 4),
          Text('${corroboration.disputeCount} ${l.t('disputes')}',
              style: const TextStyle(fontSize: 16)),
        ],
      ],
    );
  }
}

/// Freshness: human age with a decay-driven color (fresh -> stale).
class FreshnessBadge extends StatelessWidget {
  final Freshness freshness;
  const FreshnessBadge({super.key, required this.freshness});

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      Theme.of(context).colorScheme.outline,
      AppTheme.verified,
      freshness.decayFactor.clamp(0.0, 1.0),
    )!;
    final stale = freshness.decayFactor < 0.25;
    return Semantics(
      label: 'Updated ${_ageString(freshness.ageMs)}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stale ? Icons.history_toggle_off_rounded : Icons.schedule_rounded,
              size: 20, color: color),
          const SizedBox(width: 6),
          Text(_ageString(freshness.ageMs),
              style: TextStyle(fontSize: 16, color: color)),
        ],
      ),
    );
  }
}

/// A compact confidence band chip (derived; shown alongside, not instead of,
/// the three dimensions).
class ConfidenceChip extends StatelessWidget {
  final ConfidenceBand band;
  const ConfidenceChip({super.key, required this.band});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final (String key, Color color) = switch (band) {
      ConfidenceBand.high => ('confidence_high', AppTheme.verified),
      ConfidenceBand.medium => ('confidence_medium', Color(0xFFB07A00)),
      ConfidenceBand.low => ('confidence_low', Color(0xFFB4530A)),
      ConfidenceBand.unconfirmed =>
        ('confidence_unconfirmed', Theme.of(context).colorScheme.outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        l.t(key),
        style:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// All three dimensions stacked — the canonical resource trust display.
class TrustProfileView extends StatelessWidget {
  final TrustProfile profile;
  const TrustProfileView({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProvenanceBadge(provenance: profile.source),
        const SizedBox(height: 8),
        CorroborationBadge(corroboration: profile.corroboration),
        const SizedBox(height: 8),
        FreshnessBadge(freshness: profile.freshness),
        const SizedBox(height: 10),
        ConfidenceChip(band: profile.band),
      ],
    );
  }
}

String _ageString(int ageMs) {
  if (ageMs < 0) ageMs = 0;
  final s = ageMs ~/ 1000;
  if (s < 60) return '${s}s ago';
  final m = s ~/ 60;
  if (m < 60) return '${m}m ago';
  final h = m ~/ 60;
  if (h < 24) return '${h}h ago';
  final d = h ~/ 24;
  return '${d}d ago';
}

/// Maps a ResourceCategory to a Material icon (no emojis).
IconData iconForCategory(ResourceCategory c) {
  switch (c) {
    case ResourceCategory.RESOURCE_CATEGORY_WATER:
      return Icons.water_drop_rounded;
    case ResourceCategory.RESOURCE_CATEGORY_FOOD:
      return Icons.restaurant_rounded;
    case ResourceCategory.RESOURCE_CATEGORY_MEDICINE:
      return Icons.medication_rounded;
    case ResourceCategory.RESOURCE_CATEGORY_SHELTER:
      return Icons.home_rounded;
    case ResourceCategory.RESOURCE_CATEGORY_POWER:
      return Icons.bolt_rounded;
    case ResourceCategory.RESOURCE_CATEGORY_TRANSPORTATION:
      return Icons.directions_car_rounded;
    case ResourceCategory.RESOURCE_CATEGORY_MEDICAL_HELP:
      return Icons.medical_services_rounded;
    case ResourceCategory.RESOURCE_CATEGORY_COMMUNICATION:
      return Icons.cell_tower_rounded;
    case ResourceCategory.RESOURCE_CATEGORY_BLANKETS:
      return Icons.bed_rounded;
    case ResourceCategory.RESOURCE_CATEGORY_BATTERIES:
      return Icons.battery_charging_full_rounded;
    case ResourceCategory.RESOURCE_CATEGORY_CHARGING:
      return Icons.power_rounded;
    case ResourceCategory.RESOURCE_CATEGORY_TOOLS:
      return Icons.build_rounded;
    default:
      return Icons.category_rounded;
  }
}

String categoryLabel(L10n l, ResourceCategory c) {
  switch (c) {
    case ResourceCategory.RESOURCE_CATEGORY_WATER:
      return l.t('cat_water');
    case ResourceCategory.RESOURCE_CATEGORY_FOOD:
      return l.t('cat_food');
    case ResourceCategory.RESOURCE_CATEGORY_MEDICINE:
      return l.t('cat_medicine');
    case ResourceCategory.RESOURCE_CATEGORY_SHELTER:
      return l.t('cat_shelter');
    case ResourceCategory.RESOURCE_CATEGORY_POWER:
      return l.t('cat_power');
    case ResourceCategory.RESOURCE_CATEGORY_TRANSPORTATION:
      return l.t('cat_transportation');
    case ResourceCategory.RESOURCE_CATEGORY_MEDICAL_HELP:
      return l.t('cat_medical_help');
    case ResourceCategory.RESOURCE_CATEGORY_COMMUNICATION:
      return l.t('cat_communication');
    case ResourceCategory.RESOURCE_CATEGORY_BLANKETS:
      return l.t('cat_blankets');
    case ResourceCategory.RESOURCE_CATEGORY_BATTERIES:
      return l.t('cat_batteries');
    case ResourceCategory.RESOURCE_CATEGORY_CHARGING:
      return l.t('cat_charging');
    case ResourceCategory.RESOURCE_CATEGORY_TOOLS:
      return l.t('cat_tools');
    default:
      return l.t('cat_other');
  }
}
