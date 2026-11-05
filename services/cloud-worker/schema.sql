-- Omnispex Multi-User Key-Authenticated Remote Schema (Cloudflare D1)
-- Raw access keys are never stored; only SHA-256(key) -> key_hash is persisted.

DROP TABLE IF EXISTS user_sync;
DROP TABLE IF EXISTS user_rosters;
DROP TABLE IF EXISTS user_wishlists;
DROP TABLE IF EXISTS users;

CREATE TABLE IF NOT EXISTS api_keys (
    key_hash TEXT PRIMARY KEY,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    last_active_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE IF NOT EXISTS army_rosters (
    key_hash TEXT NOT NULL,
    id TEXT NOT NULL,
    game_system TEXT NOT NULL DEFAULT 'wh40k',
    faction_id TEXT NOT NULL DEFAULT '',
    name TEXT NOT NULL DEFAULT '',
    payload_json TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    PRIMARY KEY (key_hash, id)
);

CREATE INDEX IF NOT EXISTS idx_army_rosters_key_system
    ON army_rosters(key_hash, game_system, updated_at DESC);

CREATE TABLE IF NOT EXISTS wishlists (
    key_hash TEXT NOT NULL,
    id TEXT NOT NULL,
    game_system TEXT NOT NULL DEFAULT 'wh40k',
    faction_id TEXT NOT NULL DEFAULT '',
    unit_id TEXT NOT NULL DEFAULT '',
    payload_json TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    PRIMARY KEY (key_hash, id)
);

CREATE INDEX IF NOT EXISTS idx_wishlists_key_system
    ON wishlists(key_hash, game_system, updated_at DESC);

CREATE TABLE IF NOT EXISTS match_history (
    key_hash TEXT NOT NULL,
    id TEXT NOT NULL,
    game_system TEXT NOT NULL DEFAULT 'wh40k',
    payload_json TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    PRIMARY KEY (key_hash, id)
);

CREATE INDEX IF NOT EXISTS idx_match_history_key_system
    ON match_history(key_hash, game_system, updated_at DESC);
