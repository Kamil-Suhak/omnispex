/**
 * Omnispex Multi-User Key-Authenticated Cloud Sync Worker (Cloudflare D1)
 *
 * Architectural Guarantees:
 * - Key-based authentication without a login system: clients generate a unique
 *   cryptographic key on first launch (`omnispex_<64-hex>`) and pass it via
 *   `Authorization: Bearer <key>`. Inputting the same key on any platform
 *   retrieves and modifies that key's data.
 * - Zero plaintext key storage: the Worker hashes the key with SHA-256 (`key_hash`)
 *   before touching D1.
 * - Normalized remote tables (`army_rosters`, `wishlists`, `match_history`),
 *   scoped per `(key_hash, id)` and `game_system` (`wh40k` | `kill_team`).
 */

export interface Env {
  DB: D1Database;
  ALLOWED_ORIGIN?: string;
}

const MAX_BODY_BYTES = 1_048_576; // 1 MiB
const MIN_KEY_LENGTH = 32;
const MAX_KEY_LENGTH = 256;

function corsHeaders(env: Env, request: Request): Record<string, string> {
  const allowedOrigin = env.ALLOWED_ORIGIN || '*';
  const reqOrigin = request.headers.get('Origin') || '*';
  const origin = allowedOrigin === '*' ? '*' : reqOrigin === allowedOrigin ? reqOrigin : allowedOrigin;

  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
    'Cache-Control': 'no-store',
  };
}

function jsonResponse(
  data: unknown,
  status: number,
  headers: Record<string, string>,
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ...headers,
    },
  });
}

export async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function extractBearerKey(request: Request): string | null {
  const auth = request.headers.get('Authorization') || '';
  if (!auth.startsWith('Bearer ')) {
    return null;
  }
  const token = auth.slice('Bearer '.length).trim();
  if (token.length < MIN_KEY_LENGTH || token.length > MAX_KEY_LENGTH) {
    return null;
  }
  if (!/^[A-Za-z0-9_\-]+$/.test(token)) {
    return null;
  }
  return token;
}

function normalizeGameSystem(raw: unknown): 'wh40k' | 'kill_team' {
  if (typeof raw === 'string') {
    const clean = raw.trim().toLowerCase();
    if (clean === 'kill_team' || clean === 'killteam' || clean === 'kt') {
      return 'kill_team';
    }
  }
  return 'wh40k';
}

function safeParseJson(raw: unknown): unknown {
  if (typeof raw !== 'string') {
    return raw ?? {};
  }
  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

async function readBoundedJson(request: Request): Promise<Record<string, unknown>> {
  const raw = await request.text();
  if (raw.length > MAX_BODY_BYTES) {
    throw new Error('PAYLOAD_TOO_LARGE');
  }
  const parsed = JSON.parse(raw);
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('INVALID_JSON_OBJECT');
  }
  return parsed as Record<string, unknown>;
}

async function ensureKeyRegistered(
  db: D1Database,
  keyHash: string,
  nowIso: string,
  ctx?: ExecutionContext,
): Promise<boolean> {
  const existing = await db
    .prepare('SELECT key_hash FROM api_keys WHERE key_hash = ?1')
    .bind(keyHash)
    .first<{ key_hash: string }>();

  const upsertStmt = db
    .prepare(
      `INSERT INTO api_keys (key_hash, created_at, last_active_at)
       VALUES (?1, ?2, ?2)
       ON CONFLICT(key_hash) DO UPDATE SET last_active_at = excluded.last_active_at`,
    )
    .bind(keyHash, nowIso);

  if (!existing) {
    await upsertStmt.run();
    return true;
  }

  if (ctx && typeof ctx.waitUntil === 'function') {
    ctx.waitUntil(upsertStmt.run());
  } else {
    await upsertStmt.run();
  }
  return false;
}

