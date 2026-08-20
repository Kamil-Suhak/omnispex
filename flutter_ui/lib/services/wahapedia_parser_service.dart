import '../models/simulation_models.dart';

class WahapediaParserService {
  static const String sampleTerminators = '''
Storm bolter\t24"\t2\t3+\t4\t0\t1\t[RAPID FIRE 2]
Cyclone missile launcher - frag\t36"\t2D6\t3+\t4\t0\t1\t[BLAST]
Cyclone missile launcher - krak\t36"\t2\t3+\t9\t-2\tD6\t-
Power fist\tMelee\t3\t3+\t8\t-2\t2\t-
Chainfist\tMelee\t3\t4+\t8\t-2\t2\t[ANTI-VEHICLE 3+]
''';

  static const String sampleLemanRuss = '''
Leman Russ battle cannon\t48"\tD6+3\t4+\t10\t-1\t3\t[BLAST]
Lascannon\t48"\t1\t4+\t12\t-3\tD6+1\t[HEAVY]
Heavy bolter\t36"\t3\t4+\t5\t-1\t2\t[SUSTAINED HITS 1, HEAVY]
Plasma cannon - standard\t36"\tD3\t4+\t7\t-2\t1\t[BLAST, HEAVY]
''';

  static const String sampleEradicators = '''
Melta rifle\t18"\t1\t3+\t9\t-4\tD6\t[MELTA 2]
Heavy melta rifle\t18"\t1\t3+\t9\t-4\tD6+1\t[HEAVY, MELTA 2]
Multi-melta\t18"\t2\t3+\t9\t-4\tD6\t[HEAVY, MELTA 2]
''';

  static List<WeaponUiProfile> parseWeapons(String text) {
    final weapons = <WeaponUiProfile>[];
    final lines = text.split('\n');

    final weaponRegex = RegExp(
      r'^(?<name>[^"0-9\t\[]+?)(?:\s*\[(?<name_kw>[^\]]+)\])?\s+(?<range>\d+"?|MELEE|N/A|-)\s+(?<a>\d+|D\d+(?:\+\d+)?|2D\d+(?:\+\d+)?|-)\s+(?<skill>\d+\+|N/A|-)\s+(?<s>\d+|-)\s+(?<ap>-?\d+|-)\s+(?<d>\d+|D\d+(?:\+\d+)?|2D\d+(?:\+\d+)?|-)(?:\s+(?<end_kw>.*))?$',
      caseSensitive: false,
    );

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty ||
          line.toUpperCase().startsWith("RANGED WEAPONS") ||
          line.toUpperCase().startsWith("MELEE WEAPONS") ||
          line.toUpperCase().startsWith("RANGE") ||
          line.toUpperCase().startsWith("WEAPON")) {
        continue;
      }

