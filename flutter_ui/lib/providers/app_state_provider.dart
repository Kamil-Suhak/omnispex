import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/simulation_models.dart';
import '../services/simulation_service.dart';

final isDeepAnalyticsModeProvider = StateProvider<bool>((ref) => false);
final currentNavIndexProvider = StateProvider<int>((ref) => 0);

final customArsenalProvider = StateProvider<List<WeaponUiProfile>>((ref) => List.from(SimulationService.defaultWeapons));

final customArchetypesProvider = StateProvider<List<ArchetypeEntryUi>>((ref) => List.from(SimulationService.defaultArchetypes));

final simulationIterationsProvider = StateProvider<int>((ref) => 10000);
final confidenceThresholdProvider = StateProvider<int>((ref) => 80);

final loadedAttackerNameProvider = StateProvider<String?>((ref) => null);
final loadedDefenderNameProvider = StateProvider<String?>((ref) => null);

