# Omnispex — Project Overview

## Vision

**Omnispex is an all-in-one, cross-platform Warhammer companion application** designed to bring army building, rules reference, collection planning, combat calculations, and match tracking into a single, cohesive experience.

The goal is to create a free, reliable, and intuitive platform that players can use throughout their entire Warhammer experience, from planning their next army to playing and reviewing games.

Rather than requiring players to switch between multiple specialized tools, Omnispex aims to provide a unified environment where game data, army rosters, and match information work together seamlessly.

## Core Functionality

Omnispex combines several interconnected features:

- **Army List Builder:** Create, manage, and validate army rosters, accounting for faction rules, detachments, unit restrictions, and contextual abilities.
- **Datasheet & Rules Browser:** Quickly access unit profiles, weapons, abilities, detachments, and other relevant game information.
- **Unit Wishlist:** Track desired units and plan future army purchases or collection expansions.
- **Damage Calculator:** Estimate combat outcomes using unit statistics, weapon profiles, and applicable modifiers.
- **Match History:** Record games, opponents, armies, scores, and results.
- **Live Game Companion (Planned):** Track victory points, command points, and other game-state information during matches.
- **Cloud Synchronization:** Keep personal rosters, wishlists, and match records available across devices.

## Technical Vision

Omnispex is built around a shared Rust core, a Flutter interface targeting Android and web browsers, and cloud infrastructure for distribution and synchronization.

A central data pipeline ingests community-maintained Warhammer data and transforms it into a consistent, validated representation shared across the application's features.

The architecture aims to prioritize correctness, performance, offline usability, maintainability, and extensibility. Game rules and data should be modeled centrally rather than independently implemented by individual features.

## Purpose

Existing Warhammer tools often specialize in individual aspects of the hobby, requiring players to manage information across separate applications.

Omnispex aims to address this fragmentation by connecting those experiences through a common data model and consistent interface.

Its long-term ambition is to become a dependable daily-use companion for Warhammer players: accessible, free to use, and capable of supporting a broader community through cloud-backed accounts and shared infrastructure.

## Development Direction

Omnispex is initially being developed as a personal daily driver, with plans to expand testing to a small group of Warhammer players before considering a wider public release.

Development prioritizes a trustworthy data foundation, accurate game mechanics, responsive interfaces, and reliable persistence over rapid feature expansion.

**The guiding principle is simple: one application, one consistent source of game information, and a connected experience across every stage of playing Warhammer.**