      final match = weaponRegex.firstMatch(line);
      if (match != null) {
        final fullName = match.namedGroup('name')?.trim() ?? "Custom Weapon";
        final rangeRaw = match.namedGroup('range')?.trim() ?? "0";
        final isMelee = rangeRaw.toUpperCase() == "MELEE" || rangeRaw == "-" || rangeRaw == "N/A" || rangeRaw == "0";
        final range = isMelee ? 0 : int.tryParse(rangeRaw.replaceAll('"', '')) ?? 24;

        final attacks = match.namedGroup('a')?.trim() ?? "1";
        final skillRaw = match.namedGroup('skill')?.trim() ?? "3+";
        final skill = (skillRaw == "N/A" || skillRaw == "-") ? 7 : (int.tryParse(skillRaw.replaceAll('+', '')) ?? 3);

        final sRaw = match.namedGroup('s')?.trim() ?? "4";
        final strength = int.tryParse(sRaw) ?? 4;

        final apRaw = match.namedGroup('ap')?.trim() ?? "0";
        final ap = (int.tryParse(apRaw.replaceAll('-', '')) ?? 0).abs();

        final damage = match.namedGroup('d')?.trim() ?? "1";

        final abilities = <String>[];
        if (skill == 7) abilities.add("Torrent");

        final nameKw = match.namedGroup('name_kw');
        final endKw = match.namedGroup('end_kw');

        if (nameKw != null) {
          _extractAbilities(nameKw, abilities);
        }
        if (endKw != null) {
          _extractAbilities(endKw, abilities);
        }

        String mainName = fullName;
        String profileName = isMelee ? "Melee" : "Standard";
        if (fullName.contains(" - ")) {
          final parts = fullName.split(" - ");
          mainName = parts[0].trim();
          profileName = parts.sublist(1).join(" - ").trim();
        }

        weapons.add(WeaponUiProfile(
          name: mainName,
          profileName: profileName,
          range: range,
          attacks: attacks,
          skill: skill == 7 ? 3 : skill,
          strength: strength,
          ap: ap,
          damage: damage,
          abilities: abilities,
        ));
      }
    }

    return weapons;
  }

  static void _extractAbilities(String raw, List<String> list) {
    final cleaned = raw.replaceAll('[', '').replaceAll(']', '').replaceAll('(', '').replaceAll(')', '');
    final tokens = cleaned.split(RegExp(r'[,;]'));

    for (final token in tokens) {
      final t = token.trim();
      if (t.isEmpty || t == "-") continue;
      final upper = t.toUpperCase();

      if (upper == "TORRENT") {
        if (!list.contains("Torrent")) list.add("Torrent");
      } else if (upper == "LETHAL HITS") {
        if (!list.contains("Lethal Hits")) list.add("Lethal Hits");
      } else if (upper == "DEVASTATING WOUNDS") {
        if (!list.contains("Devastating Wounds")) list.add("Devastating Wounds");
      } else if (upper.contains("TWIN-LINKED") || upper.contains("TWIN LINKED")) {
        if (!list.contains("Twin-Linked")) list.add("Twin-Linked");
      } else if (upper == "BLAST") {
        if (!list.contains("Blast")) list.add("Blast");
      } else if (upper == "IGNORES COVER") {
        if (!list.contains("Ignores Cover")) list.add("Ignores Cover");
      } else if (upper == "HEAVY") {
        if (!list.contains("Heavy")) list.add("Heavy");
      } else if (upper == "LANCE") {
        if (!list.contains("Lance")) list.add("Lance");
      } else if (upper == "HAZARDOUS") {
        if (!list.contains("Hazardous")) list.add("Hazardous");
      } else if (upper.startsWith("SUSTAINED HITS")) {
        final val = int.tryParse(upper.replaceAll("SUSTAINED HITS", "").trim()) ?? 1;
        final formatted = "Sustained Hits $val";
        if (!list.contains(formatted)) list.add(formatted);
      } else if (upper.startsWith("RAPID FIRE")) {
        final val = int.tryParse(upper.replaceAll("RAPID FIRE", "").trim()) ?? 1;
        final formatted = "Rapid Fire $val";
        if (!list.contains(formatted)) list.add(formatted);
      } else if (upper.startsWith("MELTA")) {
        final val = int.tryParse(upper.replaceAll("MELTA", "").trim()) ?? 2;
        final formatted = "Melta $val";
        if (!list.contains(formatted)) list.add(formatted);
      } else {
        if (!list.contains(t)) list.add(t);
      }
    }
  }

  static UnitUiProfile? parseUnit(String text) {
    final tRegex = RegExp(r'T:\s*(\d+)', caseSensitive: false);
    final svRegex = RegExp(r'SV:\s*(\d+)\+?', caseSensitive: false);
    final wRegex = RegExp(r'W:\s*(\d+)', caseSensitive: false);
    final invRegex = RegExp(r'INV(?:ULN)?:\s*(\d+)\+?', caseSensitive: false);
    final modelsRegex = RegExp(r'MODELS?:\s*(\d+)', caseSensitive: false);

    final tMatch = tRegex.firstMatch(text);
    final svMatch = svRegex.firstMatch(text);
    final wMatch = wRegex.firstMatch(text);

    if (tMatch == null || svMatch == null || wMatch == null) return null;

    final t = int.tryParse(tMatch.group(1)!) ?? 4;
    final sv = int.tryParse(svMatch.group(1)!) ?? 3;
    final w = int.tryParse(wMatch.group(1)!) ?? 2;

    final invMatch = invRegex.firstMatch(text);
    final inv = invMatch != null ? int.tryParse(invMatch.group(1)!) : null;

    final modelsMatch = modelsRegex.firstMatch(text);
    final models = modelsMatch != null ? (int.tryParse(modelsMatch.group(1)!) ?? 5) : 5;

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final name = lines.isNotEmpty ? lines.first : "Imported Unit";

    return UnitUiProfile(
      name: name,
      toughness: t,
      save: sv,
      invuln: inv,
      woundsPerModel: w,
      modelCount: models,
      keywords: ["IMPORTED"],
    );
  }
}
