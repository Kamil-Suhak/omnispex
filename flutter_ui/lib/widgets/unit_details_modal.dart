import 'package:flutter/material.dart';
import '../models/bsdata_models.dart';
import '../models/simulation_models.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';
import 'stat_badge.dart';

void showUnitDetailsModal(BuildContext context, BsDataUnit unit) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _UnitDetailsSheet(unit: unit),
  );
}

class _UnitDetailsSheet extends StatelessWidget {
  final BsDataUnit unit;

  const _UnitDetailsSheet({required this.unit});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
      decoration: const BoxDecoration(
        color: OmnispexColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: OmnispexColors.cyan, width: 2),
          left: BorderSide(color: OmnispexColors.border),
          right: BorderSide(color: OmnispexColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: OmnispexColors.borderBright,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.name,
                        style: OmnispexTypography.h2.copyWith(fontSize: 20),
                      ),
                      if (unit.faction.isNotEmpty)
                        Text(
                          unit.faction.toUpperCase(),
                          style: OmnispexTypography.label.copyWith(
                            color: OmnispexColors.cyan,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                if (unit.pointsCost != null)
                  StatBadge(
                    label: 'POINTS',
                    value: '${unit.pointsCost} PTS',
                    accentColor: OmnispexColors.cyan,
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: OmnispexColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: OmnispexColors.border),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Core Profile Statlines
                  _buildSectionHeader('PROFILE STATS'),
                  const SizedBox(height: 8),
                  _buildProfileRow(unit),
                  const SizedBox(height: 16),

                  // 2. Ranged & Melee Weapons
                  if (unit.weapons.isNotEmpty) ...[
                    _buildSectionHeader('WEAPONS PROFILES (${unit.weapons.length})'),
                    const SizedBox(height: 8),
                    ...unit.weapons.map((w) => _buildWeaponTile(w)),
                    const SizedBox(height: 16),
                  ],

                  // 3. Abilities & Rules
                  if (unit.abilities.isNotEmpty) ...[
                    _buildSectionHeader('UNIT ABILITIES & RULES'),
                    const SizedBox(height: 8),
                    ...unit.abilities.map((ab) => _buildAbilityTile(ab)),
                    const SizedBox(height: 16),
                  ],

                  // 4. Unit Composition / Legal Size Options
                  if (unit.legalSizeOptions.isNotEmpty) ...[
                    _buildSectionHeader('UNIT COMPOSITION & SIZES'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: unit.legalSizeOptions.map((opt) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: OmnispexColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: OmnispexColors.border),
                          ),
                          child: Text(
                            '${opt.models} Models • ${opt.points} pts',
                            style: OmnispexTypography.monoData.copyWith(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 5. Keywords & Categories
                  if (unit.categories.isNotEmpty) ...[
                    _buildSectionHeader('KEYWORDS & FACTION TAGS'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: unit.categories.map((cat) {
                        final isRole = cat == 'Character' || cat == 'Battleline' || cat == 'Epic Hero';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isRole
                                ? OmnispexColors.amber.withValues(alpha: 0.15)
                                : OmnispexColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isRole ? OmnispexColors.amber : OmnispexColors.border,
                            ),
                          ),
                          child: Text(
                            cat.toUpperCase(),
                            style: OmnispexTypography.monoStatBadge.copyWith(
                              fontSize: 10,
                              color: isRole ? OmnispexColors.amber : OmnispexColors.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: OmnispexTypography.label.copyWith(
        fontSize: 11,
        color: OmnispexColors.cyan,
      ),
    );
  }

  Widget _buildProfileRow(BsDataUnit u) {
    final prof = u.unitProfile;
    final statList = [
      {'label': 'M', 'val': prof.movement},
      {'label': 'T', 'val': '${prof.toughness}'},
      {'label': 'SV', 'val': '${prof.save}+'},
      {'label': 'W', 'val': '${prof.woundsPerModel}'},
      {'label': 'LD', 'val': prof.leadership},
      {'label': 'OC', 'val': '${prof.objectiveControl}'},
      if (prof.invuln != null)
        {'label': 'INV', 'val': '${prof.invuln}+'},
      if (prof.fnp != null)
        {'label': 'FNP', 'val': '${prof.fnp}+'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statList.map((stat) {
        return Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: OmnispexColors.surfaceElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: OmnispexColors.border),
          ),
          child: Column(
            children: [
              Text(
                stat['label']!,
                style: OmnispexTypography.label.copyWith(fontSize: 10, color: OmnispexColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                stat['val']!,
                style: OmnispexTypography.monoData.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: stat['label'] == 'INV'
                      ? OmnispexColors.purple
                      : (stat['label'] == 'SV' ? OmnispexColors.cyan : OmnispexColors.textPrimary),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeaponTile(WeaponUiProfile w) {
    final isMelee = w.isMelee;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: OmnispexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isMelee ? Icons.sports_kabaddi : Icons.gps_fixed,
                size: 14,
                color: isMelee ? OmnispexColors.amber : OmnispexColors.cyan,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  w.name,
                  style: OmnispexTypography.h3.copyWith(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                isMelee ? 'MELEE' : 'RANGED',
                style: OmnispexTypography.monoStatBadge.copyWith(
                  fontSize: 10,
                  color: isMelee ? OmnispexColors.amber : OmnispexColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('Range: ${w.isMelee ? 'Melee' : '${w.range}"'}', style: OmnispexTypography.monoData.copyWith(fontSize: 11)),
              Text('A: ${w.attacks}', style: OmnispexTypography.monoData.copyWith(fontSize: 11)),
              Text('BS/WS: ${w.skill}+', style: OmnispexTypography.monoData.copyWith(fontSize: 11)),
              Text('S: ${w.strength}', style: OmnispexTypography.monoData.copyWith(fontSize: 11)),
              Text('AP: -${w.ap}', style: OmnispexTypography.monoData.copyWith(fontSize: 11)),
              Text('D: ${w.damage}', style: OmnispexTypography.monoData.copyWith(fontSize: 11)),
            ],
          ),
          if (w.abilities.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Abilities: ${w.abilities.join(", ")}',
              style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11, color: OmnispexColors.cyan),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAbilityTile(String ability) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: OmnispexColors.border),
      ),
      child: Text(
        ability,
        style: OmnispexTypography.body.copyWith(fontSize: 12),
      ),
    );
  }
}
