import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/simulation_models.dart';
import '../providers/app_state_provider.dart';
import '../services/bsdata_service.dart';
import '../services/personal_data_service.dart';
import '../services/simulation_service.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';
import '../widgets/stat_badge.dart';
import '../widgets/tactical_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iterations = ref.watch(simulationIterationsProvider);
    final confidence = ref.watch(confidenceThresholdProvider);
    final archetypes = ref.watch(customArchetypesProvider);

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
                      Text("SETTINGS & ARCHETYPES", style: OmnispexTypography.h2),
                      Text("Engine Configuration & Custom Benchmark Roster", style: OmnispexTypography.bodyMuted),
                    ],
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restore, size: 14),
                    label: Text("RESET TO DEFAULTS", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OmnispexColors.amber,
                      side: const BorderSide(color: OmnispexColors.amber),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () {
                      ref.read(simulationIterationsProvider.notifier).state = 10000;
                      ref.read(confidenceThresholdProvider.notifier).state = 80;
                      ref.read(customArchetypesProvider.notifier).state = List.from(SimulationService.defaultArchetypes);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("All settings and archetypes reset to defaults!"),
                          backgroundColor: OmnispexColors.surfaceElevated,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 1. Simulation Engine Parameters
              TacticalCard(
                title: "1. SIMULATION ENGINE PARAMETERS",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("MONTE CARLO ITERATIONS:", style: OmnispexTypography.label.copyWith(fontSize: 11)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildIterationChip(ref, 1000, "1,000 (Fast)", iterations),
                        _buildIterationChip(ref, 10000, "10,000 (Standard)", iterations),
                        _buildIterationChip(ref, 50000, "50,000 (Precision)", iterations),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text("SAFE BET CONFIDENCE THRESHOLD:", style: OmnispexTypography.label.copyWith(fontSize: 11)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildConfidenceChip(ref, 75, "75% Confidence", confidence),
                        _buildConfidenceChip(ref, 80, "80% Confidence (Standard)", confidence),
                        _buildConfidenceChip(ref, 90, "90% Confidence (Conservative)", confidence),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Customizable Defensive Archetypes
              Text("2. CUSTOMIZABLE DEFENSIVE ARCHETYPES", style: OmnispexTypography.h2),
              const SizedBox(height: 4),
              Text(
                "Adjust baseline stats (Toughness, Armor, Invuln, Wounds, Models) to match your local meta:",
                style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 12),

              ...List.generate(archetypes.length, (idx) {
                final entry = archetypes[idx];
                return _buildArchetypeEditorCard(context, ref, idx, entry);
              }),
              const SizedBox(height: 16),

              // 3. Game Data Provenance & Catalogue Management
              TacticalCard(
                title: "3. WARHAMMER 11E GAME DATA & PROVENANCE",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        StatBadge(
                          label: "EDITION",
                          value: BsDataService.provenance.edition,
                          accentColor: OmnispexColors.cyan,
                        ),
                        StatBadge(
                          label: "BSDATA REV",
                          value: BsDataService.provenance.bsdataRevision.length > 8
                              ? BsDataService.provenance.bsdataRevision.substring(0, 8)
                              : BsDataService.provenance.bsdataRevision,
                          accentColor: OmnispexColors.amber,
                        ),
                        StatBadge(
                          label: "MFM VERSION",
                          value: "v${BsDataService.provenance.mfmVersion} (${BsDataService.provenance.mfmLastUpdated})",
                          accentColor: OmnispexColors.purple,
                        ),
                        StatBadge(
                          label: "FACTIONS",
                          value: "${BsDataService.bundledFactions.length}",
                          accentColor: OmnispexColors.greenKill,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      BsDataService.provenance.attributionNotice,
                      style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.upload_file, size: 14),
                          label: Text(
                            "IMPORT CUSTOM BSDATA JSON",
                            style: OmnispexTypography.monoStatBadge.copyWith(
                              fontSize: 10,
                              color: OmnispexColors.background,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: OmnispexColors.cyan,
                          ),
                          onPressed: () => _showImportCatalogueDialog(context, ref),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 4. Local-First Personal Data Backup & Restore
              TacticalCard(
                title: "4. PERSONAL DATA BACKUP & RESTORE (ISOLATED FROM GAME DATA)",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your Army Lists, Wishlists, Match History, and Saved Calculations are stored locally and isolated from game catalogue updates.",
                      style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.download, size: 14),
                          label: Text(
                            "EXPORT PERSONAL BACKUP JSON",
                            style: OmnispexTypography.monoStatBadge.copyWith(
                              fontSize: 10,
                              color: OmnispexColors.background,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: OmnispexColors.greenKill,
                          ),
                          onPressed: () {
                            final store = ref.read(personalStoreProvider);
                            final jsonStr = PersonalDataService.exportBackupJson(store);
                            _showBackupExportDialog(context, jsonStr);
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.restore_page, size: 14),
                          label: Text(
                            "RESTORE FROM BACKUP JSON",
                            style: OmnispexTypography.monoStatBadge.copyWith(
                              fontSize: 10,
                              color: OmnispexColors.amber,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: OmnispexColors.amber,
                            side: const BorderSide(color: OmnispexColors.amber),
                          ),
                          onPressed: () => _showBackupRestoreDialog(context, ref),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImportCatalogueDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmnispexColors.surfaceCard,
        title: Text("IMPORT BSDATA CATALOGUE JSON", style: OmnispexTypography.h3),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: ctrl,
            maxLines: 8,
            style: OmnispexTypography.monoData.copyWith(fontSize: 11),
            decoration: const InputDecoration(
              hintText: 'Paste BSData 11e .json catalogue content...',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: OmnispexColors.cyan,
              foregroundColor: OmnispexColors.background,
            ),
            onPressed: () {
              try {
                final parsed = BsDataService.importCatalogueJson(ctrl.text);
                ref.read(catalogueRevisionEpochProvider.notifier).state++;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        "Imported '${parsed.name}' (${parsed.units.length} units) without modifying personal data!"),
                    backgroundColor: OmnispexColors.surfaceElevated,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Catalogue parse error: $e"),
                    backgroundColor: OmnispexColors.redIneffective,
                  ),
                );
              }
            },
            child: const Text("IMPORT"),
          ),
        ],
      ),
    );
  }

  void _showBackupExportDialog(BuildContext context, String jsonStr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmnispexColors.surfaceCard,
        title: Text("PERSONAL DATA BACKUP JSON", style: OmnispexTypography.h3),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonStr,
              style: OmnispexTypography.monoData.copyWith(fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("CLOSE"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 14),
            label: const Text("COPY TO CLIPBOARD"),
            style: ElevatedButton.styleFrom(
              backgroundColor: OmnispexColors.cyan,
              foregroundColor: OmnispexColors.background,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Personal backup JSON copied to clipboard!"),
                  backgroundColor: OmnispexColors.surfaceElevated,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showBackupRestoreDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmnispexColors.surfaceCard,
        title: Text("RESTORE PERSONAL BACKUP JSON", style: OmnispexTypography.h3),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: ctrl,
            maxLines: 8,
            style: OmnispexTypography.monoData.copyWith(fontSize: 11),
            decoration: const InputDecoration(
              hintText: 'Paste exported Omnispex Personal Data Backup JSON...',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: OmnispexColors.amber,
              foregroundColor: OmnispexColors.background,
            ),
            onPressed: () {
              try {
                final restored =
                    PersonalDataService.restoreFromBackupJson(ctrl.text);
                ref.read(personalStoreProvider.notifier).restoreBackup(restored);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        "Personal data restored and migrated via Rust schema engine!"),
                    backgroundColor: OmnispexColors.surfaceElevated,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Invalid backup JSON: $e"),
                    backgroundColor: OmnispexColors.redIneffective,
                  ),
                );
              }
            },
            child: const Text("RESTORE"),
          ),
        ],
      ),
    );
  }

  Widget _buildIterationChip(WidgetRef ref, int val, String label, int current) {
    final isSel = val == current;
    return ChoiceChip(
      label: Text(label, style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 11, color: isSel ? OmnispexColors.background : OmnispexColors.cyan)),
      selected: isSel,
      selectedColor: OmnispexColors.cyan,
      backgroundColor: OmnispexColors.surfaceElevated,
      side: BorderSide(color: isSel ? OmnispexColors.cyan : OmnispexColors.border),
      onSelected: (sel) {
        if (sel) ref.read(simulationIterationsProvider.notifier).state = val;
      },
    );
  }

  Widget _buildConfidenceChip(WidgetRef ref, int val, String label, int current) {
    final isSel = val == current;
    return ChoiceChip(
      label: Text(label, style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 11, color: isSel ? OmnispexColors.background : OmnispexColors.greenKill)),
      selected: isSel,
      selectedColor: OmnispexColors.greenKill,
      backgroundColor: OmnispexColors.surfaceElevated,
      side: BorderSide(color: isSel ? OmnispexColors.greenKill : OmnispexColors.border),
      onSelected: (sel) {
        if (sel) ref.read(confidenceThresholdProvider.notifier).state = val;
      },
    );
  }

  Widget _buildArchetypeEditorCard(
    BuildContext context,
    WidgetRef ref,
    int idx,
    ArchetypeEntryUi entry,
  ) {
    final target = entry.target;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OmnispexColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OmnispexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(entry.label, style: OmnispexTypography.h2.copyWith(fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: OmnispexColors.cyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(entry.id.toUpperCase(), style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 9, color: OmnispexColors.cyan)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(entry.description, style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11)),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatField("Toughness (T)", "${target.toughness}", (val) {
                final n = int.tryParse(val);
                if (n != null) _updateTarget(ref, idx, entry, toughness: n);
              }),
              _buildStatField("Armor (Sv+)", "${target.save}", (val) {
                final n = int.tryParse(val);
                if (n != null) _updateTarget(ref, idx, entry, save: n);
              }),
              _buildStatField("Invuln (Inv+)", target.invuln != null ? "${target.invuln}" : "-", (val) {
                final n = int.tryParse(val);
                _updateTarget(ref, idx, entry, invuln: n);
              }),
              _buildStatField("Wounds (W)", "${target.woundsPerModel}", (val) {
                final n = int.tryParse(val);
                if (n != null) _updateTarget(ref, idx, entry, wounds: n);
              }),
              _buildStatField("Models", "${target.modelCount}", (val) {
                final n = int.tryParse(val);
                if (n != null) _updateTarget(ref, idx, entry, models: n);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatField(String label, String value, ValueChanged<String> onChanged) {
    return SizedBox(
      width: 100,
      child: TextFormField(
        initialValue: value,
        keyboardType: TextInputType.number,
        style: OmnispexTypography.monoData.copyWith(fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: OmnispexTypography.label.copyWith(fontSize: 10),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          fillColor: OmnispexColors.surfaceElevated,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: OmnispexColors.border)),
        ),
        onChanged: onChanged,
      ),
    );
  }

  void _updateTarget(
    WidgetRef ref,
    int idx,
    ArchetypeEntryUi entry, {
    int? toughness,
    int? save,
    int? invuln,
    int? wounds,
    int? models,
  }) {
    final list = List<ArchetypeEntryUi>.from(ref.read(customArchetypesProvider));
    final t = entry.target;

    final updatedTarget = UnitUiProfile(
      name: t.name,
      toughness: toughness ?? t.toughness,
      save: save ?? t.save,
      invuln: invuln ?? t.invuln,
      fnp: t.fnp,
      woundsPerModel: wounds ?? t.woundsPerModel,
      modelCount: models ?? t.modelCount,
      keywords: t.keywords,
      defensiveAbilities: t.defensiveAbilities,
    );

    list[idx] = ArchetypeEntryUi(
      id: entry.id,
      label: entry.label,
      description: entry.description,
      target: updatedTarget,
    );

    ref.read(customArchetypesProvider.notifier).state = list;
  }
}
