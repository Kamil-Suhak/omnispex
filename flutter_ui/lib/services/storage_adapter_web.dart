import 'package:web/web.dart' as web;

const _kMainKey = 'omnispex_personal_store_v2';
const _kBackupKey = 'omnispex_personal_store_v2_bak';
const _kAuthKey = 'omnispex_device_auth_v1';
const _kMfmKey = 'omnispex_mfm_cache_v1';
const _kFactionPrefix = 'omnispex_faction_';

Future<String?> readPersonalStoreRaw() async {
  try {
    final storage = web.window.localStorage;
    final main = storage.getItem(_kMainKey);
    if (main != null && main.trim().isNotEmpty) return main;
    final bak = storage.getItem(_kBackupKey);
    if (bak != null && bak.trim().isNotEmpty) return bak;
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

Future<String?> readCredentialsRaw() async {
  try {
    final storage = web.window.localStorage;
    return storage.getItem(_kAuthKey);
  } catch (_) {}
  return null;
}

Future<void> writeCredentialsRaw(String content) async {
  try {
    final storage = web.window.localStorage;
    storage.setItem(_kAuthKey, content);
  } catch (_) {}
}

Future<String?> readFactionCacheRaw(String slug) async {
  try {
    final storage = web.window.localStorage;
    return storage.getItem('$_kFactionPrefix$slug');
  } catch (_) {}
  return null;
}

Future<void> writeFactionCacheRaw(String slug, String content) async {
  try {
    final storage = web.window.localStorage;
    storage.setItem('$_kFactionPrefix$slug', content);
  } catch (_) {}
}

Future<void> deleteFactionCacheRaw(String slug) async {
  try {
    final storage = web.window.localStorage;
    storage.removeItem('$_kFactionPrefix$slug');
  } catch (_) {}
}

Future<List<String>> listCachedFactionSlugs() async {
  final slugs = <String>[];
  try {
    final storage = web.window.localStorage;
    final len = storage.length;
    for (int i = 0; i < len; i++) {
      final key = storage.key(i);
      if (key != null && key.startsWith(_kFactionPrefix)) {
        slugs.add(key.substring(_kFactionPrefix.length));
      }
    }
  } catch (_) {}
  return slugs;
}

Future<String?> readMfmCacheRaw() async {
  try {
    final storage = web.window.localStorage;
    return storage.getItem(_kMfmKey);
  } catch (_) {}
  return null;
}

Future<void> writeMfmCacheRaw(String content) async {
  try {
    final storage = web.window.localStorage;
    storage.setItem(_kMfmKey, content);
  } catch (_) {}
}
