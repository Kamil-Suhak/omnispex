import 'simulation_models.dart';

// ============================================================================
// 1. ARMY LIST BUILDER & VALIDATION MODELS
// ============================================================================

enum BattleSizeUi {
  incursion,
  strikeForce,
  onslaught,
  custom;

  String toRustJson() {
    switch (this) {
      case BattleSizeUi.incursion:
        return 'incursion';
      case BattleSizeUi.strikeForce:
        return 'strike_force';
      case BattleSizeUi.onslaught:
        return 'onslaught';
      case BattleSizeUi.custom:
        return 'custom';
    }
  }

  static BattleSizeUi fromRustJson(String? raw) {
    switch (raw) {
      case 'incursion':
        return BattleSizeUi.incursion;
      case 'onslaught':
        return BattleSizeUi.onslaught;
      case 'custom':
        return BattleSizeUi.custom;
      default:
        return BattleSizeUi.strikeForce;
    }
  }

  int get defaultPointsLimit {
    switch (this) {
      case BattleSizeUi.incursion:
        return 1000;
      case BattleSizeUi.strikeForce:
        return 2000;
      case BattleSizeUi.onslaught:
        return 3000;
      case BattleSizeUi.custom:
        return 2000;
    }
  }

  int get dpLimit {
    switch (this) {
      case BattleSizeUi.incursion:
        return 2;
      case BattleSizeUi.strikeForce:
        return 3;
      case BattleSizeUi.onslaught:
      case BattleSizeUi.custom:
        return 4;
    }
  }

  int get enhancementLimit {
    switch (this) {
      case BattleSizeUi.incursion:
        return 2;
      case BattleSizeUi.strikeForce:
        return 4;
      case BattleSizeUi.onslaught:
      case BattleSizeUi.custom:
        return 6;
    }
  }

  String get label {
    switch (this) {
      case BattleSizeUi.incursion:
        return 'Incursion (1,000 pts)';
      case BattleSizeUi.strikeForce:
        return 'Strike Force (2,000 pts)';
      case BattleSizeUi.onslaught:
        return 'Onslaught (3,000 pts)';
      case BattleSizeUi.custom:
        return 'Custom Size';
    }
  }
}

class SelectedDetachmentUi {
  final String id;
  final String name;
  final int dpCost;
  final String? uniqueTag;

  const SelectedDetachmentUi({
    required this.id,
    required this.name,
    this.dpCost = 2,
    this.uniqueTag,
  });

  factory SelectedDetachmentUi.fromRustJson(Map<String, dynamic> json) {
    return SelectedDetachmentUi(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      dpCost: (json['dp_cost'] as num?)?.toInt() ?? 2,
      uniqueTag: json['unique_tag']?.toString(),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'name': name,
        'dp_cost': dpCost,
        'unique_tag': uniqueTag,
      };
}

class SelectedWargearOptionUi {
  final String item;
  final int count;
  final int pointsEach;

  const SelectedWargearOptionUi({
    required this.item,
    this.count = 1,
    required this.pointsEach,
  });

