import 'dart:convert';
import 'package:flutter_ui/models/bsdata_models.dart';
import 'package:flutter_ui/services/bsdata_service.dart';
import 'package:flutter_ui/services/storage_adapter.dart';

class TestFixtures {
  static final Map<String, dynamic> compliantChaptersJson = {
    'id': 'compliant-chapters',
    'slug': 'compliant-chapters',
    'name': 'Adeptus Astartes - Compliant Chapters',
    'armyRules': [],
    'detachments': [
      {
        'id': 'det-gladius',
        'name': 'Gladius Task Force',
        'dpCost': 3,
        'forceDispositions': [],
        'rules': [],
        'enhancements': [],
      }
    ],
    'units': [
      {
        'id': 'sm-term-1',
        'name': 'Terminator Squad',
        'faction': 'Adeptus Astartes',
        'pointsCost': 175,
        'categories': ['Infantry', 'Imperium'],
        'weapons': [
          {
            'name': 'Storm Bolter',
            'profileName': 'Standard',
            'range': 24,
            'attacks': '2',
            'skill': 3,
            'strength': 4,
            'ap': 0,
            'damage': '1',
            'abilities': [],
          }
        ],
        'abilities': [],
        'movement': '5"',
        'leadership': '6+',
        'objectiveControl': 1,
        'unitProfile': {
          'name': 'Terminator Squad',
          'toughness': 5,
          'save': 2,
          'invuln': 4,
          'woundsPerModel': 3,
          'modelCount': 5,
          'keywords': ['Infantry', 'Imperium', 'Terminator'],
          'defensiveAbilities': [],
        },
      }
    ],
  };

  static final Map<String, dynamic> orksJson = {
    'id': 'orks',
    'slug': 'orks',
    'name': 'Xenos - Orks',
    'armyRules': [],
    'detachments': [
      {
        'id': 'det-war-horde',
        'name': 'War Horde',
        'dpCost': 3,
        'forceDispositions': [],
        'rules': [],
        'enhancements': [
          {
            'id': 'enh-killchoppa',
            'name': "Headwoppa's Killchoppa",
            'points': 15,
            'isUpgrade': false,
            'description': 'Melee weapon gains Devastating Wounds.',
          }
        ],
      }
    ],
    'units': [
      {
        'id': 'ork-bw-1',
        'name': 'Battlewagon',
        'faction': 'Orks',
        'pointsCost': 145,
        'categories': ['Vehicle', 'Transport'],
        'weapons': [],
        'abilities': [],
        'movement': '10"',
        'leadership': '7+',
        'objectiveControl': 5,
        'unitProfile': {
          'name': 'Battlewagon',
          'toughness': 12,
          'save': 3,
          'woundsPerModel': 16,
          'modelCount': 1,
          'keywords': ['Vehicle', 'Transport'],
          'defensiveAbilities': [],
        },
      }
    ],
  };

  static final Map<String, dynamic> necronsJson = {
    'id': 'necrons',
    'slug': 'necrons',
    'name': 'Xenos - Necrons',
    'armyRules': [],
    'detachments': [],
    'units': [
      {
        'id': 'nec-war-1',
        'name': 'Necron Warriors',
        'faction': 'Necrons',
        'pointsCost': 100,
        'categories': ['Infantry', 'Battleline'],
        'weapons': [],
        'abilities': [],
        'movement': '5"',
        'leadership': '7+',
        'objectiveControl': 2,
        'unitProfile': {
          'name': 'Necron Warriors',
          'toughness': 4,
          'save': 4,
          'woundsPerModel': 1,
          'modelCount': 10,
          'keywords': ['Infantry', 'Battleline'],
          'defensiveAbilities': [],
        },
      }
    ],
  };

  static final Map<String, dynamic> csmJson = {
    'id': 'chaos-space-marines',
    'slug': 'chaos-space-marines',
    'name': 'Chaos Space Marines',
    'armyRules': [],
    'detachments': [],
    'units': [
      {
        'id': 'csm-term-1',
        'name': 'Chaos Terminator Squad',
        'faction': 'Chaos Space Marines',
        'pointsCost': 185,
        'categories': ['Infantry', 'Chaos'],
        'weapons': [],
        'abilities': [],
        'movement': '5"',
        'leadership': '6+',
        'objectiveControl': 1,
        'unitProfile': {
          'name': 'Chaos Terminator Squad',
          'toughness': 5,
          'save': 2,
          'invuln': 4,
          'woundsPerModel': 3,
          'modelCount': 5,
          'keywords': ['Infantry', 'Chaos', 'Terminator'],
          'defensiveAbilities': [],
        },
      }
    ],
  };

  static final Map<String, dynamic> astraMilitarumJson = {
    'id': 'astra-militarum',
    'slug': 'astra-militarum',
    'name': 'Astra Militarum',
    'armyRules': [],
    'detachments': [],
    'units': [
      {
        'id': 'am-lrbt-1',
        'name': 'Leman Russ Battle Tank',
        'faction': 'Astra Militarum',
        'pointsCost': 180,
        'categories': ['Vehicle'],
        'weapons': [],
        'abilities': [],
        'movement': '10"',
        'leadership': '7+',
        'objectiveControl': 3,
        'unitProfile': {
          'name': 'Leman Russ Battle Tank',
          'toughness': 11,
          'save': 2,
          'woundsPerModel': 13,
          'modelCount': 1,
          'keywords': ['Vehicle'],
          'defensiveAbilities': [],
        },
      }
    ],
  };

  static Future<void> seedDiskCaches() async {
    await writeFactionCacheRaw('compliant-chapters', jsonEncode(compliantChaptersJson));
    await writeFactionCacheRaw('orks', jsonEncode(orksJson));
    await writeFactionCacheRaw('necrons', jsonEncode(necronsJson));
    await writeFactionCacheRaw('chaos-space-marines', jsonEncode(csmJson));
    await writeFactionCacheRaw('astra-militarum', jsonEncode(astraMilitarumJson));

    BsDataService.cachedFactionSlugs.addAll([
      'compliant-chapters',
      'orks',
      'necrons',
      'chaos-space-marines',
      'astra-militarum',
    ]);
  }

  static void loadInMemory() {
    final sm = BsDataFaction.fromRustJson(compliantChaptersJson);
    final orks = BsDataFaction.fromRustJson(orksJson);
    final nec = BsDataFaction.fromRustJson(necronsJson);
    final csm = BsDataFaction.fromRustJson(csmJson);
    final am = BsDataFaction.fromRustJson(astraMilitarumJson);

    BsDataService.loadedFactionsMap[sm.id] = sm;
    BsDataService.loadedFactionsMap[orks.id] = orks;
    BsDataService.loadedFactionsMap[nec.id] = nec;
    BsDataService.loadedFactionsMap[csm.id] = csm;
    BsDataService.loadedFactionsMap[am.id] = am;
  }
}
