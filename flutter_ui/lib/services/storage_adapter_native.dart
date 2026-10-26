import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<Directory> _resolveStorageDir() async {
  try {
    return await getApplicationSupportDirectory();
  } catch (_) {
    return Directory.systemTemp;
  }
}

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
