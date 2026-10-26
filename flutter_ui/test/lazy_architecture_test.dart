import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/services/auth_service.dart';
import 'package:flutter_ui/services/bsdata_service.dart';
import 'package:flutter_ui/services/faction_registry.dart';
import 'package:flutter_ui/services/storage_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lazy Game Data & In-Memory Scoping Architecture', () {
    test('FactionRegistry contains all 35 Warhammer 40k 11e factions', () {
      expect(FactionRegistry.allFactions.length, equals(35));

      final orks = FactionRegistry.find('orks');
      expect(orks, isNotNull);
      expect(orks!.name, equals('Xenos - Orks'));
      expect(orks.remoteFile, equals('Orks.json'));
      expect(orks.expectedUnits, equals(65));

      final sm = FactionRegistry.find('space-marines');
      expect(sm, isNotNull);
      expect(sm!.name, equals('Adeptus Astartes - Space Marines'));

      final nec = FactionRegistry.find('necrons');
      expect(nec, isNotNull);
      expect(nec!.name, equals('Xenos - Necrons'));
    });

    test('BsDataService initializes universal MFM points upfront', () async {
      await BsDataService.initOnStartup();
      expect(BsDataService.provenance.mfmVersion, equals('1.6'));
      expect(BsDataService.provenance.edition, contains('11th Edition'));
    });

    test('BsDataService lazy faction download, disk caching, and cache deletion', () async {
      final orkMeta = FactionRegistry.find('orks')!;

      // Download and cache Orks
      final downloaded = await BsDataService.downloadAndCacheFaction(orkMeta.slug);
      expect(downloaded, isNotNull);
      expect(downloaded!.name, contains('Orks'));
      expect(BsDataService.isFactionCached(orkMeta.slug), isTrue);

      // Verify cached content exists on disk / storage adapter
      final cachedRaw = await readFactionCacheRaw(orkMeta.slug);
      expect(cachedRaw, isNotNull);
      expect(cachedRaw!.isNotEmpty, isTrue);

      // Delete cache
      await BsDataService.deleteFactionCache(orkMeta.slug);
      expect(BsDataService.isFactionCached(orkMeta.slug), isFalse);
      final afterDelete = await readFactionCacheRaw(orkMeta.slug);
      expect(afterDelete, isNull);

      // Re-download for subsequent scoping tests
      await BsDataService.downloadAndCacheFaction(orkMeta.slug);
    });

    test('List Builder memory scope: strictly 1 faction loaded in RAM', () async {
      // Load Space Marines first
      await BsDataService.loadFactionIntoMemory('space-marines');

      // Now scope to Orks for army list building
      final scoped = await BsDataService.scopeMemoryToListBuilder('orks');
      expect(scoped, isNotNull);
      expect(scoped!.name, contains('Orks'));

      // Verify that RAM strictly holds ONLY 1 faction
      expect(BsDataService.loadedFactionsMap.length, equals(1));
      expect(BsDataService.loadedFactionsMap.containsKey(scoped.id), isTrue);
    });

    test('Live Match memory scope: at most 2 factions loaded in RAM', () async {
      // Scope to Attacker: Orks, Defender: Space Marines
      await BsDataService.scopeMemoryToMatch('orks', 'space-marines');

      expect(BsDataService.loadedFactionsMap.length, lessThanOrEqualTo(2));
      final names = BsDataService.loadedFactionsMap.values.map((f) => f.name).toList();
      for (final n in names) {
        expect(n.contains('Orks') || n.contains('Space Marines'), isTrue);
      }
    });

    test('Datasheet Browser memory scope: strictly 1 browsed faction in RAM', () async {
      final browserFaction = await BsDataService.scopeMemoryToBrowser('necrons');
      expect(browserFaction, isNotNull);
      expect(browserFaction!.name, contains('Necrons'));

      // Verify only 1 faction is in RAM
      expect(BsDataService.loadedFactionsMap.length, equals(1));
      expect(BsDataService.loadedFactionsMap.containsKey(browserFaction.id), isTrue);
    });
  });

  group('Client Cryptographic Authentication & Account Pairing', () {
    test('DeviceCredentials generates valid format and account pairing key', () async {
      final creds = await AuthService.getOrCreateCredentials();
      expect(creds.userId.startsWith('usr_'), isTrue);
      expect(creds.secretKey.startsWith('sec_'), isTrue);
      expect(creds.secretKey.length, greaterThanOrEqualTo(16));

      final pairingKey = creds.accountKey;
      expect(pairingKey, contains(':'));

      final parsed = DeviceCredentials.tryParseAccountKey(pairingKey);
      expect(parsed, isNotNull);
      expect(parsed!.userId, equals(creds.userId));
      expect(parsed.secretKey, equals(creds.secretKey));
    });

    test('AuthService generates Bearer authorization headers', () async {
      final creds = await AuthService.getOrCreateCredentials();
      final headers = AuthService.getAuthHeaders(creds);

      expect(headers['Authorization'], equals('Bearer ${creds.secretKey}'));
      expect(headers['Content-Type'], equals('application/json'));
    });
  });
}

