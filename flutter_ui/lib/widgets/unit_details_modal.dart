import 'package:flutter/material.dart';
import '../models/bsdata_models.dart';
import '../models/simulation_models.dart';
import '../services/bsdata_service.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_theme.dart';
import '../theme/omnispex_typography.dart';

/// The single entry point for showing a unit datasheet, from any screen.
void showUnitDetailsModal(BuildContext context, BsDataUnit unit) {
  final isWide =
      MediaQuery.of(context).size.width >= OmnispexLayout.wideBreakpoint;
  if (isWide) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(32),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880, maxHeight: 760),
          child: _UnitDetailsContent(unit: unit),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: OmnispexColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _UnitDetailsContent(unit: unit),
    );
  }
}

void showUnitDetailsByNameModal(BuildContext context, String unitName) {
  final unit = BsDataService.findUnitByName(unitName);
  if (unit != null) {
    showUnitDetailsModal(context, unit);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("No loaded datasheet found for '$unitName'."),
        backgroundColor: OmnispexColors.surfaceElevated,
      ),
    );
  }
}

class _UnitDetailsContent extends StatelessWidget {
  final BsDataUnit unit;

  const _UnitDetailsContent({required this.unit});

  @override
  Widget build(BuildContext context) {
    final pts = unit.pointsCost ??
        (unit.legalSizeOptions.isNotEmpty
            ? unit.legalSizeOptions.first.points
            : null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unit.name, style: OmnispexTypography.h2),
                    if (unit.faction.isNotEmpty)
                      Text(unit.faction, style: OmnispexTypography.bodyMuted),
                  ],
                ),
              ),
              if (pts != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  child: Text('$pts pts', style: OmnispexTypography.monoData),
                ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('Profile'),
                _ProfileStats(unit: unit),
                if (unit.weapons.isNotEmpty) ...[
                  _section('Weapons'),
                  ...unit.weapons.map((w) => _WeaponRow(weapon: w)),
                ],
                if (unit.abilities.isNotEmpty) ...[
                  _section('Abilities'),
                  ...unit.abilities.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(a, style: OmnispexTypography.bodyMuted),
                      )),
                ],
                if (unit.legalSizeOptions.isNotEmpty) ...[
                  _section('Unit size'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: unit.legalSizeOptions
                        .map((o) => Chip(
                              label: Text('${o.models} models · ${o.points} pts'),
                            ))
                        .toList(),
                  ),
                ],
                if (unit.categories.isNotEmpty) ...[
                  _section('Keywords'),
                  Text(
                    unit.categories.join(' · '),
                    style: OmnispexTypography.bodyMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(title.toUpperCase(), style: OmnispexTypography.label),
      );
}

class _ProfileStats extends StatelessWidget {
  final BsDataUnit unit;

  const _ProfileStats({required this.unit});

  @override
  Widget build(BuildContext context) {
    final p = unit.unitProfile;
    final stats = <(String, String)>[
      ('M', unit.movement),
      ('T', '${p.toughness}'),
      ('SV', '${p.save}+'),
      ('W', '${p.woundsPerModel}'),
      ('LD', unit.leadership),
      ('OC', '${unit.objectiveControl}'),
      if (p.invuln != null) ('INV', '${p.invuln}+'),
      if (p.fnp != null) ('FNP', '${p.fnp}+'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: stats
          .map((s) => Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: OmnispexColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(OmnispexLayout.radius),
                ),
                child: Column(
                  children: [
                    Text(s.$1, style: OmnispexTypography.label),
                    const SizedBox(height: 2),
                    Text(s.$2, style: OmnispexTypography.monoData),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _WeaponRow extends StatelessWidget {
  final WeaponUiProfile weapon;

  const _WeaponRow({required this.weapon});

  @override
  Widget build(BuildContext context) {
    final w = weapon;
    final stats = [
      ('Range', w.isMelee ? 'Melee' : '${w.range}"'),
      ('A', w.attacks),
      (w.isMelee ? 'WS' : 'BS', '${w.skill}+'),
      ('S', '${w.strength}'),
      ('AP', '-${w.ap}'),
      ('D', w.damage),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceElevated,
        borderRadius: BorderRadius.circular(OmnispexLayout.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(w.name, style: OmnispexTypography.h3)),
              Text(w.isMelee ? 'MELEE' : 'RANGED',
                  style: OmnispexTypography.label),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: stats
                .map((s) => Text.rich(TextSpan(children: [
                      TextSpan(
                          text: '${s.$1} ', style: OmnispexTypography.label),
                      TextSpan(
                          text: s.$2,
                          style: OmnispexTypography.monoData
                              .copyWith(fontSize: 13)),
                    ])))
                .toList(),
          ),
          if (w.abilities.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(w.abilities.join(', '), style: OmnispexTypography.bodyMuted),
          ],
        ],
      ),
    );
  }
}
