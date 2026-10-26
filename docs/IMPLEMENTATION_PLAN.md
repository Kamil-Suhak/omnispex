# Omnispex — Comprehensive Architecture & Implementation Plan

## 1. Initial Codebase Audit Summary

### 1.1 Existing Repository Structure
- `crates/omnispex_core`: Shared Rust engine for Warhammer 40,000 dice probability & Monte Carlo combat simulation.
- `crates/omnispex_cli`: Rust command-line tool wrapping `omnispex_core`.
- `crates/omnispex_flutter`: Rust FFI / WebAssembly bridge crate exposing APIs to Flutter.
- `flutter_ui`: Flutter application (Android, Web, Desktop) using `flutter_riverpod`, `fl_chart`, `google_fonts`, and a dark-first "Imperial Cogitator / Tactical Instrument" theme (`OmnispexColors`, `OmnispexTypography`).

### 1.2 Completed Architectural Refactoring & Enhancements
1. **Unified Rust Domain & Business Logic (`crates/omnispex_core`)**:
   - **Exact Analytical + Monte Carlo Engine**: Added `compute_exact_stage_probabilities` (`StageProbabilities`) alongside Monte Carlo discrete wound allocation (`run_simulation`, `run_squad_simulation`, `compare_profiles`, `evaluate_archetypes`), hit/wound re-rolls (`ReRollMode`), hit/wound modifiers, bonus Strength/AP, defensive counter-stratagems, `safe_bet_damage_80`, `bracket_50_probability`, `calculation_method` attribution, and `unsupported_notices` for non-numerical weapon abilities (`Hazardous`, `Precision`, `Assault`, `Pistol`, `One Shot`, `Extra Attacks`).
   - **11th Edition BSData + MFM v1.6 Data Pipeline (`parser/` & `domain/catalogue.rs`)**:
     - Multi-catalogue cross-reference indexer (`BsDataLookupIndex`) resolving `catalogueLinks`, `entryLinks`, `infoLinks`, `sharedSelectionEntries`, `sharedSelectionEntryGroups`, `sharedProfiles`, and `sharedRules` across `BSData/wh40k-11e`.
     - MFM v1.6 YAML parser & merger (`parse_mfm_faction_yaml`, `merge_mfm_into_faction`) integrating points, 11e Requisition Threshold tiers (`[1,2]`, `[3,)`), and wargear costs.
     - Generated normalized offline bundle `flutter_ui/assets/data/wh40k_11e_bundle.json` containing **35 Factions, 690 Detachments, and 1,531 Datasheets**.
   - **11e Army List Builder & Validator (`domain/army_list.rs`)**:
     - Dynamic 11e Requisition Threshold pricing (`recalculate_points`), Detachment Points (`DP`) budget checks (`Incursion 2 DP`, `Strike Force 3 DP`, `Onslaught 4 DP`), Enhancement slot limits (including 2-slot `(Upgrade)` enhancements), Warlord & Epic Hero uniqueness, Rule of 3 / Rule of 2 (`Incursion`), Dedicated Transport capacity checks, and explicit separation of confirmed violations from unverified prose rules.
   - **Unit Wishlists (`domain/wishlist.rs`)**:
     - Army-scoped wishlists with deduplicated upserts, desired/owned quantities, priority (`Low`, `Medium`, `High`, `Critical`), hobby state (`Wishlist` → `Parade Ready`), search/filter/sort, and completion summaries.
   - **Match History & Analytics (`domain/matches.rs`)**:
     - Separate rule/scoring models for **Warhammer 40,000** (5 Battle Rounds, Primary/Secondary/Battle Ready) and **Kill Team** (4 Turning Points, Crit Op/Tac Op/Kill Op/Primary Op 50% bonus/Painted bonus) with mathematically verified statistics (`compute_match_statistics`).
   - **Local-First Persistence (`storage.rs`)**:
     - Versioned `PersonalDataStore` with schema migration (`v0 → v1 → v2`) and JSON backup export/restore isolated from game catalogue updates.
2. **Rust CLI (`crates/omnispex_cli`)**:
   - Implemented 6 subcommands: `simulate`, `run-matchup`, `build-catalogue-bundle`, `search-units`, `validate-list`, and `match-stats`.
3. **Cross-Platform Rust Bridge (`crates/omnispex_flutter`)**:
   - Built native Windows (`omnispex_flutter.dll`), WebAssembly (`flutter_ui/web/omnispex_flutter.wasm`), and Android (`jniLibs/arm64-v8a/libomnispex_flutter.so` & `jniLibs/x86_64/libomnispex_flutter.so`) artifacts.
4. **Cohesive Flutter UI (`flutter_ui`)**:
   - Implemented 6-destination responsive navigation (`In-Battle`, `List-Build`, `Datasheets`, `Wishlist`, `Matches`, `Settings`) with local-first persistence across Native and Web.

---

## 2. Implementation Progress Tracker

- [x] Phase 0: Initial Codebase Audit & Implementation Plan (`docs/IMPLEMENTATION_PLAN.md`)
- [x] Phase 1: Rust Core Expansion (`omnispex_core`) — Math, 11e Data Pipeline, Army Lists, Wishlist, Matches, Storage
- [x] Phase 2: 11th Edition BSData + MFM v1.6 Asset Bundle Generation (35 Factions, 690 Detachments, 1,531 Datasheets)
- [x] Phase 3: Rust CLI Expansion (`omnispex_cli`)
- [x] Phase 4: Rust-Flutter Bridge (`omnispex_flutter` — Native FFI DLL + Android `.so` + WebAssembly `.wasm`)
- [x] Phase 5: Flutter UI & Local-First Persistence (`flutter_ui`)
- [x] Phase 6: Final Verification (`cargo test --workspace`, `flutter analyze`, `flutter test`, `flutter build web --wasm`)

---

## 3. Product Verification Status

All implementation milestones are fully completed and verified:
1. **Rust Workspace Tests**: `cargo test --workspace` passed 22/22 unit tests (`omnispex_core`, `omnispex_flutter`).
2. **Flutter Static Analysis**: `flutter analyze` completed with 0 errors.
3. **Flutter Widget & State Tests**: `flutter test` passed all 11/11 tests across `test/design_system_test.dart` and `test/widget_test.dart`.
4. **Cross-Platform Bridge Targets**:
   - Native Windows: `target/release/omnispex_flutter.dll` and `flutter_ui/omnispex_flutter.dll`.
   - WebAssembly: `flutter_ui/web/omnispex_flutter.wasm` and `flutter build web --wasm` (compiled in 62.2s).
   - Android: `flutter_ui/android/app/src/main/jniLibs/arm64-v8a/libomnispex_flutter.so` and `x86_64/libomnispex_flutter.so`.
5. **11th Edition Offline Game Data Bundle**:
   - `flutter_ui/assets/data/wh40k_11e_bundle.json` with 35 Factions, 690 Detachments, and 1,531 Datasheets with MFM v1.6 points and Requisition Threshold pricing tiers.
