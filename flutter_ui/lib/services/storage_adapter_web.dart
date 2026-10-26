import 'package:web/web.dart' as web;

const _kMainKey = 'omnispex_personal_store_v2';
const _kBackupKey = 'omnispex_personal_store_v2_bak';

Future<String?> readPersonalStoreRaw() async {
  try {
    final storage = web.window.localStorage;
    final main = storage.getItem(_kMainKey);
    if (main != null && main.trim().isNotEmpty) {
      return main;
    }
    final bak = storage.getItem(_kBackupKey);
    if (bak != null && bak.trim().isNotEmpty) {
      return bak;
    }
  } catch (_) {}
  return null;
}

Future<void> writePersonalStoreRaw(String content) async {
  try {
    final storage = web.window.localStorage;
    final prev = storage.getItem(_kMainKey);
    if (prev != null && prev.trim().isNotEmpty) {
      storage.setItem(_kBackupKey, prev);
    }
    storage.setItem(_kMainKey, content);
  } catch (_) {}
}
