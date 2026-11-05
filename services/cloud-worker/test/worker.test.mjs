import { describe, it } from "node:test";
import assert from "node:assert/strict";
import worker, { sha256Hex } from "../src/index.ts";

class MockD1Database {
  constructor() {
    this.apiKeys = new Map();
    this.armyRosters = new Map();
    this.wishlists = new Map();
    this.matchHistory = new Map();
  }

  prepare(query) {
    const db = this;
    let bound = [];

    const stmt = {
      bind(...args) {
        bound = args;
        return stmt;
      },
      async first() {
        if (query.includes("SELECT key_hash FROM api_keys WHERE key_hash = ?1")) {
          const kh = bound[0];
          return db.apiKeys.get(kh) || null;
        }
        return null;
      },
      async all() {
        if (query.includes("SELECT COUNT(*) AS cnt FROM army_rosters")) {
          const kh = bound[0];
          const cnt = Array.from(db.armyRosters.values()).filter((r) => r.key_hash === kh).length;
          return { results: [{ cnt }] };
        }
        if (query.includes("SELECT COUNT(*) AS cnt FROM wishlists")) {
          const kh = bound[0];
          const cnt = Array.from(db.wishlists.values()).filter((w) => w.key_hash === kh).length;
          return { results: [{ cnt }] };
        }
        if (query.includes("SELECT COUNT(*) AS cnt FROM match_history")) {
          const kh = bound[0];
          const cnt = Array.from(db.matchHistory.values()).filter((m) => m.key_hash === kh).length;
          return { results: [{ cnt }] };
        }
        if (query.includes("FROM army_rosters WHERE key_hash = ?1")) {
          const kh = bound[0];
          const gs = bound[1];
          const results = Array.from(db.armyRosters.values()).filter(
            (r) => r.key_hash === kh && (!gs || r.game_system === gs),
          );
          return { results };
        }
        if (query.includes("FROM wishlists WHERE key_hash = ?1")) {
          const kh = bound[0];
          const gs = bound[1];
          const results = Array.from(db.wishlists.values()).filter(
            (w) => w.key_hash === kh && (!gs || w.game_system === gs),
          );
          return { results };
        }
        if (query.includes("FROM match_history WHERE key_hash = ?1")) {
          const kh = bound[0];
          const gs = bound[1];
          const results = Array.from(db.matchHistory.values()).filter(
            (m) => m.key_hash === kh && (!gs || m.game_system === gs),
          );
          return { results };
        }
        return { results: [] };
      },
      async run() {
        if (query.includes("INSERT INTO api_keys")) {
          const [keyHash, nowIso] = bound;
          const existing = db.apiKeys.get(keyHash);
          db.apiKeys.set(keyHash, {
            key_hash: keyHash,
            created_at: existing ? existing.created_at : nowIso,
            last_active_at: nowIso,
          });
          return { success: true };
        }
        if (query.includes("INSERT INTO army_rosters")) {
          const [keyHash, id, gameSystem, factionId, name, payloadJson, updatedAt] = bound;
          const k = `${keyHash}:${id}`;
          const existing = db.armyRosters.get(k);
          if (!existing || updatedAt >= existing.updated_at) {
            db.armyRosters.set(k, {
              key_hash: keyHash,
              id,
              game_system: gameSystem,
              faction_id: factionId,
              name,
              payload_json: payloadJson,
              updated_at: updatedAt,
            });
          }
          return { success: true };
        }
        if (query.includes("DELETE FROM army_rosters")) {
          const [keyHash, id] = bound;
          db.armyRosters.delete(`${keyHash}:${id}`);
          return { success: true };
        }
        if (query.includes("INSERT INTO wishlists")) {
          const [keyHash, id, gameSystem, factionId, unitId, payloadJson, updatedAt] = bound;
          const k = `${keyHash}:${id}`;
          const existing = db.wishlists.get(k);
          if (!existing || updatedAt >= existing.updated_at) {
            db.wishlists.set(k, {
              key_hash: keyHash,
              id,
              game_system: gameSystem,
              faction_id: factionId,
              unit_id: unitId,
              payload_json: payloadJson,
              updated_at: updatedAt,
            });
          }
          return { success: true };
        }
        if (query.includes("DELETE FROM wishlists")) {
          const [keyHash, id] = bound;
          db.wishlists.delete(`${keyHash}:${id}`);
          return { success: true };
        }
        if (query.includes("INSERT INTO match_history")) {
          const [keyHash, id, gameSystem, payloadJson, updatedAt] = bound;
          const k = `${keyHash}:${id}`;
          const existing = db.matchHistory.get(k);
          if (!existing || updatedAt >= existing.updated_at) {
            db.matchHistory.set(k, {
              key_hash: keyHash,
              id,
              game_system: gameSystem,
              payload_json: payloadJson,
              updated_at: updatedAt,
            });
          }
          return { success: true };
        }
        if (query.includes("DELETE FROM match_history")) {
          const [keyHash, id] = bound;
          db.matchHistory.delete(`${keyHash}:${id}`);
          return { success: true };
        }
        return { success: true };
      },
    };
    return stmt;
  }

