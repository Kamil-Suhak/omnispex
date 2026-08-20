import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/simulation_models.dart';
import '../providers/app_state_provider.dart';
import '../screens/in_battle_screen.dart';
import '../services/wahapedia_parser_service.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';
import '../widgets/stat_badge.dart';
import '../widgets/tactical_card.dart';

final wahapediaRawTextProvider = StateProvider<String>((ref) => WahapediaParserService.sampleTerminators);

class WahapediaIngestionScreen extends ConsumerStatefulWidget {
  const WahapediaIngestionScreen({super.key});

  @override
  ConsumerState<WahapediaIngestionScreen> createState() => _WahapediaIngestionScreenState();
}

class _WahapediaIngestionScreenState extends ConsumerState<WahapediaIngestionScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(wahapediaRawTextProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawText = ref.watch(wahapediaRawTextProvider);
    final parsedWeapons = WahapediaParserService.parseWeapons(rawText);
    final parsedUnit = WahapediaParserService.parseUnit(rawText);

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("WAHAPEDIA RAW INGESTION", style: OmnispexTypography.h2),
                      Text("Instant Tabular Text Parser & Weapon Importer", style: OmnispexTypography.bodyMuted),
                    ],
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear_all, size: 14),
                    label: Text("CLEAR INPUT", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OmnispexColors.textSecondary,
                      side: const BorderSide(color: OmnispexColors.border),
                    ),
                    onPressed: () {
                      _controller.clear();
                      ref.read(wahapediaRawTextProvider.notifier).state = "";
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildInputPane(context, ref),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: _buildPreviewPane(context, ref, parsedWeapons, parsedUnit),
                    ),
                  ],
                )
              else ...[
                _buildInputPane(context, ref),
                const SizedBox(height: 16),
                _buildPreviewPane(context, ref, parsedWeapons, parsedUnit),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputPane(BuildContext context, WidgetRef ref) {
    return TacticalCard(
      title: "PASTE RAW WEAPON / UNIT TABLE",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Quick Sample Templates:", style: OmnispexTypography.label.copyWith(fontSize: 10)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTemplateChip("Terminators", WahapediaParserService.sampleTerminators),
              _buildTemplateChip("Leman Russ", WahapediaParserService.sampleLemanRuss),
              _buildTemplateChip("Eradicators", WahapediaParserService.sampleEradicators),
            ],
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _controller,
            maxLines: 12,
            style: OmnispexTypography.monoData.copyWith(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Paste Wahapedia or 40k App weapon tables here...\n\nExample:\nStorm bolter\t24"\t2\t3+\t4\t0\t1\t[RAPID FIRE 2]',
              hintStyle: OmnispexTypography.bodyMuted.copyWith(fontSize: 11),
              fillColor: OmnispexColors.surfaceElevated,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: OmnispexColors.border)),
            ),
            onChanged: (val) => ref.read(wahapediaRawTextProvider.notifier).state = val,
          ),
          const SizedBox(height: 8),
          Text(
            "Auto-detects weapon range, attacks, BS/WS, strength, AP, damage, and keywords (Blast, Lethal Hits, Torrent, etc.).",
            style: OmnispexTypography.bodyMuted.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateChip(String label, String templateText) {
    return ActionChip(
      label: Text(label, style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.cyan)),
      backgroundColor: OmnispexColors.surfaceElevated,
      side: const BorderSide(color: OmnispexColors.border),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: () {
        _controller.text = templateText;
        ref.read(wahapediaRawTextProvider.notifier).state = templateText;
      },
    );
  }

  Widget _buildPreviewPane(
    BuildContext context,
    WidgetRef ref,
    List<WeaponUiProfile> parsedWeapons,
    UnitUiProfile? parsedUnit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TacticalCard(
          title: "LIVE PARSED WEAPONS (${parsedWeapons.length})",
          child: parsedWeapons.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(Icons.table_rows_outlined, size: 36, color: OmnispexColors.textMuted),
                      const SizedBox(height: 8),
                      Text("No valid weapons detected yet.", style: OmnispexTypography.bodyMuted),
                      const SizedBox(height: 4),
                      Text("Paste a weapon table or click a template above.", style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11)),
                    ],
                  ),
                )
              : Column(
                  children: parsedWeapons.map((w) {
                    return _buildParsedWeaponCard(context, ref, w);
                  }).toList(),
                ),
        ),
        if (parsedUnit != null) ...[
          const SizedBox(height: 12),
          TacticalCard(
            title: "PARSED UNIT DATASHEET",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parsedUnit.name, style: OmnispexTypography.h2.copyWith(fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatBadge(label: "T", value: '${parsedUnit.toughness}'),
                    StatBadge(label: "SV", value: '${parsedUnit.save}+'),
                    if (parsedUnit.invuln != null) StatBadge(label: "INV", value: '${parsedUnit.invuln}+', accentColor: OmnispexColors.amber),
                    StatBadge(label: "W", value: '${parsedUnit.woundsPerModel}'),
                    StatBadge(label: "MODELS", value: '${parsedUnit.modelCount}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildParsedWeaponCard(BuildContext context, WidgetRef ref, WeaponUiProfile weapon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OmnispexColors.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "${weapon.name} [${weapon.profileName}]",
                  style: OmnispexTypography.monoData.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatBadge(
                label: "TYPE",
                value: weapon.isMelee ? "MELEE" : '${weapon.range}"',
                accentColor: weapon.isMelee ? OmnispexColors.amber : OmnispexColors.cyan,
              ),
            ],
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatBadge(label: "A", value: weapon.attacks),
              StatBadge(label: "BS/WS", value: '${weapon.skill}+'),
              StatBadge(label: "S", value: '${weapon.strength}'),
              StatBadge(label: "AP", value: '-${weapon.ap}'),
              StatBadge(label: "D", value: weapon.damage),
            ],
          ),

          if (weapon.abilities.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: weapon.abilities.map((ab) {
                return Chip(
                  label: Text(ab, style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 9)),
                  backgroundColor: OmnispexColors.surfaceCard,
                  side: const BorderSide(color: OmnispexColors.border),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(color: OmnispexColors.border, height: 1),
          const SizedBox(height: 8),

          // Actions
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.flash_on, size: 13),
                label: Text("TEST IN BATTLE", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.background)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OmnispexColors.cyan,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  ref.read(customWeaponProfileProvider.notifier).state = weapon;
                  ref.read(isCustomWeaponModeProvider.notifier).state = true;
                  ref.read(currentNavIndexProvider.notifier).state = 0; // In-Battle tab
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Loaded '${weapon.name}' into In-Battle Simulator!"),
                      backgroundColor: OmnispexColors.surfaceElevated,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 13),
                label: Text("ADD TO ARSENAL", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OmnispexColors.textSecondary,
                  side: const BorderSide(color: OmnispexColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  final arsenal = List<WeaponUiProfile>.from(ref.read(customArsenalProvider));
                  if (!arsenal.any((w) => w.name == weapon.name && w.profileName == weapon.profileName)) {
                    arsenal.add(weapon);
                    ref.read(customArsenalProvider.notifier).state = arsenal;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Added '${weapon.name}' to custom weapon arsenal!"),
                      backgroundColor: OmnispexColors.surfaceElevated,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
