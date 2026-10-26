import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/simulation_models.dart';
import '../providers/app_state_provider.dart';
import '../services/auth_service.dart';
import '../services/bsdata_service.dart';
import '../services/faction_registry.dart';
import '../services/personal_data_service.dart';
import '../services/simulation_service.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';
import '../widgets/stat_badge.dart';
import '../widgets/tactical_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  DeviceCredentials? _credentials;
  bool _isCheckingCatalog = false;
  bool _isCheckingMfm = false;
  bool _isSyncingCloud = false;
  String _factionFilter = '';
  final Set<String> _downloadingSlugs = {};

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    try {
      final creds = await AuthService.getOrCreateCredentials();
      if (mounted) {
        setState(() {
          _credentials = creds;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(catalogueRevisionEpochProvider);
    final iterations = ref.watch(simulationIterationsProvider);
    final confidence = ref.watch(confidenceThresholdProvider);
    final archetypes = ref.watch(customArchetypesProvider);

    final filteredFactions = FactionRegistry.allFactions.where((f) {
      if (_factionFilter.trim().isEmpty) return true;
      return f.name.toLowerCase().contains(_factionFilter.trim().toLowerCase()) ||
          f.slug.toLowerCase().contains(_factionFilter.trim().toLowerCase());
    }).toList();

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
                      Text("Client Authentication, Lazy BSData Ingestion & Simulation Benchmarks", style: OmnispexTypography.bodyMuted),
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
                      ref.read(customArchetypesProvider.notifier).state =
                          List.from(SimulationService.defaultArchetypes);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Settings restored to defaults."),
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
                    Text(
                      "Monte Carlo Iteration Count (Discrete Wound Allocation Rollouts):",
                      style: OmnispexTypography.label.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildIterationChip(ref, 2500, "2,500 (FAST)", iterations),
                        _buildIterationChip(ref, 10000, "10,000 (STANDARD)", iterations),
                        _buildIterationChip(ref, 25000, "25,000 (TOURNAMENT)", iterations),
                        _buildIterationChip(ref, 50000, "50,000 (LAB BENCHMARK)", iterations),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Defensive Elimination Confidence Interval:",
                      style: OmnispexTypography.label.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildConfidenceChip(ref, 80, "80% (AGGRESSIVE)", confidence),
                        _buildConfidenceChip(ref, 90, "90% (BALANCED)", confidence),
                        _buildConfidenceChip(ref, 95, "95% (STRICT / COMPETITIVE)", confidence),
                        _buildConfidenceChip(ref, 99, "99% (CONSERVATIVE)", confidence),
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

              // 3. Game Data & Factions Manager (Lazy Ingestion Architecture)
              TacticalCard(
                title: "3. WARHAMMER 11E GAME DATA & PROVENANCE",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Game data is downloaded lazily per-faction directly to this client. Munitorum Field Manual (MFM) points are universal and checked on startup. Only active factions are held in RAM.",
                      style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 12),
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
                          label: "CACHED FACTIONS",
                          value: "${BsDataService.cachedFactionSlugs.length} / ${FactionRegistry.allFactions.length}",
                          accentColor: OmnispexColors.greenKill,
                        ),
                        StatBadge(
                          label: "ACTIVE IN RAM",
                          value: "${BsDataService.loadedFactionsMap.length} Faction(s)",
                          accentColor: OmnispexColors.cyan,
                        ),
                      ],
                    ),
                    if (BsDataService.updateStatusMessage != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: OmnispexColors.cyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: OmnispexColors.cyan.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: OmnispexColors.cyan),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                BsDataService.updateStatusMessage!,
                                style: OmnispexTypography.monoData.copyWith(fontSize: 11, color: OmnispexColors.cyan),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: _isCheckingCatalog
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: OmnispexColors.background),
                                )
                              : const Icon(Icons.sync, size: 14),
                          label: Text(
                            "CHECK 11E CATALOG UPDATES",
                            style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.background),
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: OmnispexColors.cyan),
                          onPressed: _isCheckingCatalog
                              ? null
                              : () async {
                                  setState(() => _isCheckingCatalog = true);
                                  await BsDataService.checkForCatalogUpdates();
                                  if (mounted) setState(() => _isCheckingCatalog = false);
                                },
                        ),
                        OutlinedButton.icon(
                          icon: _isCheckingMfm
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: OmnispexColors.purple),
                                )
                              : const Icon(Icons.price_check, size: 14),
                          label: Text(
                            "CHECK MFM POINTS UPDATES",
                            style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.purple),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: OmnispexColors.purple),
                          ),
                          onPressed: _isCheckingMfm
                              ? null
                              : () async {
                                  setState(() => _isCheckingMfm = true);
                                  final hasUpdate = await BsDataService.checkForMfmUpdates();
                                  if (mounted) {
                                    setState(() => _isCheckingMfm = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(hasUpdate
                                            ? "New MFM points update detected upstream!"
                                            : "Munitorum Field Manual points are up to date (v1.6)."),
                                        backgroundColor: OmnispexColors.surfaceElevated,
                                      ),
                                    );
                                  }
                                },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.upload_file, size: 14),
                          label: Text(
                            "IMPORT CUSTOM BSDATA JSON",
                            style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.amber),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: OmnispexColors.amber),
                          ),
                          onPressed: () => _showImportCatalogueDialog(context, ref),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Faction Manager Search & Feed
                    Text("MANAGE ALL 35 FACTIONS INDIVIDUALLY:", style: OmnispexTypography.label.copyWith(fontSize: 11)),
                    const SizedBox(height: 8),
                    TextField(
                      style: OmnispexTypography.monoData.copyWith(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "Filter factions (e.g. 'Orks', 'Space Marines', 'Tyranids')...",
                        hintStyle: OmnispexTypography.bodyMuted.copyWith(fontSize: 11),
                        prefixIcon: const Icon(Icons.search, size: 16, color: OmnispexColors.cyan),
                        fillColor: OmnispexColors.surfaceElevated,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: OmnispexColors.border)),
                      ),
                      onChanged: (val) => setState(() => _factionFilter = val),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      constraints: const BoxConstraints(maxHeight: 360),
                      decoration: BoxDecoration(
                        color: OmnispexColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: OmnispexColors.border),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredFactions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: OmnispexColors.border),
                        itemBuilder: (ctx, idx) {
                          final f = filteredFactions[idx];
                          final isCached = BsDataService.isFactionCached(f.slug);
                          final isDownloading = _downloadingSlugs.contains(f.slug);

                          return ListTile(
                            dense: true,
                            leading: Icon(
                              isCached ? Icons.check_circle : Icons.cloud_outlined,
                              color: isCached ? OmnispexColors.greenKill : OmnispexColors.textMuted,
                              size: 18,
                            ),
                            title: Text(f.name, style: OmnispexTypography.monoData.copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
                            subtitle: Text("~${f.expectedUnits} datasheets • ${f.remoteFile}", style: OmnispexTypography.bodyMuted.copyWith(fontSize: 10)),
                            trailing: isDownloading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: OmnispexColors.cyan))
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isCached) ...[
                                        TextButton(
                                          child: Text("RE-FETCH", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.cyan)),
                                          onPressed: () async {
                                            setState(() => _downloadingSlugs.add(f.slug));
                                            await BsDataService.downloadAndCacheFaction(f.slug, force: true);
                                            ref.read(catalogueRevisionEpochProvider.notifier).state++;
                                            if (mounted) setState(() => _downloadingSlugs.remove(f.slug));
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 16, color: OmnispexColors.redIneffective),
                                          tooltip: "Delete local cache",
                                          onPressed: () async {
                                            await BsDataService.deleteFactionCache(f.slug);
                                            ref.read(catalogueRevisionEpochProvider.notifier).state++;
                                            if (mounted) setState(() {});
                                          },
                                        ),
                                      ] else ...[
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.download, size: 12),
                                          label: Text("DOWNLOAD", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 9, color: OmnispexColors.background)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: OmnispexColors.cyan,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                          onPressed: () async {
                                            setState(() => _downloadingSlugs.add(f.slug));
                                            await BsDataService.downloadAndCacheFaction(f.slug);
                                            ref.read(catalogueRevisionEpochProvider.notifier).state++;
                                            if (mounted) setState(() => _downloadingSlugs.remove(f.slug));
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Cloud-Authoritative User Store & Multi-Device Pairing
              TacticalCard(
                title: "4. CLOUD-AUTHORITATIVE ACCOUNT & MULTI-DEVICE PAIRING",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your army rosters, wishlists, and match histories are cloud-authoritative and synchronized via Cloudflare D1 edge database with cryptographic bearer tokens. Local storage acts strictly as an offline read mirror.",
                      style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    if (_credentials != null) ...[
                      Container(
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
                                Text("DEVICE ACCOUNT PAIRING KEY:", style: OmnispexTypography.label.copyWith(fontSize: 11, color: OmnispexColors.cyan)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: OmnispexColors.greenKill.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text("AUTHENTICATED", style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 9, color: OmnispexColors.greenKill)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              _credentials!.accountKey,
                              style: OmnispexTypography.monoData.copyWith(fontSize: 12, color: OmnispexColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Copy this key to pair your rosters & wishlists seamlessly to another phone, tablet, or browser.",
                              style: OmnispexTypography.bodyMuted.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.copy, size: 14),
                          label: Text(
                            "COPY ACCOUNT PAIRING KEY",
                            style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.background),
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: OmnispexColors.cyan),
                          onPressed: _credentials == null
                              ? null
                              : () {
                                  Clipboard.setData(ClipboardData(text: _credentials!.accountKey));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Account Pairing Key copied to clipboard!"),
                                      backgroundColor: OmnispexColors.surfaceElevated,
                                    ),
                                  );
                                },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.devices, size: 14),
                          label: Text(
                            "PAIR ANOTHER DEVICE / IMPORT KEY",
                            style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.cyan),
                          ),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: OmnispexColors.cyan)),
                          onPressed: () => _showPairDeviceDialog(context, ref),
                        ),
                        ElevatedButton.icon(
                          icon: _isSyncingCloud
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: OmnispexColors.background),
                                )
                              : const Icon(Icons.cloud_upload, size: 14),
                          label: Text(
                            "FORCE SYNC TO CLOUD NOW",
                            style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.background),
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: OmnispexColors.greenKill),
                          onPressed: _isSyncingCloud
                              ? null
                              : () async {
                                  setState(() => _isSyncingCloud = true);
                                  try {
                                    final store = ref.read(personalStoreProvider);
                                    await PersonalDataService.savePersonalStore(store);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("All army rosters and wishlists synchronized to Cloudflare edge!"),
                                          backgroundColor: OmnispexColors.surfaceElevated,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) setState(() => _isSyncingCloud = false);
                                  }
                                },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download, size: 14),
                          label: Text(
                            "EXPORT PERSONAL BACKUP JSON",
                            style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.textPrimary),
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
                            style: OmnispexTypography.monoStatBadge.copyWith(fontSize: 10, color: OmnispexColors.amber),
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

  void _showPairDeviceDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmnispexColors.surfaceCard,
        title: Text("PAIR DEVICE WITH ACCOUNT KEY", style: OmnispexTypography.h3),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Enter your Account Key (formatted as 'USER_ID:SECRET_KEY') from another device to load and synchronize your cloud rosters:",
                style: OmnispexTypography.bodyMuted.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                style: OmnispexTypography.monoData.copyWith(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Paste usr_...:sec_... key here',
                ),
              ),
            ],
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
            onPressed: () async {
              final key = ctrl.text.trim();
              final success = await AuthService.importCredentials(key);
              if (success) {
                await _loadCredentials();
                await ref.read(personalStoreProvider.notifier).loadFromDisk();
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Account paired! Roster and wishlist data synced from cloud."),
                      backgroundColor: OmnispexColors.surfaceElevated,
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Invalid Account Key or cloud verification failed."),
                      backgroundColor: OmnispexColors.redIneffective,
                    ),
                  );
                }
              }
            },
            child: const Text("PAIR & SYNC"),
          ),
        ],
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