  async batch(statements) {
    const out = [];
    for (const s of statements) {
      await s.run();
      const res = await s.all();
      out.push(res);
    }
    return out;
  }
}

describe("Omnispex Multi-User Key-Authenticated Cloud Worker", () => {
  const env = {
    DB: new MockD1Database(),
  };

  const userKeyA = "omnispex_a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90";
  const userKeyB = "omnispex_9999999999999999999999999999999999999999999999999999999999999999";

  const headersA = {
    "Content-Type": "application/json",
    Authorization: `Bearer ${userKeyA}`,
  };
  const headersB = {
    "Content-Type": "application/json",
    Authorization: `Bearer ${userKeyB}`,
  };

  it("handles CORS OPTIONS preflight", async () => {
    const req = new Request("http://localhost/health", { method: "OPTIONS" });
    const res = await worker.fetch(req, env);
    assert.equal(res.status, 204);
    assert.equal(res.headers.get("Access-Control-Allow-Origin"), "*");
  });

  it("GET /health returns status ok and normalized table list without auth", async () => {
    const req = new Request("http://localhost/health", { method: "GET" });
    const res = await worker.fetch(req, env);
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.status, "ok");
    assert.equal(data.auth, "key_sha256");
    assert.deepEqual(data.tables, ["army_rosters", "wishlists", "match_history"]);
  });

  it("rejects requests without valid 32+ char Bearer key", async () => {
    const req1 = new Request("http://localhost/api/rosters", { method: "GET" });
    const res1 = await worker.fetch(req1, env);
    assert.equal(res1.status, 401);

    const req2 = new Request("http://localhost/api/rosters", {
      method: "GET",
      headers: { Authorization: "Bearer too_short" },
    });
    const res2 = await worker.fetch(req2, env);
    assert.equal(res2.status, 401);
  });

  it("POST /api/auth/verify registers a new key using SHA-256 hash and never stores raw key", async () => {
    const req = new Request("http://localhost/api/auth/verify", {
      method: "POST",
      headers: headersA,
    });
    const res = await worker.fetch(req, env);
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.ok, true);
    assert.equal(data.is_new_key, true);
    assert.equal(data.key_hash, await sha256Hex(userKeyA));
    assert.equal(env.DB.apiKeys.has(userKeyA), false, "Raw key must never be stored in D1");
    assert.equal(env.DB.apiKeys.has(data.key_hash), true, "SHA-256 key_hash must be stored in D1");

    // Second verify with same key from another device returns is_new_key: false
    const reqSecond = new Request("http://localhost/api/auth/verify", {
      method: "POST",
      headers: headersA,
    });
    const resSecond = await worker.fetch(reqSecond, env);
    const dataSecond = await resSecond.json();
    assert.equal(dataSecond.is_new_key, false);
  });

  it("isolates army_rosters, wishlists, and match_history strictly by key_hash and game_system", async () => {
    // User A saves a 40K roster and a Kill Team roster
    const put40k = new Request("http://localhost/api/rosters/r-40k-1", {
      method: "PUT",
      headers: headersA,
      body: JSON.stringify({
        game_system: "wh40k",
        faction_id: "orks",
        name: "Waaagh Strike Force",
        updated_at: "2026-11-05T01:00:00Z",
        payload: { id: "r-40k-1", name: "Waaagh Strike Force", points_limit: 2000 },
      }),
    });
    assert.equal((await worker.fetch(put40k, env)).status, 200);

    const putKt = new Request("http://localhost/api/rosters/r-kt-1", {
      method: "PUT",
      headers: headersA,
      body: JSON.stringify({
        game_system: "kill_team",
        faction_id: "kt-kommandos",
        name: "Kommandos Strike Team",
        updated_at: "2026-11-05T01:05:00Z",
        payload: { id: "r-kt-1", name: "Kommandos Strike Team" },
      }),
    });
    assert.equal((await worker.fetch(putKt, env)).status, 200);

    // User A saves a wishlist item
    const putWish = new Request("http://localhost/api/wishlists/w-1", {
      method: "PUT",
      headers: headersA,
      body: JSON.stringify({
        game_system: "wh40k",
        faction_id: "orks",
        unit_id: "u-boyz",
        updated_at: "2026-11-05T01:10:00Z",
        payload: { id: "w-1", unit_name: "Boyz", quantity_desired: 2 },
      }),
    });
    assert.equal((await worker.fetch(putWish, env)).status, 200);

    // User B queries rosters -> must see 0 rosters
    const resB = await worker.fetch(
      new Request("http://localhost/api/rosters", { method: "GET", headers: headersB }),
      env,
    );
    const dataB = await resB.json();
    assert.equal(dataB.rosters.length, 0);

    // User A queries 40K rosters only
    const resA40k = await worker.fetch(
      new Request("http://localhost/api/rosters?game_system=wh40k", {
        method: "GET",
        headers: headersA,
      }),
      env,
    );
    const dataA40k = await resA40k.json();
    assert.equal(dataA40k.rosters.length, 1);
    assert.equal(dataA40k.rosters[0].name, "Waaagh Strike Force");

    // User A queries Kill Team rosters only
    const resAKt = await worker.fetch(
      new Request("http://localhost/api/rosters?game_system=kill_team", {
        method: "GET",
        headers: headersA,
      }),
      env,
    );
    const dataAKt = await resAKt.json();
    assert.equal(dataAKt.rosters.length, 1);
    assert.equal(dataAKt.rosters[0].name, "Kommandos Strike Team");
  });

  it("supports atomic batch sync and optimistic updated_at conflict protection", async () => {
    // Attempt to overwrite r-40k-1 with an older timestamp -> must be ignored
    const stalePut = new Request("http://localhost/api/rosters/r-40k-1", {
      method: "PUT",
      headers: headersA,
      body: JSON.stringify({
        game_system: "wh40k",
        faction_id: "orks",
        name: "Stale Name",
        updated_at: "2026-11-05T00:00:00Z",
        payload: { id: "r-40k-1", name: "Stale Name" },
      }),
    });
    await worker.fetch(stalePut, env);

    const syncGet = await worker.fetch(
      new Request("http://localhost/api/sync", { method: "GET", headers: headersA }),
      env,
    );
    const syncData = await syncGet.json();
    const r40k = syncData.rosters.find((r) => r.id === "r-40k-1");
    assert.equal(r40k.name, "Waaagh Strike Force", "Stale write must not overwrite newer row");

    // Batch delete w-1 and add match m-1
    const batchPost = new Request("http://localhost/api/sync/batch", {
      method: "POST",
      headers: headersA,
      body: JSON.stringify({
        deleted_wishlist_ids: ["w-1"],
        matches: [
          {
            id: "m-1",
            game_system: "wh40k",
            updated_at: "2026-11-05T02:00:00Z",
            payload: { id: "m-1", player_score: 90, opponent_score: 70 },
          },
        ],
      }),
    });
    const batchRes = await worker.fetch(batchPost, env);
    assert.equal(batchRes.status, 200);

    const syncAfter = await (
      await worker.fetch(
        new Request("http://localhost/api/sync", { method: "GET", headers: headersA }),
        env,
      )
    ).json();
    assert.equal(syncAfter.wishlists.length, 0);
    assert.equal(syncAfter.matches.length, 1);
    assert.equal(syncAfter.matches[0].payload.player_score, 90);
  });

  it("delegates static website asset requests to env.ASSETS binding", async () => {
    let fetchedPath = "";
    const mockAssets = {
      async fetch(req) {
        fetchedPath = new URL(req.url).pathname;
        return new Response("<html>Omnispex Web</html>", {
          status: 200,
          headers: { "Content-Type": "text/html" },
        });
      },
    };

    const envWithAssets = { DB: new MockD1Database(), ASSETS: mockAssets };

    // Root website request
    const rootRes = await worker.fetch(new Request("https://omnispex.workers.dev/"), envWithAssets);
    assert.equal(rootRes.status, 200);
    assert.equal(fetchedPath, "/");
    assert.equal(await rootRes.text(), "<html>Omnispex Web</html>");

    // Static bundle file request
    const wasmRes = await worker.fetch(
      new Request("https://omnispex.workers.dev/omnispex_flutter.wasm"),
      envWithAssets,
    );
    assert.equal(wasmRes.status, 200);
    assert.equal(fetchedPath, "/omnispex_flutter.wasm");
  });
});
