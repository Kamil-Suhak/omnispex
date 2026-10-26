# Omnispex Flutter Application (`flutter_ui`)

The client presentation layer for **Omnispex** — an offline-first tactical companion application for Warhammer 40,000 (11th Edition) and Kill Team players.

Omnispex is built with Flutter (Android, Web, and Desktop) and powered by a shared Rust engine (`omnispex_core`).

---

## Architecture Overview

Omnispex follows a strict separation of concerns:
- **Rust Core (`crates/omnispex_core`)**: Owns 100% of the game mathematics, discrete wound allocation simulations, army list legality validation, catalogue indexing, and personal data storage models.
- **Flutter Client (`flutter_ui`)**: Pure presentation layer. Flutter never writes ad-hoc Warhammer rules, calculation approximations, or list validation logic in Dart.

```
Flutter UI (Dart / Riverpod)
     │
     ├── In-Memory Catalogue: BsDataService (reads assets/data/wh40k_11e_bundle.json)
     ├── Storage Adapters: PersonalDataService (Native File I/O or Web IndexedDB)
     └── Rust Engine RPC: OmnispexRustBridge
              │
              ├── Android / Desktop: dart:ffi ──► libomnispex_flutter.so / .dll
              └── Web: dart:js_interop ──────────► omnispex_flutter.wasm
```

---

## Project Structure

```
flutter_ui/
├── assets/
│   └── data/
│       └── wh40k_11e_bundle.json    # Normalized 11th Edition BSData & MFM v1.6 bundle
├── lib/
│   ├── bridge/
│   │   ├── omnispex_rust_bridge.dart # Platform-agnostic bridge contract
│   │   ├── rust_bridge_native.dart   # Native C-FFI / JNI dynamic loader
│   │   ├── rust_bridge_web.dart      # WebAssembly JS interop loader
│   │   └── rust_bridge_stub.dart     # Compile-time conditional stub
│   ├── models/
│   │   ├── bsdata_models.dart        # Factions, datasheets, weapons, detachments
│   │   ├── omnispex_models.dart      # Army rosters, wishlists, match records
│   │   └── simulation_models.dart    # Combat profiles, target profiles, duel stats
│   ├── providers/
│   │   └── app_state_provider.dart   # Riverpod application state & reactivity
│   ├── screens/
│   │   ├── army_list_builder_screen.dart # 11e Army Builder with live Rust validation
│   │   ├── in_battle_screen.dart     # Real-time combat & probability calculator
│   │   ├── wishlist_screen.dart      # Faction-scoped unit wishlists & summaries
│   │   ├── matches_screen.dart       # 40K (5-round) & Kill Team (4-TP) match tracking
│   │   ├── unit_browser_screen.dart  # Searchable 11e reference for 35 factions
│   │   ├── settings_screen.dart      # Data export/import, backup, and provenance
│   │   └── main_shell.dart           # Tactical navigation shell
│   ├── services/
│   │   ├── bsdata_service.dart       # Fast in-memory queries & faction indexing
│   │   ├── personal_data_service.dart# Local-first persistence coordinator
│   │   ├── storage_adapter_native.dart# Android/Desktop file storage
│   │   └── storage_adapter_web.dart   # Browser IndexedDB / localStorage
│   ├── theme/
│   │   └── omnispex_theme.dart       # Tactical dark grimdark design system
│   └── widgets/                      # Charts, metric cards, duel bars, stat badges
└── web/
    ├── index.html                    # WASM bootstrap & memory manager
    └── omnispex_flutter.wasm         # Compiled Rust WebAssembly module
```

---

## Key Features

1. **Army List Builder & Legal Validator**:
   - Live 11th Edition legality verification powered by Rust (`validate_army_roster_rpc`).
   - Validates points budgets, detachment DP limits, Warlord selection, Epic Hero uniqueness, Enhancement limits, and transport capacities.
   - Text roster export and printable format.
2. **Combat Probability Calculator**:
   - Exact analytical stage expectations ($P(\text{Hit})$, $P(\text{Wound})$, $P(\text{Unsaved})$).
   - Monte Carlo discrete model-by-model allocation simulations (handling re-rolls, critical hits, blast, damage truncation, and defensive abilities).
3. **Faction Unit Wishlists**:
   - Faction-specific collection planning.
   - Tracks model progress (`Wanted`, `Ordered`, `Building`, `Painting`, `Ready`) and priorities.
   - Complete wishlist summary metrics and one-click import into army lists.
4. **Match Performance Tracker**:
   - Dedicated scoring for **Warhammer 40,000** (5 Battle Rounds, Primary/Secondary/Battle Ready) and **Kill Team** (4 Turning Points, Crit Op/Tac Op/Kill Op).
   - Historical win/loss statistics, point differentials, and faction win-rate tracking.
5. **Datasheet & Rules Reference**:
   - Instant search across 35 factions, 690 detachments, and 1,531 datasheets sourced from the official 11th Edition BSData repository.

---

## Local Development & Running

### 1. Flutter Web
Ensure the WebAssembly module is compiled before launching web:
```bash
# Compile Rust WASM module from root:
cargo build --target wasm32-unknown-unknown --release -p omnispex_flutter
cp target/wasm32-unknown-unknown/release/omnispex_flutter.wasm flutter_ui/web/

# Run web app locally:
cd flutter_ui
flutter run -d chrome
```

### 2. Android
Ensure the native shared libraries (`.so`) are built for your target device or emulator ABI:
```bash
# Build Android JNI libraries from root:
cargo ndk -t arm64-v8a -t x86_64 -o flutter_ui/android/app/src/main/jniLibs build --release -p omnispex_flutter

# Run on connected device or emulator:
cd flutter_ui
flutter run -d android
```

### 3. Windows Desktop
```bash
# Compile native DLL from root:
cargo build --release -p omnispex_flutter
cp target/release/omnispex_flutter.dll flutter_ui/

# Run Windows desktop app:
cd flutter_ui
flutter run -d windows
```

---

## Verification & Testing

```bash
cd flutter_ui

# Fetch packages
flutter pub get

# Static analysis (ensures zero errors)
flutter analyze
```

---

## Full Deployment Pipeline

For end-to-end production build instructions, cross-compilation matrix, Keystore signing, NGINX configuration, and GitHub Actions CI/CD workflows, see the root deployment guide:

👉 [**docs/DEPLOYMENT.md**](../docs/DEPLOYMENT.md)
