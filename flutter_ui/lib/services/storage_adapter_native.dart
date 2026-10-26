import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<Directory> _resolveStorageDir() async {
  try {
    return await getApplicationSupportDirectory();
  } catch (_) {
    return Directory.systemTemp;
  }
}

Future<Directory> _resolveFactionsDir() async {
  final base = await _resolveStorageDir();
  final factionsDir = Directory('${base.path}/omnispex_factions');
  if (!await factionsDir.exists()) {
    await factionsDir.create(recursive: true);
  }
  return factionsDir;
}

// User Personal Store (Offline Safety Mirror)
Future<String?> readPersonalStoreRaw() async {
  try {
    final dir = await _resolveStorageDir();
    final mainFile = File('${dir.path}/omnispex_personal_store_v2.json');
    if (await mainFile.exists()) {
      final text = await mainFile.readAsString();
      if (text.trim().isNotEmpty) return text;
    }
    final bakFile = File('${dir.path}/omnispex_personal_store_v2.json.bak');
    if (await bakFile.exists()) {
      final text = await bakFile.readAsString();
      if (text.trim().isNotEmpty) return text;
    }
  } catch (_) {}
  return null;
}

Future<void> writePersonalStoreRaw(String content) async {
  try {
    final dir = await _resolveStorageDir();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final mainFile = File('${dir.path}/omnispex_personal_store_v2.json');
    final bakFile = File('${dir.path}/omnispex_personal_store_v2.json.bak');
    final tmpFile = File('${dir.path}/omnispex_personal_store_v2.json.tmp');

    if (await mainFile.exists()) {
      try {
        await mainFile.copy(bakFile.path);
      } catch (_) {}
    }

    await tmpFile.writeAsString(content, flush: true);
    await tmpFile.rename(mainFile.path);
  } catch (_) {}
}

// Device Auth Credentials
Future<String?> readCredentialsRaw() async {
  try {
    final dir = await _resolveStorageDir();
    final file = File('${dir.path}/omnispex_device_auth_v1.json');
    if (await file.exists()) {
      final text = await file.readAsString();
      if (text.trim().isNotEmpty) return text;
    }
  } catch (_) {}
  return null;
}

Future<void> writeCredentialsRaw(String content) async {
  try {
    final dir = await _resolveStorageDir();
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/omnispex_device_auth_v1.json');
    await file.writeAsString(content, flush: true);
  } catch (_) {}
}

// Faction Caching
Future<String?> readFactionCacheRaw(String slug) async {
  try {
    final dir = await _resolveFactionsDir();
    final file = File('${dir.path}/$slug.json');
    if (await file.exists()) {
      final text = await file.readAsString();
      if (text.trim().isNotEmpty) return text;
    }
  } catch (_) {}
  return null;
}

Future<void> writeFactionCacheRaw(String slug, String content) async {
  try {
    final dir = await _resolveFactionsDir();
    final file = File('${dir.path}/$slug.json');
    await file.writeAsString(content, flush: true);
  } catch (_) {}
}

Future<void> deleteFactionCacheRaw(String slug) async {
  try {
    final dir = await _resolveFactionsDir();
    final file = File('${dir.path}/$slug.json');
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {}
}

Future<List<String>> listCachedFactionSlugs() async {
  try {
    final dir = await _resolveFactionsDir();
    if (!await dir.exists()) return [];
    final entities = await dir.list().toList();
    final slugs = <String>[];
    for (final e in entities) {
      if (e is File && e.path.endsWith('.json')) {
        final filename = e.uri.pathSegments.last;
        slugs.add(filename.replaceAll('.json', ''));
      }
    }
    return slugs;
  } catch (_) {
    return [];
  }
}

// MFM Cache
Future<String?> readMfmCacheRaw() async {
  try {
    final dir = await _resolveStorageDir();
    final file = File('${dir.path}/omnispex_mfm_cache_v1.json');
    if (await file.exists()) {
      final text = await file.readAsString();
      if (text.trim().isNotEmpty) return text;
    }
  } catch (_) {}
  return null;
}

Future<void> writeMfmCacheRaw(String content) async {
  try {
    final dir = await _resolveStorageDir();
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/omnispex_mfm_cache_v1.json');
    await file.writeAsString(content, flush: true);
  } catch (_) {}
}
