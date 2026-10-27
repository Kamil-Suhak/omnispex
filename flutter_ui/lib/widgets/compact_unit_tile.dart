import 'package:flutter/material.dart';
import '../models/bsdata_models.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_theme.dart';
import '../theme/omnispex_typography.dart';
import 'unit_details_modal.dart';

/// One-line unit row: name, points, details and an optional trailing action.
/// This is the only unit row used outside of the full datasheet modal.
class CompactUnitTile extends StatelessWidget {
  final BsDataUnit unit;
  final Widget? trailing;
  final VoidCallback? onDetails;

  const CompactUnitTile({
    super.key,
    required this.unit,
    this.trailing,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final pts = unit.pointsCost ??
        (unit.legalSizeOptions.isNotEmpty
            ? unit.legalSizeOptions.first.points
            : null);

    return Material(
      color: OmnispexColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OmnispexLayout.radius),
        side: const BorderSide(color: OmnispexColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(OmnispexLayout.radius),
        onTap: onDetails ?? () => showUnitDetailsModal(context, unit),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  unit.name,
                  style: OmnispexTypography.body
                      .copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (pts != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '$pts pts',
                    style: OmnispexTypography.monoData.copyWith(
                      fontSize: 12,
                      color: OmnispexColors.textSecondary,
                    ),
                  ),
                ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
