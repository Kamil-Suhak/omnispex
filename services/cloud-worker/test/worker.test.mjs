import { describe, it } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.ts";

// Mock D1 database implementation for local testing
class MockD1Database {
  constructor() {
    this.syncStore = new Map();
    this.rosterStore = new Map();
    this.wishlistStore = new Map();
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
        if (query.includes("SELECT 1 as alive")) {
          return { alive: 1 };
        }
        if (query.includes("FROM user_sync WHERE user_id = ?")) {
          const userId = bound[0];
          const item = db.syncStore.get(userId);
          return item ? { data: item.data, updated_at: item.updated_at } : null;
        }
        return null;
      },
      async all() {
        if (query.includes("FROM user_rosters WHERE user_id = ?")) {
          const userId = bound[0];
          const results = Array.from(db.rosterStore.values()).filter(
            (r) => r.user_id === userId
          );
          return { results };
        }
        if (query.includes("FROM user_wishlists WHERE user_id = ?")) {
          const userId = bound[0];
          const results = Array.from(db.wishlistStore.values()).filter(
            (w) => w.user_id === userId
          );
          return { results };
        }
        return { results: [] };
      },
      async run() {
        if (query.includes("INSERT INTO user_sync")) {
          const [userId, data] = bound;
          db.syncStore.set(userId, { data, updated_at: new Date().toISOString() });
          return { success: true };
        }
        if (query.includes("INSERT INTO user_rosters")) {
          const [userId, rosterId, name, faction, points, roster_json] = bound;
          db.rosterStore.set(`${userId}:${rosterId}`, {
            user_id: userId,
            roster_id: rosterId,
            name,
            faction,
            points,
            roster_json,
            updated_at: new Date().toISOString(),
          });
          return { success: true };
        }
        if (query.includes("DELETE FROM user_rosters")) {
          const [userId, rosterId] = bound;
          db.rosterStore.delete(`${userId}:${rosterId}`);
          return { success: true };
        }
        if (query.includes("INSERT INTO user_wishlists")) {
          const [userId, factionId, wishlist_json] = bound;
          db.wishlistStore.set(`${userId}:${factionId}`, {
            user_id: userId,
            faction_id: factionId,
            wishlist_json,
            updated_at: new Date().toISOString(),
          });
          return { success: true };
        }
        return { success: true };
      },
    };

    return stmt;
  }
}

describe("Omnispex Cloudflare Worker API", () => {
  const env = {
    DB: new MockD1Database(),
  };

  it("handles CORS OPTIONS preflight", async () => {
    const req = new Request("http://localhost/api/health", { method: "OPTIONS" });
    const res = await worker.fetch(req, env);
    assert.equal(res.status, 204);
    assert.equal(res.headers.get("Access-Control-Allow-Origin"), "*");
  });

  it("GET /api/health returns database status ok", async () => {
    const req = new Request("http://localhost/api/health", { method: "GET" });
    const res = await worker.fetch(req, env);
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.status, "ok");
    assert.equal(data.service, "omnispex-cloud");
    assert.equal(data.database, "connected");
  });

  it("POST /api/sync/:userId saves and GET retrieves user data", async () => {
    const userId = "inquisitor_kamil";
    const payload = {
      schema_version: 1,
      rosters: [{ id: "roster_1", name: "Speed Freeks", faction: "Orks" }],
      wishlists: [{ faction_id: "orks", entries: [{ unit_id: "ghaz" }] }],
    };

    const postReq = new Request(`http://localhost/api/sync/${userId}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const postRes = await worker.fetch(postReq, env);
    assert.equal(postRes.status, 200);
    const postData = await postRes.json();
    assert.equal(postData.ok, true);

    const getReq = new Request(`http://localhost/api/sync/${userId}`, { method: "GET" });
    const getRes = await worker.fetch(getReq, env);
    assert.equal(getRes.status, 200);
    const getData = await getRes.json();
    assert.equal(getData.ok, true);
    assert.equal(getData.exists, true);
    assert.equal(getData.data.rosters[0].name, "Speed Freeks");
  });

  it("POST /api/rosters/:userId upserts and GET returns rosters", async () => {
    const userId = "warlord_thraka";
    const roster = {
      id: "da_great_waaagh",
      name: "Da Great Waaagh!",
      faction: "Orks",
      points: 2000,
      units: [{ name: "Ghazghkull Thraka", points: 290 }],
    };

    const postReq = new Request(`http://localhost/api/rosters/${userId}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(roster),
    });
    const postRes = await worker.fetch(postReq, env);
    assert.equal(postRes.status, 200);

    const getReq = new Request(`http://localhost/api/rosters/${userId}`, { method: "GET" });
    const getRes = await worker.fetch(getReq, env);
    assert.equal(getRes.status, 200);
    const getData = await getRes.json();
    assert.equal(getData.rosters.length, 1);
    assert.equal(getData.rosters[0].name, "Da Great Waaagh!");
  });

  it("DELETE /api/rosters/:userId/:rosterId deletes the roster", async () => {
    const userId = "warlord_thraka";
    const delReq = new Request(`http://localhost/api/rosters/${userId}/da_great_waaagh`, {
      method: "DELETE",
    });
    const delRes = await worker.fetch(delReq, env);
    assert.equal(delRes.status, 200);

    const getReq = new Request(`http://localhost/api/rosters/${userId}`, { method: "GET" });
    const getRes = await worker.fetch(getReq, env);
    const getData = await getRes.json();
    assert.equal(getData.rosters.length, 0);
  });

  it("POST /api/wishlists/:userId saves and GET retrieves wishlists", async () => {
    const userId = "iron_priest";
    const wishlist = {
      faction_id: "space_wolves",
      entries: [{ unit_id: "bjorn", priority: "High", quantity: 1 }],
    };

    const postReq = new Request(`http://localhost/api/wishlists/${userId}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(wishlist),
    });
    const postRes = await worker.fetch(postReq, env);
    assert.equal(postRes.status, 200);

    const getReq = new Request(`http://localhost/api/wishlists/${userId}`, { method: "GET" });
    const getRes = await worker.fetch(getReq, env);
    assert.equal(getRes.status, 200);
    const getData = await getRes.json();
    assert.equal(getData.wishlists.length, 1);
    assert.equal(getData.wishlists[0].faction_id, "space_wolves");
  });
});

