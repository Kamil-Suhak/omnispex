# Omnispex Engine

Omnispex is a high-performance, strictly typed Warhammer 40k attack resolution and probability engine written in Rust.

## Architecture

The workspace consists of:
- `omnispex_core`: Headless library containing domain models, dice rolling abstractions, rules pipeline, Monte Carlo simulation engine, and BSData catalog indexers.
- `omnispex_flutter`: Flutter-Rust Bridge layer exposing high-speed async APIs to the Flutter frontend.
- `omnispex_cli`: Terminal CLI wrapper providing subcommands for ad-hoc simulations and matchup evaluations with ASCII probability distribution histograms.
- `flutter_ui`: Cross-platform Flutter desktop and mobile application.

## Features

- **Discrete Damage Allocation**: Individual attacks are tracked against discrete model wound pools with casualty truncation (no illegal damage spillover).
- **Full Discrete Distributions**: Monte Carlo simulation produces mean kills, expected damage, squad wipe probabilities ($100\%$ casualty threshold), safe bet ($80\%$ floor), and discrete kill/damage histograms.
- **Strict 10th/11th Edition Rule Implementation**:
  - Hit roll resolution: natural 1 fails, natural 6 crits, Torrent, Heavy, Indirect Fire, Lethal Hits, Sustained Hits, $[-1, +1]$ modifier capping.
  - Wound roll resolution: $S$ vs $T$ table, natural 1 fails, natural 6 crits, Anti-Keyword $X+$, Lance, Twin-Linked re-rolls, Devastating Wounds, $[-1, +1]$ modifier capping.
  - Save resolution: $\min(\text{Armor} + \text{AP} - \text{Cover}, \text{Invulnerable Save})$ with allocation to wounded models first. Benefit of cover can be granted by terrain, abilities, or stratagems.
  - Mitigation & Truncation: Feel No Pain rolled per individual wound point; leftover attack damage discarded upon model destruction.
- **BSData Integration & Caching**: Fast indexing and offline unit search across Warhammer 40k factions with automatic defensive rule detection.

## Usage

```bash
# Ad-hoc simulation
cargo run -p omnispex_cli -- simulate --attacks 20 --bs 3 --str 4 --ap 0 --dmg 1 --target-t 3 --target-sv 6 --target-w 1 --target-count 10

# Run matchup from JSON profiles
cargo run -p omnispex_cli -- run-matchup --attacker weapon.json --defender target.json
```