export default {
  async fetch(request: Request, env: Env, ctx?: ExecutionContext): Promise<Response> {
    const headers = corsHeaders(env, request);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers });
    }

    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, '') || '/';

    if (path === '/health' && request.method === 'GET') {
      return jsonResponse(
        {
          status: 'ok',
          service: 'omnispex-cloud-worker',
          auth: 'key_sha256',
          tables: ['army_rosters', 'wishlists', 'match_history'],
        },
        200,
        headers,
      );
    }

    const rawKey = extractBearerKey(request);
    if (!rawKey) {
      return jsonResponse(
        {
          error:
            'Missing or invalid access key. Provide Authorization: Bearer <omnispex_key> (minimum 32 characters).',
        },
        401,
        headers,
      );
    }

    const keyHash = await sha256Hex(rawKey);
    const nowIso = new Date().toISOString();
    const gameSystemFilter = url.searchParams.get('game_system')
      ? normalizeGameSystem(url.searchParams.get('game_system'))
      : null;

    try {
      // 1. Key verification / cross-platform key recovery check
      if (path === '/api/auth/verify' && request.method === 'POST') {
        const isNewKey = await ensureKeyRegistered(env.DB, keyHash, nowIso, ctx);

        const [rostersRes, wishlistsRes, matchesRes] = await env.DB.batch([
          env.DB.prepare('SELECT COUNT(*) AS cnt FROM army_rosters WHERE key_hash = ?1').bind(
            keyHash,
          ),
          env.DB.prepare('SELECT COUNT(*) AS cnt FROM wishlists WHERE key_hash = ?1').bind(
            keyHash,
          ),
          env.DB.prepare('SELECT COUNT(*) AS cnt FROM match_history WHERE key_hash = ?1').bind(
            keyHash,
          ),
        ]);

        const countFrom = (res: D1Result<unknown>): number => {
          const row = (res.results?.[0] || {}) as Record<string, unknown>;
          return Number(row.cnt || 0);
        };

        return jsonResponse(
          {
            ok: true,
            key_hash: keyHash,
            is_new_key: isNewKey,
            counts: {
              rosters: countFrom(rostersRes),
              wishlists: countFrom(wishlistsRes),
              matches: countFrom(matchesRes),
            },
          },
          200,
          headers,
        );
      }

      await ensureKeyRegistered(env.DB, keyHash, nowIso, ctx);

      // 2. Atomic multi-table pull: GET /api/sync
      if (path === '/api/sync' && request.method === 'GET') {
        const stmts = gameSystemFilter
          ? [
              env.DB.prepare(
                'SELECT id, game_system, faction_id, name, payload_json, updated_at FROM army_rosters WHERE key_hash = ?1 AND game_system = ?2 ORDER BY updated_at DESC',
              ).bind(keyHash, gameSystemFilter),
              env.DB.prepare(
                'SELECT id, game_system, faction_id, unit_id, payload_json, updated_at FROM wishlists WHERE key_hash = ?1 AND game_system = ?2 ORDER BY updated_at DESC',
              ).bind(keyHash, gameSystemFilter),
              env.DB.prepare(
                'SELECT id, game_system, payload_json, updated_at FROM match_history WHERE key_hash = ?1 AND game_system = ?2 ORDER BY updated_at DESC',
              ).bind(keyHash, gameSystemFilter),
            ]
          : [
              env.DB.prepare(
                'SELECT id, game_system, faction_id, name, payload_json, updated_at FROM army_rosters WHERE key_hash = ?1 ORDER BY updated_at DESC',
              ).bind(keyHash),
              env.DB.prepare(
                'SELECT id, game_system, faction_id, unit_id, payload_json, updated_at FROM wishlists WHERE key_hash = ?1 ORDER BY updated_at DESC',
              ).bind(keyHash),
              env.DB.prepare(
                'SELECT id, game_system, payload_json, updated_at FROM match_history WHERE key_hash = ?1 ORDER BY updated_at DESC',
              ).bind(keyHash),
            ];

        const [rostersRes, wishlistsRes, matchesRes] = await env.DB.batch(stmts);

        const formatRows = (rows: unknown[] = []) =>
          rows.map((r) => {
            const rec = r as Record<string, unknown>;
            return {
              ...rec,
              payload: safeParseJson(rec.payload_json),
            };
          });

        return jsonResponse(
          {
            ok: true,
            rosters: formatRows(rostersRes.results),
            wishlists: formatRows(wishlistsRes.results),
            matches: formatRows(matchesRes.results),
          },
          200,
          headers,
        );
      }

      // 3. Atomic multi-table batch write: POST /api/sync/batch
      if (path === '/api/sync/batch' && request.method === 'POST') {
        const body = await readBoundedJson(request);
        const statements: D1PreparedStatement[] = [];

        const rosters = Array.isArray(body.rosters) ? body.rosters : [];
        for (const item of rosters) {
          if (!item || typeof item !== 'object') continue;
          const rec = item as Record<string, unknown>;
          const id = String(rec.id || '').trim();
          if (!id) continue;
          const gs = normalizeGameSystem(rec.game_system);
          const factionId = String(rec.faction_id || '');
          const name = String(rec.name || '');
          const updatedAt = String(rec.updated_at || rec.updated_at_iso || nowIso);
          const payloadObj = rec.payload !== undefined ? rec.payload : rec;
          const payloadJson =
            typeof payloadObj === 'string' ? payloadObj : JSON.stringify(payloadObj);

          statements.push(
            env.DB.prepare(
              `INSERT INTO army_rosters (key_hash, id, game_system, faction_id, name, payload_json, updated_at)
               VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
               ON CONFLICT(key_hash, id) DO UPDATE SET
                 game_system = excluded.game_system,
                 faction_id = excluded.faction_id,
                 name = excluded.name,
                 payload_json = excluded.payload_json,
                 updated_at = excluded.updated_at
               WHERE excluded.updated_at >= army_rosters.updated_at`,
            ).bind(keyHash, id, gs, factionId, name, payloadJson, updatedAt),
          );
        }

        const wishlists = Array.isArray(body.wishlists) ? body.wishlists : [];
        for (const item of wishlists) {
          if (!item || typeof item !== 'object') continue;
          const rec = item as Record<string, unknown>;
          const id = String(rec.id || '').trim();
          if (!id) continue;
          const gs = normalizeGameSystem(rec.game_system);
          const factionId = String(rec.faction_id || '');
          const unitId = String(rec.unit_id || rec.operative_id || '');
          const updatedAt = String(rec.updated_at || rec.updated_at_iso || nowIso);
          const payloadObj = rec.payload !== undefined ? rec.payload : rec;
          const payloadJson =
            typeof payloadObj === 'string' ? payloadObj : JSON.stringify(payloadObj);

          statements.push(
            env.DB.prepare(
              `INSERT INTO wishlists (key_hash, id, game_system, faction_id, unit_id, payload_json, updated_at)
               VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
               ON CONFLICT(key_hash, id) DO UPDATE SET
                 game_system = excluded.game_system,
                 faction_id = excluded.faction_id,
                 unit_id = excluded.unit_id,
                 payload_json = excluded.payload_json,
                 updated_at = excluded.updated_at
               WHERE excluded.updated_at >= wishlists.updated_at`,
            ).bind(keyHash, id, gs, factionId, unitId, payloadJson, updatedAt),
          );
        }

        const matches = Array.isArray(body.matches) ? body.matches : [];
        for (const item of matches) {
          if (!item || typeof item !== 'object') continue;
          const rec = item as Record<string, unknown>;
          const id = String(rec.id || '').trim();
          if (!id) continue;
          const gs = normalizeGameSystem(rec.game_system);
          const updatedAt = String(rec.updated_at || rec.updated_at_iso || nowIso);
          const payloadObj = rec.payload !== undefined ? rec.payload : rec;
          const payloadJson =
            typeof payloadObj === 'string' ? payloadObj : JSON.stringify(payloadObj);

          statements.push(
            env.DB.prepare(
              `INSERT INTO match_history (key_hash, id, game_system, payload_json, updated_at)
               VALUES (?1, ?2, ?3, ?4, ?5)
               ON CONFLICT(key_hash, id) DO UPDATE SET
                 game_system = excluded.game_system,
                 payload_json = excluded.payload_json,
                 updated_at = excluded.updated_at
               WHERE excluded.updated_at >= match_history.updated_at`,
            ).bind(keyHash, id, gs, payloadJson, updatedAt),
          );
        }

        const delRosters = Array.isArray(body.deleted_roster_ids) ? body.deleted_roster_ids : [];
        for (const rawId of delRosters) {
          const id = String(rawId || '').trim();
          if (id) {
            statements.push(
              env.DB.prepare('DELETE FROM army_rosters WHERE key_hash = ?1 AND id = ?2').bind(
                keyHash,
                id,
              ),
            );
          }
        }

        const delWishlists = Array.isArray(body.deleted_wishlist_ids)
          ? body.deleted_wishlist_ids
          : [];
        for (const rawId of delWishlists) {
          const id = String(rawId || '').trim();
          if (id) {
            statements.push(
              env.DB.prepare('DELETE FROM wishlists WHERE key_hash = ?1 AND id = ?2').bind(
                keyHash,
                id,
              ),
            );
          }
        }

        const delMatches = Array.isArray(body.deleted_match_ids) ? body.deleted_match_ids : [];
        for (const rawId of delMatches) {
          const id = String(rawId || '').trim();
          if (id) {
            statements.push(
              env.DB.prepare('DELETE FROM match_history WHERE key_hash = ?1 AND id = ?2').bind(
                keyHash,
                id,
              ),
            );
          }
        }

        if (statements.length > 0) {
          await env.DB.batch(statements);
        }

        return jsonResponse(
          {
            ok: true,
            operations_executed: statements.length,
            synced_at: nowIso,
          },
          200,
          headers,
        );
      }

      // 4. Granular table endpoints: /api/rosters, /api/wishlists, /api/matches
      if (path === '/api/rosters' && request.method === 'GET') {
        const stmt = gameSystemFilter
          ? env.DB.prepare(
              'SELECT id, game_system, faction_id, name, payload_json, updated_at FROM army_rosters WHERE key_hash = ?1 AND game_system = ?2 ORDER BY updated_at DESC',
            ).bind(keyHash, gameSystemFilter)
          : env.DB.prepare(
              'SELECT id, game_system, faction_id, name, payload_json, updated_at FROM army_rosters WHERE key_hash = ?1 ORDER BY updated_at DESC',
            ).bind(keyHash);
        const res = await stmt.all();
        const items = (res.results || []).map((r) => {
          const rec = r as Record<string, unknown>;
          return { ...rec, payload: safeParseJson(rec.payload_json) };
        });
        return jsonResponse({ ok: true, rosters: items }, 200, headers);
      }

      const rosterMatch = path.match(/^\/api\/rosters\/([^/]+)$/);
      if (rosterMatch) {
        const rosterId = decodeURIComponent(rosterMatch[1]);
        if (request.method === 'PUT') {
          const body = await readBoundedJson(request);
          const gs = normalizeGameSystem(body.game_system);
          const factionId = String(body.faction_id || '');
          const name = String(body.name || '');
          const updatedAt = String(body.updated_at || body.updated_at_iso || nowIso);
          const payloadObj = body.payload !== undefined ? body.payload : body;
          const payloadJson =
            typeof payloadObj === 'string' ? payloadObj : JSON.stringify(payloadObj);

          await env.DB.prepare(
            `INSERT INTO army_rosters (key_hash, id, game_system, faction_id, name, payload_json, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
             ON CONFLICT(key_hash, id) DO UPDATE SET
               game_system = excluded.game_system,
               faction_id = excluded.faction_id,
               name = excluded.name,
               payload_json = excluded.payload_json,
               updated_at = excluded.updated_at
             WHERE excluded.updated_at >= army_rosters.updated_at`,
          )
            .bind(keyHash, rosterId, gs, factionId, name, payloadJson, updatedAt)
            .run();

          return jsonResponse(
            { ok: true, id: rosterId, game_system: gs, updated_at: updatedAt },
            200,
            headers,
          );
        }
        if (request.method === 'DELETE') {
          await env.DB.prepare('DELETE FROM army_rosters WHERE key_hash = ?1 AND id = ?2')
            .bind(keyHash, rosterId)
            .run();
          return jsonResponse({ ok: true, deleted_id: rosterId }, 200, headers);
        }
      }

      if (path === '/api/wishlists' && request.method === 'GET') {
        const stmt = gameSystemFilter
          ? env.DB.prepare(
              'SELECT id, game_system, faction_id, unit_id, payload_json, updated_at FROM wishlists WHERE key_hash = ?1 AND game_system = ?2 ORDER BY updated_at DESC',
            ).bind(keyHash, gameSystemFilter)
          : env.DB.prepare(
              'SELECT id, game_system, faction_id, unit_id, payload_json, updated_at FROM wishlists WHERE key_hash = ?1 ORDER BY updated_at DESC',
            ).bind(keyHash);
        const res = await stmt.all();
        const items = (res.results || []).map((r) => {
          const rec = r as Record<string, unknown>;
          return { ...rec, payload: safeParseJson(rec.payload_json) };
        });
        return jsonResponse({ ok: true, wishlists: items }, 200, headers);
      }

      const wishlistMatch = path.match(/^\/api\/wishlists\/([^/]+)$/);
      if (wishlistMatch) {
        const itemId = decodeURIComponent(wishlistMatch[1]);
        if (request.method === 'PUT') {
          const body = await readBoundedJson(request);
          const gs = normalizeGameSystem(body.game_system);
          const factionId = String(body.faction_id || '');
          const unitId = String(body.unit_id || body.operative_id || '');
          const updatedAt = String(body.updated_at || body.updated_at_iso || nowIso);
          const payloadObj = body.payload !== undefined ? body.payload : body;
          const payloadJson =
            typeof payloadObj === 'string' ? payloadObj : JSON.stringify(payloadObj);

          await env.DB.prepare(
            `INSERT INTO wishlists (key_hash, id, game_system, faction_id, unit_id, payload_json, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
             ON CONFLICT(key_hash, id) DO UPDATE SET
               game_system = excluded.game_system,
               faction_id = excluded.faction_id,
               unit_id = excluded.unit_id,
               payload_json = excluded.payload_json,
               updated_at = excluded.updated_at
             WHERE excluded.updated_at >= wishlists.updated_at`,
          )
            .bind(keyHash, itemId, gs, factionId, unitId, payloadJson, updatedAt)
            .run();

          return jsonResponse(
            { ok: true, id: itemId, game_system: gs, updated_at: updatedAt },
            200,
            headers,
          );
        }
        if (request.method === 'DELETE') {
          await env.DB.prepare('DELETE FROM wishlists WHERE key_hash = ?1 AND id = ?2')
            .bind(keyHash, itemId)
            .run();
          return jsonResponse({ ok: true, deleted_id: itemId }, 200, headers);
        }
      }

      if (path === '/api/matches' && request.method === 'GET') {
        const stmt = gameSystemFilter
          ? env.DB.prepare(
              'SELECT id, game_system, payload_json, updated_at FROM match_history WHERE key_hash = ?1 AND game_system = ?2 ORDER BY updated_at DESC',
            ).bind(keyHash, gameSystemFilter)
          : env.DB.prepare(
              'SELECT id, game_system, payload_json, updated_at FROM match_history WHERE key_hash = ?1 ORDER BY updated_at DESC',
            ).bind(keyHash);
        const res = await stmt.all();
        const items = (res.results || []).map((r) => {
          const rec = r as Record<string, unknown>;
          return { ...rec, payload: safeParseJson(rec.payload_json) };
        });
        return jsonResponse({ ok: true, matches: items }, 200, headers);
      }

      const matchRoute = path.match(/^\/api\/matches\/([^/]+)$/);
      if (matchRoute) {
        const matchId = decodeURIComponent(matchRoute[1]);
        if (request.method === 'PUT') {
          const body = await readBoundedJson(request);
          const gs = normalizeGameSystem(body.game_system);
          const updatedAt = String(body.updated_at || body.updated_at_iso || nowIso);
          const payloadObj = body.payload !== undefined ? body.payload : body;
          const payloadJson =
            typeof payloadObj === 'string' ? payloadObj : JSON.stringify(payloadObj);

          await env.DB.prepare(
            `INSERT INTO match_history (key_hash, id, game_system, payload_json, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5)
             ON CONFLICT(key_hash, id) DO UPDATE SET
               game_system = excluded.game_system,
               payload_json = excluded.payload_json,
               updated_at = excluded.updated_at
             WHERE excluded.updated_at >= match_history.updated_at`,
          )
            .bind(keyHash, matchId, gs, payloadJson, updatedAt)
            .run();

          return jsonResponse(
            { ok: true, id: matchId, game_system: gs, updated_at: updatedAt },
            200,
            headers,
          );
        }
        if (request.method === 'DELETE') {
          await env.DB.prepare('DELETE FROM match_history WHERE key_hash = ?1 AND id = ?2')
            .bind(keyHash, matchId)
            .run();
          return jsonResponse({ ok: true, deleted_id: matchId }, 200, headers);
        }
      }

      return jsonResponse({ error: `Route not found: ${request.method} ${path}` }, 404, headers);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      if (msg === 'PAYLOAD_TOO_LARGE') {
        return jsonResponse({ error: 'Payload exceeds 1 MiB limit.' }, 413, headers);
      }
      if (msg === 'INVALID_JSON_OBJECT' || err instanceof SyntaxError) {
        return jsonResponse({ error: 'Malformed JSON body.' }, 400, headers);
      }
      return jsonResponse({ error: 'Internal Worker error', detail: msg }, 500, headers);
    }
  },
};
