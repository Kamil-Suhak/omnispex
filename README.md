# Omnispex — Warhammer 40,000 & Kill Team Companion Engine

Omnispex is a comprehensive, local-first Warhammer companion application combining exact analytical probability mathematics, Monte Carlo discrete wound allocation simulations, a full 11th Edition BSData & Munitorum Field Manual (MFM v1.6) reference browser, a 40K army list builder with legality validation, army-organized unit wishlists, and match history/performance analytics for **Warhammer 40,000** and **Kill Team**.

## Architecture

**Rust Core (`omnispex_core`) → Rust CLI (`omnispex_cli`) + Rust Bridge (`omnispex_flutter`) → Flutter Android & Web (`flutter_ui`)**

All business logic is owned by the shared Rust core:
- **`crates/omnispex_core`**:
  - **Math & Simulation Engine (`engine/`)**: Exact analytical stage probabilities (`compute_exact_stage_probabilities`) + Monte Carlo discrete wound allocation (`run_simulation`, `run_squad_simulation`, `compare_profiles`, `evaluate_archetypes`) with explicit method attribution and informational/unsupported weapon ability notices.
  - **11th Edition Data Pipeline (`parser/` & `domain/catalogue.rs`)**: Multi-catalogue cross-reference indexer (`BsDataLookupIndex`) resolving `catalogueLinks`, `entryLinks`, `infoLinks`, `sharedSelectionEntries`, `sharedSelectionEntryGroups`, `sharedProfiles`, and `sharedRules` across `BSData/wh40k-11e`, merged with `BSData/wh40k-11e-mfm` v1.6 points, Requisition Thresholds (`[1,2]`, `[3,)`), and wargear costs (35 Factions, 690 Detachments, 1,531 Datasheets).
  - **Army List Builder & Validator (`domain/army_list.rs`)**: Dynamic 11e Requisition Threshold pricing (`recalculate_points`), Detachment Points (`DP`) budget checks, Warlord & Epic Hero uniqueness, Enhancement slot limits (including 2-slot `(Upgrade)` enhancements), Rule of 3 / Rule of 2 (`Incursion`), Dedicated Transport capacity checks, and explicit separation of confirmed violations from unverified prose rules.
  - **Unit Wishlists (`domain/wishlist.rs`)**: Faction-scoped collection planning, deduplicated upserts, hobby progress states (`Wishlist` → `Parade Ready`), filtering, sorting, and collection completion summaries.
  - **Match History & Analytics (`domain/matches.rs`)**: Distinct scoring models for **Warhammer 40,000** (5 Battle Rounds, Primary/Secondary/Battle Ready) and **Kill Team** (4 Turning Points, Crit Op/Tac Op/Kill Op/Primary Op 50% bonus/Painted bonus) with mathematically verified win rates, differentials, and faction breakdowns.
  - **Local-First Persistence (`storage.rs`)**: Versioned `PersonalDataStore` with schema migration (`v0 → v1 → v2`) and JSON backup export/restore isolated from game catalogue updates.
- **`crates/omnispex_cli`**: Full-featured Rust CLI exposing `simulate`, `run-matchup`, `build-catalogue-bundle`, `search-units`, `validate-list`, and `match-stats`.
- **`crates/omnispex_flutter`**: Cross-platform C-ABI & WebAssembly bridge compiled to Windows (`omnispex_flutter.dll`), Android (`libomnispex_flutter.so` for `arm64-v8a` & `x86_64`), and Web (`omnispex_flutter.wasm`).
- **`flutter_ui`**: Dark-first tactical Flutter interface for Android, Web, and Desktop.

## CLI Usage

```bash
# 1. Ad-hoc attack/defense probability simulation (Exact Stage Math + Monte Carlo)
cargo run -p omnispex_cli -- simulate --attacks 20 --bs 3 --str 4 --ap 0 --dmg 1 --target-t 4 --target-sv 3 --target-w 2 --target-count 5

# 2. Build normalized 11th Edition BSData + MFM v1.6 catalogue bundle
cargo run --release -p omnispex_cli -- build-catalogue-bundle --bsdata-dir ./wh40k-11e --mfm-dir ./wh40k-11e-mfm/data --output ./flutter_ui/assets/data/wh40k_11e_bundle.json

# 3. Search units across the normalized 11e bundle
cargo run -p omnispex_cli -- search-units --bundle ./flutter_ui/assets/data/wh40k_11e_bundle.json --query "Terminator" --faction "Space Marines"

# 4. Validate an 11th Edition Army List JSON file and print formatted roster
cargo run -p omnispex_cli -- validate-list --list ./my_list.json --bundle ./flutter_ui/assets/data/wh40k_11e_bundle.json

# 5. Compute Warhammer 40,000 & Kill Team match statistics from a PersonalDataStore backup
cargo run -p omnispex_cli -- match-stats --file ./personal_backup.json
```

## Platform Deployment Pipelines

Omnispex supports automated release packaging for **Rust CLI**, **Flutter Android** (APK and Google Play `.aab`), **Flutter Web** (WebAssembly SPA), and **Desktop** (Windows, Linux, macOS).

Complete build, cross-compilation, Keystore signing, NGINX hosting, and CI/CD instructions are documented in:
👉 [**docs/DEPLOYMENT.md**](docs/DEPLOYMENT.md)

## Attribution & Data Provenance

Game data is sourced from the community-maintained [BSData/wh40k-11e](https://github.com/BSData/wh40k-11e) repository (`b4dc3f40ca39ae551e480228186e769344a36194`) and Munitorum Field Manual v1.6 points from [BSData/wh40k-11e-mfm](https://github.com/BSData/wh40k-11e-mfm) (`11c45c5f062d26d6468b8b2156c7a8e258013ef5`). Omnispex is an unofficial companion application and is not affiliated with or endorsed by Games Workshop.
