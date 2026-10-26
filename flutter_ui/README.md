# Omnispex Flutter Application (`flutter_ui`)

The client presentation layer for **Omnispex** — a tactical companion application for Warhammer 40,000 (11th Edition) and Kill Team players.

Omnispex is built with Flutter (Android, Web, and Desktop) and powered by a shared Rust engine (`omnispex_core`).

---

## Architecture Overview

Omnispex follows a strict separation of concerns and a client-isolated, lazy-loading data flow:
- **Rust Core (`crates/omnispex_core`)**: Owns 100% of the game mathematics, discrete wound allocation simulations, army list legality validation, catalogue indexing, and personal data storage models.
- **Client Presentation & State (`flutter_ui`)**: Pure presentation and orchestration layer.
- **Client Data Ingestion**: Munitorum Field Manual (MFM v1.6) points costs and provenance revisions are initialized upfront. Faction data (35 factions) is streamed lazily and cached locally per-device on demand.
- **In-Memory Scoping**: Strict RAM boundaries (1 faction active in browser and list builder, at most 2 factions during battle simulation).
- **Cloud-Authoritative User Data**: User army rosters, wishlists, and matches are synchronized directly to the Cloudflare Worker API with cryptographic Bearer auth.

```
Flutter UI (Dart / Riverpod)
     │
     ├── In-Memory Catalogue: BsDataService (Lazy on-demand streaming from upstream BSData & MFM v1.6)
     ├── Storage Adapters: StorageAdapter (Client-isolated cache: SharedPreferences / localStorage)
     ├── Cloud Sync: PersonalDataService (Cloudflare Worker API + D1 SQLite with Bearer auth)
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
│   └── icons/                       # App icons and branding
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
│   │   ├── settings_screen.dart      # Faction download manager, cloud pairing key, provenance
│   │   └── main_shell.dart           # Tactical navigation shell
│   ├── services/
│   │   ├── auth_service.dart         # Device cryptographic identity & cloud credentials
│   │   ├── bsdata_service.dart       # Lazy faction streaming, caching & memory scoping
│   │   ├── faction_registry.dart     # Metadata registry for 35 Warhammer 40k factions
│   │   ├── personal_data_service.dart# Cloud-authoritative sync with offline mirror safety
│   │   ├── storage_adapter.dart      # Platform-agnostic client storage contract
│   │   ├── storage_adapter_native.dart# SharedPreferences adapter for Android/Desktop
│   │   └── storage_adapter_web.dart   # localStorage adapter for Browser
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
   - Search across 35 factions, 690 detachments, and 1,531 datasheets sourced on-demand from the official 11th Edition BSData repository.
   - Explicit confirmation prompts before downloading uncached factions with estimated file sizes.

---

## Local Development & Running

### 1. Flutter Web
Ensure the WebAssembly module is compiled before launching web:
```bash
# Compile Rust WASM module from root:
cargo build --target wasm32-unknown-unknown --release -p omnispex_flutter
cp target/wasm32-unknown-unknown/release/omnispex_flutter.wasm flutter_ui/web/

# Run web app locally with hot reload:
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

# Static analysis
flutter analyze --no-fatal-infos

# Run unit and widget tests
flutter test
```

---

## Full Deployment Pipeline

For end-to-end production build instructions, cross-compilation matrix, Keystore signing, Cloudflare Worker deployment, and GitHub Actions CI/CD workflows, see the root deployment guide:

👉 [**docs/DEPLOYMENT.md**](../docs/DEPLOYMENT.md)
