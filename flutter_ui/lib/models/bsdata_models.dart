import 'simulation_models.dart';

class BsDataUnit {
  final String id;
  final String name;
  final String faction;
  final int? pointsCost;
  final UnitUiProfile unitProfile;
  final List<WeaponUiProfile> weapons;
  final List<String> abilities;
  final List<String> categories;
  final String movement;
  final String leadership;
  final int objectiveControl;

  const BsDataUnit({
    required this.id,
    required this.name,
    required this.faction,
    this.pointsCost,
    required this.unitProfile,
    required this.weapons,
    this.abilities = const [],
    this.categories = const [],
    this.movement = '6"',
    this.leadership = '6+',
    this.objectiveControl = 1,
  });

  bool get isVehicleOrMonster =>
      categories.any((c) => c.toUpperCase() == 'VEHICLE' || c.toUpperCase() == 'MONSTER') ||
      unitProfile.keywords.any((k) => k.toUpperCase() == 'VEHICLE' || k.toUpperCase() == 'MONSTER');

  bool get isCharacter =>
      categories.any((c) => c.toUpperCase() == 'CHARACTER') ||
      unitProfile.keywords.any((k) => k.toUpperCase() == 'CHARACTER');

  bool get isInfantry =>
      categories.any((c) => c.toUpperCase() == 'INFANTRY') ||
      unitProfile.keywords.any((k) => k.toUpperCase() == 'INFANTRY');
}

class BsDataFaction {
  final String id;
  final String name;
  final int? revision;
  final List<BsDataUnit> units;

  const BsDataFaction({
    required this.id,
    required this.name,
    this.revision,
    required this.units,
  });
}
