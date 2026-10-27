import 'package:flutter/material.dart';
import '../models/bsdata_models.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';
import 'unit_details_modal.dart';

class CompactUnitTile extends StatelessWidget {
  final BsDataUnit unit;
  final Widget? trailing;
  final List<Widget>? actionButtons;
  final VoidCallback? onDetails;

  const CompactUnitTile({
    super.key,
    required this.unit,
    this.trailing,
    this.actionButtons,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final p = unit.unitProfile;
    final pts = unit.pointsCost ??
        (unit.legalSizeOptions.isNotEmpty
            ? unit.legalSizeOptions.first.points
            : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OmnispexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Indicator, Unit Name, Points Badge, Details Button, Trailing
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: OmnispexColors.cyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  unit.name,
                  style: OmnispexTypography.h3.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (pts != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: OmnispexColors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: OmnispexColors.purple.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    "$pts PTS",
                    style: OmnispexTypography.monoStatBadge.copyWith(
                      fontSize: 11,
                      color: OmnispexColors.purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.info_outline, size: 13),
                label: Text(
                  "DETAILS",
                  style: OmnispexTypography.monoStatBadge.copyWith(
                    fontSize: 10,
                    color: OmnispexColors.cyan,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OmnispexColors.cyan,
                  side: const BorderSide(color: OmnispexColors.cyan),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onDetails ?? () => showUnitDetailsModal(context, unit),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Row 2: Categories & Stats Summary
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: OmnispexColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: OmnispexColors.border),
                ),
                child: Text(
                  unit.faction.toUpperCase(),
                  style: OmnispexTypography.monoStatBadge.copyWith(
                    fontSize: 9,
                    color: OmnispexColors.textMuted,
                  ),
                ),
              ),
              ...unit.categories.take(3).map((cat) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: OmnispexColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: OmnispexColors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    cat.toUpperCase(),
                    style: OmnispexTypography.monoStatBadge.copyWith(
                      fontSize: 8,
                      color: OmnispexColors.textSecondary,
                    ),
                  ),
                );
              }),
              Text(
                "• M ${unit.movement} • T ${p.toughness} • Sv ${p.save}+ • W ${p.woundsPerModel}",
                style: OmnispexTypography.monoData.copyWith(
                  fontSize: 10,
                  color: OmnispexColors.textMuted,
                ),
              ),
            ],
          ),

          // Row 3: Action Buttons (optional)
          if (actionButtons != null && actionButtons!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: actionButtons!,
            ),
          ],
        ],
      ),
    );
  }
}