  factory SelectedWargearOptionUi.fromRustJson(Map<String, dynamic> json) {
    return SelectedWargearOptionUi(
      item: json['item']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 1,
      pointsEach: (json['points_each'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toRustJson() => {
        'item': item,
        'count': count,
        'points_each': pointsEach,
      };
}

class RosterUnitEntryUi {
  final String entryId;
  final String unitId;
  final String unitName;
  final int modelsCount;
  final String? optionDescription;
  final int basePoints;
  final String? requisitionTierLabel;
  final List<SelectedWargearOptionUi> selectedWargear;
  final String? enhancementId;
  final String? enhancementName;
  final int enhancementPoints;
  final bool enhancementIsUpgrade;
  final bool isWarlord;
  final String? attachedToEntryId;
  final List<String> categories;
  final List<String> customWeapons;
  final String notes;

  const RosterUnitEntryUi({
    required this.entryId,
    required this.unitId,
    required this.unitName,
    required this.modelsCount,
    this.optionDescription,
    required this.basePoints,
    this.requisitionTierLabel,
    this.selectedWargear = const [],
    this.enhancementId,
    this.enhancementName,
    this.enhancementPoints = 0,
    this.enhancementIsUpgrade = false,
    this.isWarlord = false,
    this.attachedToEntryId,
    this.categories = const [],
    this.customWeapons = const [],
    this.notes = '',
  });

  int get wargearPoints =>
      selectedWargear.fold(0, (sum, w) => sum + w.count * w.pointsEach);

  int get totalPoints => basePoints + wargearPoints + enhancementPoints;

  bool get isCharacter =>
      categories.any((c) => c.toUpperCase() == 'CHARACTER');

  bool get isEpicHero => categories.any(
      (c) => c.toUpperCase() == 'EPIC HERO' || c.toUpperCase() == 'EPIC_HERO');

  RosterUnitEntryUi copyWith({
    String? entryId,
    String? unitId,
    String? unitName,
    int? modelsCount,
    String? optionDescription,
    int? basePoints,
    String? requisitionTierLabel,
    List<SelectedWargearOptionUi>? selectedWargear,
    String? enhancementId,
    bool clearEnhancement = false,
    String? enhancementName,
    int? enhancementPoints,
    bool? enhancementIsUpgrade,
    bool? isWarlord,
    String? attachedToEntryId,
    bool clearAttachment = false,
    List<String>? categories,
    List<String>? customWeapons,
    String? notes,
  }) {
    return RosterUnitEntryUi(
      entryId: entryId ?? this.entryId,
      unitId: unitId ?? this.unitId,
      unitName: unitName ?? this.unitName,
      modelsCount: modelsCount ?? this.modelsCount,
      optionDescription: optionDescription ?? this.optionDescription,
      basePoints: basePoints ?? this.basePoints,
      requisitionTierLabel: requisitionTierLabel ?? this.requisitionTierLabel,
      selectedWargear: selectedWargear ?? this.selectedWargear,
      enhancementId:
          clearEnhancement ? null : (enhancementId ?? this.enhancementId),
      enhancementName:
          clearEnhancement ? null : (enhancementName ?? this.enhancementName),
      enhancementPoints: clearEnhancement
          ? 0
          : (enhancementPoints ?? this.enhancementPoints),
      enhancementIsUpgrade: clearEnhancement
          ? false
          : (enhancementIsUpgrade ?? this.enhancementIsUpgrade),
      isWarlord: isWarlord ?? this.isWarlord,
      attachedToEntryId: clearAttachment
          ? null
          : (attachedToEntryId ?? this.attachedToEntryId),
      categories: categories ?? this.categories,
      customWeapons: customWeapons ?? this.customWeapons,
      notes: notes ?? this.notes,
    );
  }

  factory RosterUnitEntryUi.fromRustJson(Map<String, dynamic> json) {
    return RosterUnitEntryUi(
      entryId: json['entry_id']?.toString() ?? '',
      unitId: json['unit_id']?.toString() ?? '',
      unitName: json['unit_name']?.toString() ?? '',
      modelsCount: (json['models_count'] as num?)?.toInt() ?? 1,
      optionDescription: json['option_description']?.toString(),
      basePoints: (json['base_points'] as num?)?.toInt() ?? 0,
      requisitionTierLabel: json['requisition_tier_label']?.toString(),
      selectedWargear: (json['selected_wargear'] as List? ?? [])
          .map((e) =>
              SelectedWargearOptionUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      enhancementId: json['enhancement_id']?.toString(),
      enhancementName: json['enhancement_name']?.toString(),
      enhancementPoints: (json['enhancement_points'] as num?)?.toInt() ?? 0,
      enhancementIsUpgrade: json['enhancement_is_upgrade'] as bool? ?? false,
      isWarlord: json['is_warlord'] as bool? ?? false,
      attachedToEntryId: json['attached_to_entry_id']?.toString(),
      categories:
          (json['categories'] as List? ?? []).map((e) => e.toString()).toList(),
      customWeapons: (json['custom_weapons'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toRustJson() => {
        'entry_id': entryId,
        'unit_id': unitId,
        'unit_name': unitName,
        'models_count': modelsCount,
        'option_description': optionDescription,
        'base_points': basePoints,
        'requisition_tier_label': requisitionTierLabel,
        'selected_wargear': selectedWargear.map((w) => w.toRustJson()).toList(),
        'enhancement_id': enhancementId,
        'enhancement_name': enhancementName,
        'enhancement_points': enhancementPoints,
        'enhancement_is_upgrade': enhancementIsUpgrade,
        'is_warlord': isWarlord,
        'attached_to_entry_id': attachedToEntryId,
        'categories': categories,
        'custom_weapons': customWeapons,
        'notes': notes,
      };
}

class ArmyListUi {
  final String id;
  final String name;
  final String factionId;
  final String factionName;
  final BattleSizeUi battleSize;
  final int pointsLimit;
  final List<SelectedDetachmentUi> detachments;
  final List<RosterUnitEntryUi> units;
  final String notes;
  final String createdAtIso;
  final String updatedAtIso;

  const ArmyListUi({
    required this.id,
    required this.name,
    required this.factionId,
    required this.factionName,
    this.battleSize = BattleSizeUi.strikeForce,
    this.pointsLimit = 2000,
    this.detachments = const [],
    this.units = const [],
    this.notes = '',
    required this.createdAtIso,
    required this.updatedAtIso,
  });

  int get totalPoints => units.fold(0, (sum, u) => sum + u.totalPoints);
  int get totalDp => detachments.fold(0, (sum, d) => sum + d.dpCost);

  ArmyListUi copyWith({
    String? id,
    String? name,
    String? factionId,
    String? factionName,
    BattleSizeUi? battleSize,
    int? pointsLimit,
    List<SelectedDetachmentUi>? detachments,
    List<RosterUnitEntryUi>? units,
    String? notes,
    String? createdAtIso,
    String? updatedAtIso,
  }) {
    return ArmyListUi(
      id: id ?? this.id,
      name: name ?? this.name,
      factionId: factionId ?? this.factionId,
      factionName: factionName ?? this.factionName,
      battleSize: battleSize ?? this.battleSize,
      pointsLimit: pointsLimit ?? this.pointsLimit,
      detachments: detachments ?? this.detachments,
      units: units ?? this.units,
      notes: notes ?? this.notes,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  factory ArmyListUi.fromRustJson(Map<String, dynamic> json) {
    return ArmyListUi(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled Army List',
      factionId: json['faction_id']?.toString() ?? '',
      factionName: json['faction_name']?.toString() ?? '',
      battleSize: BattleSizeUi.fromRustJson(json['battle_size']?.toString()),
      pointsLimit: (json['points_limit'] as num?)?.toInt() ?? 2000,
      detachments: (json['detachments'] as List? ?? [])
          .map((e) =>
              SelectedDetachmentUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      units: (json['units'] as List? ?? [])
          .map((e) =>
              RosterUnitEntryUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      notes: json['notes']?.toString() ?? '',
      createdAtIso:
          json['created_at_iso']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAtIso:
          json['updated_at_iso']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'name': name,
        'faction_id': factionId,
        'faction_name': factionName,
        'battle_size': battleSize.toRustJson(),
        'points_limit': pointsLimit,
        'detachments': detachments.map((d) => d.toRustJson()).toList(),
        'units': units.map((u) => u.toRustJson()).toList(),
        'notes': notes,
        'created_at_iso': createdAtIso,
        'updated_at_iso': updatedAtIso,
      };
}

class ValidationIssueUi {
  final String severity;
  final String code;
  final String message;
  final String? affectedEntryId;

  const ValidationIssueUi({
    required this.severity,
    required this.code,
    required this.message,
    this.affectedEntryId,
  });

  factory ValidationIssueUi.fromRustJson(Map<String, dynamic> json) {
    return ValidationIssueUi(
      severity: json['severity']?.toString() ?? 'error',
      code: json['code']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      affectedEntryId: json['affected_entry_id']?.toString(),
    );
  }
}

class ListValidationReportUi {
  final bool isValid;
  final int totalPoints;
  final int pointsLimit;
  final int totalDp;
  final int dpLimit;
  final int enhancementSlotsUsed;
  final int enhancementLimit;
  final List<ValidationIssueUi> violations;
  final List<ValidationIssueUi> warnings;
  final List<String> unverifiedRules;

  const ListValidationReportUi({
    required this.isValid,
    required this.totalPoints,
    required this.pointsLimit,
    required this.totalDp,
    required this.dpLimit,
    required this.enhancementSlotsUsed,
    required this.enhancementLimit,
    this.violations = const [],
    this.warnings = const [],
    this.unverifiedRules = const [],
  });

  factory ListValidationReportUi.fromRustJson(Map<String, dynamic> json) {
    return ListValidationReportUi(
      isValid: json['is_valid'] as bool? ?? false,
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
      pointsLimit: (json['points_limit'] as num?)?.toInt() ?? 2000,
      totalDp: (json['total_dp'] as num?)?.toInt() ?? 0,
      dpLimit: (json['dp_limit'] as num?)?.toInt() ?? 3,
      enhancementSlotsUsed:
          (json['enhancement_slots_used'] as num?)?.toInt() ?? 0,
      enhancementLimit: (json['enhancement_limit'] as num?)?.toInt() ?? 4,
      violations: (json['violations'] as List? ?? [])
          .map((e) =>
              ValidationIssueUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      warnings: (json['warnings'] as List? ?? [])
          .map((e) =>
              ValidationIssueUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      unverifiedRules: (json['unverified_rules'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class ArmyListEvaluationUi {
  final ArmyListUi list;
  final ListValidationReportUi validation;
  final String exportedText;

  const ArmyListEvaluationUi({
    required this.list,
    required this.validation,
    required this.exportedText,
  });

  factory ArmyListEvaluationUi.fromRustJson(Map<String, dynamic> json) {
    return ArmyListEvaluationUi(
      list: ArmyListUi.fromRustJson(
          Map<String, dynamic>.from(json['list'] as Map? ?? {})),
      validation: ListValidationReportUi.fromRustJson(
          Map<String, dynamic>.from(json['validation'] as Map? ?? {})),
      exportedText: json['exported_text']?.toString() ?? '',
    );
  }
}

// ============================================================================
// 2. UNIT WISHLIST MODELS
// ============================================================================

enum WishlistPriorityUi {
  low,
  medium,
  high,
  critical;

  String toRustJson() => name;

  static WishlistPriorityUi fromRustJson(String? raw) {
    switch (raw) {
      case 'low':
        return WishlistPriorityUi.low;
      case 'high':
        return WishlistPriorityUi.high;
      case 'critical':
        return WishlistPriorityUi.critical;
      default:
        return WishlistPriorityUi.medium;
    }
  }

  String get label {
    switch (this) {
      case WishlistPriorityUi.low:
        return 'Low';
      case WishlistPriorityUi.medium:
        return 'Medium';
      case WishlistPriorityUi.high:
        return 'High';
      case WishlistPriorityUi.critical:
        return 'Critical';
    }
  }
}

enum AcquisitionStateUi {
  wishlist,
  ordered,
  unbuilt,
  assembled,
  primed,
  battleReady,
  paradeReady;

  String toRustJson() {
    switch (this) {
      case AcquisitionStateUi.wishlist:
        return 'wishlist';
      case AcquisitionStateUi.ordered:
        return 'ordered';
      case AcquisitionStateUi.unbuilt:
        return 'unbuilt';
      case AcquisitionStateUi.assembled:
        return 'assembled';
      case AcquisitionStateUi.primed:
        return 'primed';
      case AcquisitionStateUi.battleReady:
        return 'battle_ready';
      case AcquisitionStateUi.paradeReady:
        return 'parade_ready';
    }
  }

  static AcquisitionStateUi fromRustJson(String? raw) {
    switch (raw) {
      case 'ordered':
        return AcquisitionStateUi.ordered;
      case 'unbuilt':
        return AcquisitionStateUi.unbuilt;
      case 'assembled':
        return AcquisitionStateUi.assembled;
      case 'primed':
        return AcquisitionStateUi.primed;
      case 'battle_ready':
        return AcquisitionStateUi.battleReady;
      case 'parade_ready':
        return AcquisitionStateUi.paradeReady;
      default:
        return AcquisitionStateUi.wishlist;
    }
  }

  String get label {
    switch (this) {
      case AcquisitionStateUi.wishlist:
        return 'To Buy / Wishlist';
      case AcquisitionStateUi.ordered:
        return 'Ordered / In Transit';
      case AcquisitionStateUi.unbuilt:
        return 'In Box / Unbuilt';
      case AcquisitionStateUi.assembled:
        return 'Assembled';
      case AcquisitionStateUi.primed:
        return 'Primed';
      case AcquisitionStateUi.battleReady:
        return 'Battle Ready';
      case AcquisitionStateUi.paradeReady:
        return 'Parade Ready';
    }
  }
}

enum WishlistSortFieldUi {
  priorityDesc,
  nameAsc,
  pointsDesc,
  stateProgress,
  quantityDesc;

  String toRustJson() {
    switch (this) {
      case WishlistSortFieldUi.priorityDesc:
        return 'priority_desc';
      case WishlistSortFieldUi.nameAsc:
        return 'name_asc';
      case WishlistSortFieldUi.pointsDesc:
        return 'points_desc';
      case WishlistSortFieldUi.stateProgress:
        return 'state_progress';
      case WishlistSortFieldUi.quantityDesc:
        return 'quantity_desc';
    }
  }

  String get label {
    switch (this) {
      case WishlistSortFieldUi.priorityDesc:
        return 'Priority (High → Low)';
      case WishlistSortFieldUi.nameAsc:
        return 'Name (A → Z)';
      case WishlistSortFieldUi.pointsDesc:
        return 'Points (High → Low)';
      case WishlistSortFieldUi.stateProgress:
        return 'Hobby Progress';
      case WishlistSortFieldUi.quantityDesc:
        return 'Quantity Desired';
    }
  }
}

class WishlistItemUi {
  final String id;
  final String factionId;
  final String factionName;
  final String unitId;
  final String unitName;
  final int quantityDesired;
  final int quantityOwned;
  final int pointsPerUnit;
  final WishlistPriorityUi priority;
  final AcquisitionStateUi state;
  final String notes;
  final String updatedAtIso;

  const WishlistItemUi({
    required this.id,
    required this.factionId,
    required this.factionName,
    required this.unitId,
    required this.unitName,
    this.quantityDesired = 1,
    this.quantityOwned = 0,
    this.pointsPerUnit = 100,
    this.priority = WishlistPriorityUi.medium,
    this.state = AcquisitionStateUi.wishlist,
    this.notes = '',
    required this.updatedAtIso,
  });

  int get totalPointsDesired => quantityDesired * pointsPerUnit;
  int get remainingToAcquire =>
      (quantityDesired - quantityOwned).clamp(0, 999);

  WishlistItemUi copyWith({
    String? id,
    String? factionId,
    String? factionName,
    String? unitId,
    String? unitName,
    int? quantityDesired,
    int? quantityOwned,
    int? pointsPerUnit,
    WishlistPriorityUi? priority,
    AcquisitionStateUi? state,
    String? notes,
    String? updatedAtIso,
  }) {
    return WishlistItemUi(
      id: id ?? this.id,
      factionId: factionId ?? this.factionId,
      factionName: factionName ?? this.factionName,
      unitId: unitId ?? this.unitId,
      unitName: unitName ?? this.unitName,
      quantityDesired: quantityDesired ?? this.quantityDesired,
      quantityOwned: quantityOwned ?? this.quantityOwned,
      pointsPerUnit: pointsPerUnit ?? this.pointsPerUnit,
      priority: priority ?? this.priority,
      state: state ?? this.state,
      notes: notes ?? this.notes,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  factory WishlistItemUi.fromRustJson(Map<String, dynamic> json) {
    return WishlistItemUi(
      id: json['id']?.toString() ?? '',
      factionId: json['faction_id']?.toString() ?? '',
      factionName: json['faction_name']?.toString() ?? '',
      unitId: json['unit_id']?.toString() ?? '',
      unitName: json['unit_name']?.toString() ?? '',
      quantityDesired: (json['quantity_desired'] as num?)?.toInt() ?? 1,
      quantityOwned: (json['quantity_owned'] as num?)?.toInt() ?? 0,
      pointsPerUnit: (json['points_per_unit'] as num?)?.toInt() ?? 0,
      priority: WishlistPriorityUi.fromRustJson(json['priority']?.toString()),
      state: AcquisitionStateUi.fromRustJson(json['state']?.toString()),
      notes: json['notes']?.toString() ?? '',
      updatedAtIso:
          json['updated_at_iso']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'faction_id': factionId,
        'faction_name': factionName,
        'unit_id': unitId,
        'unit_name': unitName,
        'quantity_desired': quantityDesired,
        'quantity_owned': quantityOwned,
        'points_per_unit': pointsPerUnit,
        'priority': priority.toRustJson(),
        'state': state.toRustJson(),
        'notes': notes,
        'updated_at_iso': updatedAtIso,
      };
}

class WishlistSummaryUi {
  final String? factionFilter;
  final int totalDistinctUnits;
  final int totalBoxesDesired;
  final int totalBoxesOwned;
  final int totalBoxesRemaining;
  final int totalPointsDesired;
  final int totalPointsOwned;
  final int criticalPriorityCount;
  final int highPriorityCount;
  final int paintedEntriesCount;
  final int acquiredEntriesCount;
  final double completionPercent;

  const WishlistSummaryUi({
    this.factionFilter,
    this.totalDistinctUnits = 0,
    this.totalBoxesDesired = 0,
    this.totalBoxesOwned = 0,
    this.totalBoxesRemaining = 0,
    this.totalPointsDesired = 0,
    this.totalPointsOwned = 0,
    this.criticalPriorityCount = 0,
    this.highPriorityCount = 0,
    this.paintedEntriesCount = 0,
    this.acquiredEntriesCount = 0,
    this.completionPercent = 0.0,
  });

  factory WishlistSummaryUi.fromRustJson(Map<String, dynamic> json) {
    return WishlistSummaryUi(
      factionFilter: json['faction_filter']?.toString(),
      totalDistinctUnits:
          (json['total_distinct_units'] as num?)?.toInt() ?? 0,
      totalBoxesDesired: (json['total_boxes_desired'] as num?)?.toInt() ?? 0,
      totalBoxesOwned: (json['total_boxes_owned'] as num?)?.toInt() ?? 0,
      totalBoxesRemaining:
          (json['total_boxes_remaining'] as num?)?.toInt() ?? 0,
      totalPointsDesired:
          (json['total_points_desired'] as num?)?.toInt() ?? 0,
      totalPointsOwned: (json['total_points_owned'] as num?)?.toInt() ?? 0,
      criticalPriorityCount:
          (json['critical_priority_count'] as num?)?.toInt() ?? 0,
      highPriorityCount: (json['high_priority_count'] as num?)?.toInt() ?? 0,
      paintedEntriesCount:
          (json['painted_entries_count'] as num?)?.toInt() ?? 0,
      acquiredEntriesCount:
          (json['acquired_entries_count'] as num?)?.toInt() ?? 0,
      completionPercent:
          (json['completion_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class WishlistOperationResponseUi {
  final List<WishlistItemUi> items;
  final List<WishlistItemUi> filteredItems;
  final WishlistSummaryUi summary;

  const WishlistOperationResponseUi({
    required this.items,
    required this.filteredItems,
    required this.summary,
  });

  factory WishlistOperationResponseUi.fromRustJson(Map<String, dynamic> json) {
    return WishlistOperationResponseUi(
      items: (json['items'] as List? ?? [])
          .map((e) => WishlistItemUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      filteredItems: (json['filtered_items'] as List? ?? [])
          .map((e) => WishlistItemUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      summary: WishlistSummaryUi.fromRustJson(
          Map<String, dynamic>.from(json['summary'] as Map? ?? {})),
    );
  }
}

// ============================================================================
// 3. MATCH HISTORY & STATISTICS MODELS (40K + KILL TEAM)
// ============================================================================

enum GameSystemUi {
  warhammer40k,
  killTeam;

  String toRustJson() =>
      this == GameSystemUi.warhammer40k ? 'warhammer40k' : 'kill_team';

  static GameSystemUi fromRustJson(String? raw) =>
      raw == 'kill_team' ? GameSystemUi.killTeam : GameSystemUi.warhammer40k;

  String get label =>
      this == GameSystemUi.warhammer40k ? 'Warhammer 40,000' : 'Kill Team';
}

enum MatchResultUi {
  win,
  loss,
  draw,
  inProgress;

  String toRustJson() {
    switch (this) {
      case MatchResultUi.win:
        return 'win';
      case MatchResultUi.loss:
        return 'loss';
      case MatchResultUi.draw:
        return 'draw';
      case MatchResultUi.inProgress:
        return 'in_progress';
    }
  }

  static MatchResultUi fromRustJson(String? raw) {
    switch (raw) {
      case 'win':
        return MatchResultUi.win;
      case 'loss':
        return MatchResultUi.loss;
      case 'draw':
        return MatchResultUi.draw;
      case 'in_progress':
        return MatchResultUi.inProgress;
      default:
        return MatchResultUi.win;
    }
  }

  String get label {
    switch (this) {
      case MatchResultUi.win:
        return 'Win';
      case MatchResultUi.loss:
        return 'Loss';
      case MatchResultUi.draw:
        return 'Draw';
      case MatchResultUi.inProgress:
        return 'In Progress';
    }
  }
}

class Wh40kRoundScoreUi {
  final int round;
  final int playerPrimary;
  final int playerSecondary;
  final int opponentPrimary;
  final int opponentSecondary;
  final String notes;

  const Wh40kRoundScoreUi({
    required this.round,
    this.playerPrimary = 0,
    this.playerSecondary = 0,
    this.opponentPrimary = 0,
    this.opponentSecondary = 0,
    this.notes = '',
  });

  Wh40kRoundScoreUi copyWith({
    int? playerPrimary,
    int? playerSecondary,
    int? opponentPrimary,
    int? opponentSecondary,
    String? notes,
  }) {
    return Wh40kRoundScoreUi(
      round: round,
      playerPrimary: playerPrimary ?? this.playerPrimary,
      playerSecondary: playerSecondary ?? this.playerSecondary,
      opponentPrimary: opponentPrimary ?? this.opponentPrimary,
      opponentSecondary: opponentSecondary ?? this.opponentSecondary,
      notes: notes ?? this.notes,
    );
  }

  factory Wh40kRoundScoreUi.fromRustJson(Map<String, dynamic> json) {
    return Wh40kRoundScoreUi(
      round: (json['round'] as num?)?.toInt() ?? 1,
      playerPrimary: (json['player_primary'] as num?)?.toInt() ?? 0,
      playerSecondary: (json['player_secondary'] as num?)?.toInt() ?? 0,
      opponentPrimary: (json['opponent_primary'] as num?)?.toInt() ?? 0,
      opponentSecondary: (json['opponent_secondary'] as num?)?.toInt() ?? 0,
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toRustJson() => {
        'round': round,
        'player_primary': playerPrimary,
        'player_secondary': playerSecondary,
        'opponent_primary': opponentPrimary,
        'opponent_secondary': opponentSecondary,
        'notes': notes,
      };
}

class Wh40kMatchDetailsUi {
  final String battleSize;
  final int pointsLimit;
  final String missionPack;
  final String primaryMission;
  final String deployment;
  final String playerDetachment;
  final String opponentDetachment;
  final String? armyListId;
  final String? armyListName;
  final List<String> playerSecondaries;
  final List<String> opponentSecondaries;
  final List<Wh40kRoundScoreUi> rounds;
  final bool playerBattleReadyBonus;
  final bool opponentBattleReadyBonus;
  final bool? playerWentFirst;

  const Wh40kMatchDetailsUi({
    this.battleSize = 'Strike Force',
    this.pointsLimit = 2000,
    this.missionPack = 'Chapter Approved',
    this.primaryMission = 'Take and Hold',
    this.deployment = 'Hammer and Anvil',
    this.playerDetachment = '',
    this.opponentDetachment = '',
    this.armyListId,
    this.armyListName,
    this.playerSecondaries = const [],
    this.opponentSecondaries = const [],
    this.rounds = const [],
    this.playerBattleReadyBonus = true,
    this.opponentBattleReadyBonus = true,
    this.playerWentFirst,
  });

  int get calculatedPlayerScore {
    final p = rounds.fold(0, (s, r) => s + r.playerPrimary).clamp(0, 50);
    final s = rounds.fold(0, (s, r) => s + r.playerSecondary).clamp(0, 40);
    final b = playerBattleReadyBonus ? 10 : 0;
    return (p + s + b).clamp(0, 100);
  }

  int get calculatedOpponentScore {
    final p = rounds.fold(0, (s, r) => s + r.opponentPrimary).clamp(0, 50);
    final s = rounds.fold(0, (s, r) => s + r.opponentSecondary).clamp(0, 40);
    final b = opponentBattleReadyBonus ? 10 : 0;
    return (p + s + b).clamp(0, 100);
  }

  factory Wh40kMatchDetailsUi.fromRustJson(Map<String, dynamic> json) {
    return Wh40kMatchDetailsUi(
      battleSize: json['battle_size']?.toString() ?? 'Strike Force',
      pointsLimit: (json['points_limit'] as num?)?.toInt() ?? 2000,
      missionPack: json['mission_pack']?.toString() ?? 'Chapter Approved',
      primaryMission: json['primary_mission']?.toString() ?? 'Take and Hold',
      deployment: json['deployment']?.toString() ?? 'Hammer and Anvil',
      playerDetachment: json['player_detachment']?.toString() ?? '',
      opponentDetachment: json['opponent_detachment']?.toString() ?? '',
      armyListId: json['army_list_id']?.toString(),
      armyListName: json['army_list_name']?.toString(),
      playerSecondaries: (json['player_secondaries'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      opponentSecondaries: (json['opponent_secondaries'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      rounds: (json['rounds'] as List? ?? [])
          .map((e) =>
              Wh40kRoundScoreUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      playerBattleReadyBonus:
          json['player_battle_ready_bonus'] as bool? ?? true,
      opponentBattleReadyBonus:
          json['opponent_battle_ready_bonus'] as bool? ?? true,
      playerWentFirst: json['player_went_first'] as bool?,
    );
  }

  Map<String, dynamic> toRustJson() => {
        'battle_size': battleSize,
        'points_limit': pointsLimit,
        'mission_pack': missionPack,
        'primary_mission': primaryMission,
        'deployment': deployment,
        'player_detachment': playerDetachment,
        'opponent_detachment': opponentDetachment,
        'army_list_id': armyListId,
        'army_list_name': armyListName,
        'player_secondaries': playerSecondaries,
        'opponent_secondaries': opponentSecondaries,
        'rounds': rounds.map((r) => r.toRustJson()).toList(),
        'player_battle_ready_bonus': playerBattleReadyBonus,
        'opponent_battle_ready_bonus': opponentBattleReadyBonus,
        'player_went_first': playerWentFirst,
      };
}

class KillTeamTurningPointScoreUi {
  final int turningPoint;
  final int playerCritOp;
  final int playerTacOp;
  final int playerKillOp;
  final int opponentCritOp;
  final int opponentTacOp;
  final int opponentKillOp;
  final String notes;

  const KillTeamTurningPointScoreUi({
    required this.turningPoint,
    this.playerCritOp = 0,
    this.playerTacOp = 0,
    this.playerKillOp = 0,
    this.opponentCritOp = 0,
    this.opponentTacOp = 0,
    this.opponentKillOp = 0,
    this.notes = '',
  });

  KillTeamTurningPointScoreUi copyWith({
    int? playerCritOp,
    int? playerTacOp,
    int? playerKillOp,
    int? opponentCritOp,
    int? opponentTacOp,
    int? opponentKillOp,
    String? notes,
  }) {
    return KillTeamTurningPointScoreUi(
      turningPoint: turningPoint,
      playerCritOp: playerCritOp ?? this.playerCritOp,
      playerTacOp: playerTacOp ?? this.playerTacOp,
      playerKillOp: playerKillOp ?? this.playerKillOp,
      opponentCritOp: opponentCritOp ?? this.opponentCritOp,
      opponentTacOp: opponentTacOp ?? this.opponentTacOp,
      opponentKillOp: opponentKillOp ?? this.opponentKillOp,
      notes: notes ?? this.notes,
    );
  }

  factory KillTeamTurningPointScoreUi.fromRustJson(Map<String, dynamic> json) {
    return KillTeamTurningPointScoreUi(
      turningPoint: (json['turning_point'] as num?)?.toInt() ?? 1,
      playerCritOp: (json['player_crit_op'] as num?)?.toInt() ?? 0,
      playerTacOp: (json['player_tac_op'] as num?)?.toInt() ?? 0,
      playerKillOp: (json['player_kill_op'] as num?)?.toInt() ?? 0,
      opponentCritOp: (json['opponent_crit_op'] as num?)?.toInt() ?? 0,
      opponentTacOp: (json['opponent_tac_op'] as num?)?.toInt() ?? 0,
      opponentKillOp: (json['opponent_kill_op'] as num?)?.toInt() ?? 0,
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toRustJson() => {
        'turning_point': turningPoint,
        'player_crit_op': playerCritOp,
        'player_tac_op': playerTacOp,
        'player_kill_op': playerKillOp,
        'opponent_crit_op': opponentCritOp,
        'opponent_tac_op': opponentTacOp,
        'opponent_kill_op': opponentKillOp,
        'notes': notes,
      };
}

class KillTeamMatchDetailsUi {
  final String killzone;
  final String critOpMission;
  final String playerTacOpArchetype;
  final String playerTacOpName;
  final String opponentTacOpName;
  final String playerPrimaryOp;
  final String opponentPrimaryOp;
  final int playerPrimaryOpBonus;
  final int opponentPrimaryOpBonus;
  final bool playerPaintedBonus;
  final bool opponentPaintedBonus;
  final List<KillTeamTurningPointScoreUi> turningPoints;

  const KillTeamMatchDetailsUi({
    this.killzone = 'Killzone: Volkus',
    this.critOpMission = 'Secure',
    this.playerTacOpArchetype = 'Seek & Destroy',
    this.playerTacOpName = '',
    this.opponentTacOpName = '',
    this.playerPrimaryOp = 'Crit Op',
    this.opponentPrimaryOp = 'Crit Op',
    this.playerPrimaryOpBonus = 0,
    this.opponentPrimaryOpBonus = 0,
    this.playerPaintedBonus = true,
    this.opponentPaintedBonus = true,
    this.turningPoints = const [],
  });

  int get calculatedPlayerScore {
    final crit = turningPoints.fold(0, (s, tp) => s + tp.playerCritOp).clamp(0, 6);
    final tac = turningPoints.fold(0, (s, tp) => s + tp.playerTacOp).clamp(0, 6);
    final kill = turningPoints.fold(0, (s, tp) => s + tp.playerKillOp).clamp(0, 6);
    final base = playerPrimaryOp == 'Crit Op'
        ? crit
        : (playerPrimaryOp == 'Tac Op'
            ? tac
            : (playerPrimaryOp == 'Kill Op' ? kill : 0));
    final bonus = playerPrimaryOpBonus > 0
        ? playerPrimaryOpBonus.clamp(0, 3)
        : ((base / 2.0).ceil());
    final painted = playerPaintedBonus ? 2 : 0;
    return crit + tac + kill + bonus + painted;
  }

  int get calculatedOpponentScore {
    final crit =
        turningPoints.fold(0, (s, tp) => s + tp.opponentCritOp).clamp(0, 6);
    final tac =
        turningPoints.fold(0, (s, tp) => s + tp.opponentTacOp).clamp(0, 6);
    final kill =
        turningPoints.fold(0, (s, tp) => s + tp.opponentKillOp).clamp(0, 6);
    final base = opponentPrimaryOp == 'Crit Op'
        ? crit
        : (opponentPrimaryOp == 'Tac Op'
            ? tac
            : (opponentPrimaryOp == 'Kill Op' ? kill : 0));
    final bonus = opponentPrimaryOpBonus > 0
        ? opponentPrimaryOpBonus.clamp(0, 3)
        : ((base / 2.0).ceil());
    final painted = opponentPaintedBonus ? 2 : 0;
    return crit + tac + kill + bonus + painted;
  }

  factory KillTeamMatchDetailsUi.fromRustJson(Map<String, dynamic> json) {
    return KillTeamMatchDetailsUi(
      killzone: json['killzone']?.toString() ?? 'Killzone: Volkus',
      critOpMission: json['crit_op_mission']?.toString() ?? 'Secure',
      playerTacOpArchetype:
          json['player_tac_op_archetype']?.toString() ?? 'Seek & Destroy',
      playerTacOpName: json['player_tac_op_name']?.toString() ?? '',
      opponentTacOpName: json['opponent_tac_op_name']?.toString() ?? '',
      playerPrimaryOp: json['player_primary_op']?.toString() ?? 'Crit Op',
      opponentPrimaryOp: json['opponent_primary_op']?.toString() ?? 'Crit Op',
      playerPrimaryOpBonus:
          (json['player_primary_op_bonus'] as num?)?.toInt() ?? 0,
      opponentPrimaryOpBonus:
          (json['opponent_primary_op_bonus'] as num?)?.toInt() ?? 0,
      playerPaintedBonus: json['player_painted_bonus'] as bool? ?? true,
      opponentPaintedBonus: json['opponent_painted_bonus'] as bool? ?? true,
      turningPoints: (json['turning_points'] as List? ?? [])
          .map((e) => KillTeamTurningPointScoreUi.fromRustJson(
              Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'killzone': killzone,
        'crit_op_mission': critOpMission,
        'player_tac_op_archetype': playerTacOpArchetype,
        'player_tac_op_name': playerTacOpName,
        'opponent_tac_op_name': opponentTacOpName,
        'player_primary_op': playerPrimaryOp,
        'opponent_primary_op': opponentPrimaryOp,
        'player_primary_op_bonus': playerPrimaryOpBonus,
        'opponent_primary_op_bonus': opponentPrimaryOpBonus,
        'player_painted_bonus': playerPaintedBonus,
        'opponent_painted_bonus': opponentPaintedBonus,
        'turning_points': turningPoints.map((tp) => tp.toRustJson()).toList(),
      };
}

class MatchRecordUi {
  final String id;
  final GameSystemUi gameSystem;
  final String dateIso;
  final String playerFaction;
  final String opponentFaction;
  final String opponentName;
  final int playerScore;
  final int opponentScore;
  final MatchResultUi result;
  final bool isDetailed;
  final Wh40kMatchDetailsUi? wh40kDetails;
  final KillTeamMatchDetailsUi? killTeamDetails;
  final String notes;
  final String createdAtIso;
  final String updatedAtIso;

  const MatchRecordUi({
    required this.id,
    this.gameSystem = GameSystemUi.warhammer40k,
    required this.dateIso,
    required this.playerFaction,
    required this.opponentFaction,
    this.opponentName = '',
    required this.playerScore,
    required this.opponentScore,
    required this.result,
    this.isDetailed = false,
    this.wh40kDetails,
    this.killTeamDetails,
    this.notes = '',
    required this.createdAtIso,
    required this.updatedAtIso,
  });

  factory MatchRecordUi.fromRustJson(Map<String, dynamic> json) {
    return MatchRecordUi(
      id: json['id']?.toString() ?? '',
      gameSystem: GameSystemUi.fromRustJson(json['game_system']?.toString()),
      dateIso: json['date_iso']?.toString() ?? '',
      playerFaction: json['player_faction']?.toString() ?? '',
      opponentFaction: json['opponent_faction']?.toString() ?? '',
      opponentName: json['opponent_name']?.toString() ?? '',
      playerScore: (json['player_score'] as num?)?.toInt() ?? 0,
      opponentScore: (json['opponent_score'] as num?)?.toInt() ?? 0,
      result: MatchResultUi.fromRustJson(json['result']?.toString()),
      isDetailed: json['is_detailed'] as bool? ?? false,
      wh40kDetails: json['wh40k_details'] is Map
          ? Wh40kMatchDetailsUi.fromRustJson(
              Map<String, dynamic>.from(json['wh40k_details'] as Map))
          : null,
      killTeamDetails: json['kill_team_details'] is Map
          ? KillTeamMatchDetailsUi.fromRustJson(
              Map<String, dynamic>.from(json['kill_team_details'] as Map))
          : null,
      notes: json['notes']?.toString() ?? '',
      createdAtIso:
          json['created_at_iso']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAtIso:
          json['updated_at_iso']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'game_system': gameSystem.toRustJson(),
        'date_iso': dateIso,
        'player_faction': playerFaction,
        'opponent_faction': opponentFaction,
        'opponent_name': opponentName,
        'player_score': playerScore,
        'opponent_score': opponentScore,
        'result': result.toRustJson(),
        'is_detailed': isDetailed,
        'wh40k_details': wh40kDetails?.toRustJson(),
        'kill_team_details': killTeamDetails?.toRustJson(),
        'notes': notes,
        'created_at_iso': createdAtIso,
        'updated_at_iso': updatedAtIso,
      };
}

class FactionPerformanceUi {
  final String faction;
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;
  final double winRatePercent;
  final double averagePlayerScore;
  final double averageOpponentScore;

  const FactionPerformanceUi({
    required this.faction,
    required this.gamesPlayed,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRatePercent,
    required this.averagePlayerScore,
    required this.averageOpponentScore,
  });

  factory FactionPerformanceUi.fromRustJson(Map<String, dynamic> json) {
    return FactionPerformanceUi(
      faction: json['faction']?.toString() ?? '',
      gamesPlayed: (json['games_played'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      winRatePercent: (json['win_rate_percent'] as num?)?.toDouble() ?? 0.0,
      averagePlayerScore:
          (json['average_player_score'] as num?)?.toDouble() ?? 0.0,
      averageOpponentScore:
          (json['average_opponent_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ScoreTrendPointUi {
  final String matchId;
  final String dateIso;
  final GameSystemUi gameSystem;
  final String playerFaction;
  final String opponentFaction;
  final int playerScore;
  final int opponentScore;
  final MatchResultUi result;

  const ScoreTrendPointUi({
    required this.matchId,
    required this.dateIso,
    required this.gameSystem,
    required this.playerFaction,
    required this.opponentFaction,
    required this.playerScore,
    required this.opponentScore,
    required this.result,
  });

  factory ScoreTrendPointUi.fromRustJson(Map<String, dynamic> json) {
    return ScoreTrendPointUi(
      matchId: json['match_id']?.toString() ?? '',
      dateIso: json['date_iso']?.toString() ?? '',
      gameSystem: GameSystemUi.fromRustJson(json['game_system']?.toString()),
      playerFaction: json['player_faction']?.toString() ?? '',
      opponentFaction: json['opponent_faction']?.toString() ?? '',
      playerScore: (json['player_score'] as num?)?.toInt() ?? 0,
      opponentScore: (json['opponent_score'] as num?)?.toInt() ?? 0,
      result: MatchResultUi.fromRustJson(json['result']?.toString()),
    );
  }
}

class MatchStatisticsReportUi {
  final String scopeExplanation;
  final GameSystemUi? gameSystemFilter;
  final int totalCompletedGames;
  final int incompleteGamesExcluded;
  final int wins;
  final int losses;
  final int draws;
  final double winRatePercent;
  final double averagePlayerScore;
  final double averageOpponentScore;
  final double averageDifferential;
  final List<FactionPerformanceUi> byPlayerFaction;
  final List<FactionPerformanceUi> byOpponentFaction;
  final List<MatchResultUi> recentResults;
  final List<ScoreTrendPointUi> scoreTrends;

  const MatchStatisticsReportUi({
    this.scopeExplanation = '',
    this.gameSystemFilter,
    this.totalCompletedGames = 0,
    this.incompleteGamesExcluded = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.winRatePercent = 0.0,
    this.averagePlayerScore = 0.0,
    this.averageOpponentScore = 0.0,
    this.averageDifferential = 0.0,
    this.byPlayerFaction = const [],
    this.byOpponentFaction = const [],
    this.recentResults = const [],
    this.scoreTrends = const [],
  });

  factory MatchStatisticsReportUi.fromRustJson(Map<String, dynamic> json) {
    return MatchStatisticsReportUi(
      scopeExplanation: json['scope_explanation']?.toString() ?? '',
      gameSystemFilter: json['game_system_filter'] != null
          ? GameSystemUi.fromRustJson(json['game_system_filter']?.toString())
          : null,
      totalCompletedGames:
          (json['total_completed_games'] as num?)?.toInt() ?? 0,
      incompleteGamesExcluded:
          (json['incomplete_games_excluded'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      winRatePercent: (json['win_rate_percent'] as num?)?.toDouble() ?? 0.0,
      averagePlayerScore:
          (json['average_player_score'] as num?)?.toDouble() ?? 0.0,
      averageOpponentScore:
          (json['average_opponent_score'] as num?)?.toDouble() ?? 0.0,
      averageDifferential:
          (json['average_differential'] as num?)?.toDouble() ?? 0.0,
      byPlayerFaction: (json['by_player_faction'] as List? ?? [])
          .map((e) =>
              FactionPerformanceUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      byOpponentFaction: (json['by_opponent_faction'] as List? ?? [])
          .map((e) =>
              FactionPerformanceUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      recentResults: (json['recent_results'] as List? ?? [])
          .map((e) => MatchResultUi.fromRustJson(e?.toString()))
          .toList(),
      scoreTrends: (json['score_trends'] as List? ?? [])
          .map((e) =>
              ScoreTrendPointUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class MatchDashboardResponseUi {
  final List<MatchRecordUi> filteredMatches;
  final MatchStatisticsReportUi statistics;
  final List<String> killTeamFactions;

  const MatchDashboardResponseUi({
    required this.filteredMatches,
    required this.statistics,
    required this.killTeamFactions,
  });

  factory MatchDashboardResponseUi.fromRustJson(Map<String, dynamic> json) {
    return MatchDashboardResponseUi(
      filteredMatches: (json['filtered_matches'] as List? ?? [])
          .map((e) => MatchRecordUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      statistics: MatchStatisticsReportUi.fromRustJson(
          Map<String, dynamic>.from(json['statistics'] as Map? ?? {})),
      killTeamFactions: (json['kill_team_factions'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

// ============================================================================
// 4. PERSONAL DATA STORE & SAVED CALCULATION CONFIGS
// ============================================================================

class SavedCalculationConfigUi {
  final String id;
  final String name;
  final String attackerUnitName;
  final WeaponUiProfile weapon;
  final List<WeaponLoadoutEntry> squadLoadout;
  final UnitUiProfile target;
  final int iterations;
  final String createdAt;

  const SavedCalculationConfigUi({
    required this.id,
    required this.name,
    this.attackerUnitName = '',
    required this.weapon,
    this.squadLoadout = const [],
    required this.target,
    this.iterations = 10000,
    required this.createdAt,
  });

  factory SavedCalculationConfigUi.fromRustJson(Map<String, dynamic> json) {
    return SavedCalculationConfigUi(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Saved Calculation',
      attackerUnitName: json['attacker_unit_name']?.toString() ?? '',
      weapon: WeaponUiProfile.fromRustJson(
          Map<String, dynamic>.from(json['weapon'] as Map? ?? {})),
      squadLoadout: (json['squad_loadout'] as List? ?? [])
          .map((e) =>
              WeaponLoadoutEntry.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      target: UnitUiProfile.fromRustJson(
          Map<String, dynamic>.from(json['target'] as Map? ?? {})),
      iterations: (json['iterations'] as num?)?.toInt() ?? 10000,
      createdAt:
          json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'name': name,
        'attacker_unit_name': attackerUnitName,
        'weapon': weapon.toRustJson(),
        'squad_loadout': squadLoadout.map((e) => e.toRustJson()).toList(),
        'target': target.toRustJson(),
        'context': {},
        'iterations': iterations,
        'created_at': createdAt,
      };
}

class UserSettingsUi {
  final int defaultIterations;
  final bool showExactStageMath;
  final String? preferredFactionId;
  final String playerName;

  const UserSettingsUi({
    this.defaultIterations = 10000,
    this.showExactStageMath = true,
    this.preferredFactionId,
    this.playerName = '',
  });

  UserSettingsUi copyWith({
    int? defaultIterations,
    bool? showExactStageMath,
    String? preferredFactionId,
    String? playerName,
  }) {
    return UserSettingsUi(
      defaultIterations: defaultIterations ?? this.defaultIterations,
      showExactStageMath: showExactStageMath ?? this.showExactStageMath,
      preferredFactionId: preferredFactionId ?? this.preferredFactionId,
      playerName: playerName ?? this.playerName,
    );
  }

  factory UserSettingsUi.fromRustJson(Map<String, dynamic> json) {
    return UserSettingsUi(
      defaultIterations:
          (json['default_iterations'] as num?)?.toInt() ?? 10000,
      showExactStageMath: json['show_exact_stage_math'] as bool? ?? true,
      preferredFactionId: json['preferred_faction_id']?.toString(),
      playerName: json['player_name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toRustJson() => {
        'default_iterations': defaultIterations,
        'show_exact_stage_math': showExactStageMath,
        'preferred_faction_id': preferredFactionId,
        'player_name': playerName,
      };
}

class PersonalDataStoreUi {
  final int schemaVersion;
  final List<ArmyListUi> armyLists;
  final List<WishlistItemUi> wishlistItems;
  final List<MatchRecordUi> matches;
  final List<SavedCalculationConfigUi> savedCalculations;
  final UserSettingsUi settings;

  const PersonalDataStoreUi({
    this.schemaVersion = 2,
    this.armyLists = const [],
    this.wishlistItems = const [],
    this.matches = const [],
    this.savedCalculations = const [],
    this.settings = const UserSettingsUi(),
  });

  PersonalDataStoreUi copyWith({
    int? schemaVersion,
    List<ArmyListUi>? armyLists,
    List<WishlistItemUi>? wishlistItems,
    List<MatchRecordUi>? matches,
    List<SavedCalculationConfigUi>? savedCalculations,
    UserSettingsUi? settings,
  }) {
    return PersonalDataStoreUi(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      armyLists: armyLists ?? this.armyLists,
      wishlistItems: wishlistItems ?? this.wishlistItems,
      matches: matches ?? this.matches,
      savedCalculations: savedCalculations ?? this.savedCalculations,
      settings: settings ?? this.settings,
    );
  }

  factory PersonalDataStoreUi.fromRustJson(Map<String, dynamic> json) {
    return PersonalDataStoreUi(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 2,
      armyLists: (json['army_lists'] as List? ?? [])
          .map((e) => ArmyListUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      wishlistItems: (json['wishlist_items'] as List? ?? [])
          .map((e) => WishlistItemUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      matches: (json['matches'] as List? ?? [])
          .map((e) => MatchRecordUi.fromRustJson(Map<String, dynamic>.from(e)))
          .toList(),
      savedCalculations: (json['saved_calculations'] as List? ?? [])
          .map((e) => SavedCalculationConfigUi.fromRustJson(
              Map<String, dynamic>.from(e)))
          .toList(),
      settings: UserSettingsUi.fromRustJson(
          Map<String, dynamic>.from(json['settings'] as Map? ?? {})),
    );
  }

  Map<String, dynamic> toRustJson() => {
        'schema_version': schemaVersion,
        'army_lists': armyLists.map((e) => e.toRustJson()).toList(),
        'wishlist_items': wishlistItems.map((e) => e.toRustJson()).toList(),
        'matches': matches.map((e) => e.toRustJson()).toList(),
        'saved_calculations':
            savedCalculations.map((e) => e.toRustJson()).toList(),
        'settings': settings.toRustJson(),
      };
}
