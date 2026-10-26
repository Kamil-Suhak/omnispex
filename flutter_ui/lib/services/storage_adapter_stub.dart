Future<String?> readPersonalStoreRaw() async => null;
Future<void> writePersonalStoreRaw(String content) async {}

Future<String?> readCredentialsRaw() async => null;
Future<void> writeCredentialsRaw(String content) async {}

Future<String?> readFactionCacheRaw(String slug) async => null;
Future<void> writeFactionCacheRaw(String slug, String content) async {}
Future<void> deleteFactionCacheRaw(String slug) async {}
Future<List<String>> listCachedFactionSlugs() async => [];

Future<String?> readMfmCacheRaw() async => null;
Future<void> writeMfmCacheRaw(String content) async {}
