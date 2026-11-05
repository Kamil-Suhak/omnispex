import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state_provider.dart';
import '../services/auth_service.dart';
import '../services/personal_data_service.dart';
import '../theme/omnispex_colors.dart';
import '../theme/omnispex_typography.dart';

class AccessKeyVaultDialog extends ConsumerStatefulWidget {
  const AccessKeyVaultDialog({super.key});

  @override
  ConsumerState<AccessKeyVaultDialog> createState() =>
      _AccessKeyVaultDialogState();
}

class _AccessKeyVaultDialogState extends ConsumerState<AccessKeyVaultDialog> {
  final TextEditingController _inputController = TextEditingController();
  String _currentKey = '';
  String _statusMessage = '';
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final creds = await AuthService.getOrCreateCredentials();
    if (mounted) {
      setState(() {
        _currentKey = creds.accessKey;
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _applyInputKey() async {
    final candidate = _inputController.text.trim();
    if (candidate.isEmpty) return;
    setState(() {
      _isBusy = true;
      _statusMessage = '';
    });
    final ok = await AuthService.importCredentials(candidate);
    if (!ok) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _statusMessage = 'Invalid key format (minimum 16 alphanumeric chars).';
        });
      }
      return;
    }
    await ref.read(personalStoreProvider.notifier).loadFromDisk();
    if (PersonalDataService.killTeamRosters.isNotEmpty) {
      ref.read(killTeamRostersProvider.notifier).state =
          List.from(PersonalDataService.killTeamRosters);
    }
    await _loadKey();
    if (mounted) {
      setState(() {
        _isBusy = false;
        _statusMessage = 'Key active. Remote rosters & wishlists synchronized.';
      });
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _isBusy = true;
      _statusMessage = '';
    });
    final store = ref.read(personalStoreProvider);
    final pushed = await PersonalDataService.pushToCloudSync(
      accessKey: _currentKey,
      store: store,
    );
    if (mounted) {
      setState(() {
        _isBusy = false;
        _statusMessage = pushed
            ? 'Synchronized to remote D1 tables.'
            : 'Saved locally (remote worker unreachable).';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: OmnispexColors.surfaceCard,
      title: Text('ACCESS KEY', style: OmnispexTypography.h2),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ACTIVE DEVICE KEY', style: OmnispexTypography.label),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: OmnispexColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: OmnispexColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _currentKey.isEmpty ? 'Generating...' : _currentKey,
                      style: OmnispexTypography.monoData.copyWith(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy Key',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: _currentKey.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: _currentKey));
                            setState(() {
                              _statusMessage = 'Key copied to clipboard.';
                            });
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('RESTORE KEY FROM ANOTHER DEVICE',
                style: OmnispexTypography.label),
            const SizedBox(height: 8),
            TextField(
              controller: _inputController,
              style: OmnispexTypography.monoData.copyWith(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'omnispex_...',
                isDense: true,
              ),
            ),
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage,
                style: OmnispexTypography.bodyMuted.copyWith(
                  color: OmnispexColors.accent,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : _syncNow,
          child: const Text('SYNC REMOTE'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CLOSE'),
        ),
        ElevatedButton(
          onPressed: _isBusy ? null : _applyInputKey,
          child: const Text('LOAD KEY'),
        ),
      ],
    );
  }
}
