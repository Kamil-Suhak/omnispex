import 'package:flutter_riverpod/flutter_riverpod.dart';

final isDeepAnalyticsModeProvider = StateProvider<bool>((ref) => false);
final currentNavIndexProvider = StateProvider<int>((ref) => 0);
