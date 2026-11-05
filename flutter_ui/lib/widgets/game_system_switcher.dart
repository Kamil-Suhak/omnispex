import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/omnispex_models.dart';
import '../providers/app_state_provider.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';

class GameSystemSwitcherButton extends ConsumerWidget {
  const GameSystemSwitcherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSystem = ref.watch(activeGameSystemProvider);
    final is40k = activeSystem == GameSystemUi.warhammer40k;

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: OmnispexColors.textPrimary,
        side: const BorderSide(color: OmnispexColors.borderBright),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: Icon(
        is40k ? Icons.shield_outlined : Icons.gps_fixed,
        size: 16,
        color: OmnispexColors.accent,
      ),
      label: Text(
        is40k ? 'WARHAMMER 40,000' : 'KILL TEAM',
        style: OmnispexTypography.label.copyWith(
          color: OmnispexColors.textPrimary,
        ),
      ),
      onPressed: () => showGameSystemSelectorDialog(context, ref),
    );
  }
}

Future<void> showGameSystemSelectorDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final current = ref.read(activeGameSystemProvider);
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: OmnispexColors.surfaceCard,
        title: Text('SELECT GAME SYSTEM', style: OmnispexTypography.h2),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SystemOptionTile(
                title: 'WARHAMMER 40,000 (11TH EDITION)',
                subtitle:
                    'BSData 11e + Munitorum Field Manual • Squad Math • Army Lists',
                isSelected: current == GameSystemUi.warhammer40k,
                onTap: () {
                  ref.read(activeGameSystemProvider.notifier).state =
                      GameSystemUi.warhammer40k;
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 12),
              _SystemOptionTile(
                title: 'KILL TEAM (2024 EDITION)',
                subtitle:
                    'Shooting & Melee Strike/Parry Solver • Bespoke Operatives • Rosters',
                isSelected: current == GameSystemUi.killTeam,
                onTap: () {
                  ref.read(activeGameSystemProvider.notifier).state =
                      GameSystemUi.killTeam;
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SystemOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SystemOptionTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? OmnispexColors.surfaceElevated
              : OmnispexColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color:
                isSelected ? OmnispexColors.accent : OmnispexColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: OmnispexTypography.h3),
                  const SizedBox(height: 4),
                  Text(subtitle, style: OmnispexTypography.bodyMuted),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? OmnispexColors.accent
                  : OmnispexColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
