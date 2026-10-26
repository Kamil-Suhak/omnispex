/**
 * Omnispex Cloudflare Worker
 *
 * Responsibilities:
 * 1. Cryptographically authenticated cloud storage & sync API for user army lists,
 *    wishlists, and match histories via Cloudflare D1 SQLite.
 * 2. Static asset hosting for the compiled Flutter Web application & WebAssembly engine (`omnispex_flutter.wasm`).
 */

export interface Env {
  DB: D1Database;
  ASSETS?: Fetcher;
}

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Access-Control-Max-Age": "86400",
};

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...CORS_HEADERS,
    },
  });
}

function errorResponse(message: string, status = 400): Response {
  return jsonResponse({ ok: false, error: message }, status);
}

async function hashSecret(secret: string): Promise<string> {
  const msgUint8 = new TextEncoder().encode(secret);
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgUint8);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Authenticates the request against the D1 `users` table using a Bearer token secret.
 * On first use for a new user_id, auto-registers the user with the provided secret.
 */
async function authenticateUser(
  request: Request,
  userId: string,
  env: Env
): Promise<{ ok: boolean; error?: string }> {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return { ok: false, error: "Missing or malformed Authorization header. Expected 'Bearer <secret_key>'" };
  }

  const secretKey = authHeader.substring(7).trim();
  if (secretKey.length < 8) {
    return { ok: false, error: "Secret key must be at least 8 characters long" };
  }

  const secretHash = await hashSecret(secretKey);

  try {
    const user = await env.DB.prepare(
      "SELECT user_id, secret_hash FROM users WHERE user_id = ?"
    )
      .bind(userId)
      .first<{ user_id: string; secret_hash: string }>();

    if (!user) {
      // First time this user_id is seen: auto-register with this secret
      await env.DB.prepare(
        "INSERT INTO users (user_id, secret_hash, created_at, last_active_at) VALUES (?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
      )
        .bind(userId, secretHash)
        .run();
      return { ok: true };
    }

    if (user.secret_hash !== secretHash) {
      return { ok: false, error: "Unauthorized: Invalid secret key for this user" };
    }

    // Touch last_active_at asynchronously
    env.DB.prepare("UPDATE users SET last_active_at = CURRENT_TIMESTAMP WHERE user_id = ?")
      .bind(userId)
      .run()
      .catch(() => {});

    return { ok: true };
  } catch (err: unknown) {
    return { ok: false, error: `Authentication error: ${err instanceof Error ? err.message : String(err)}` };
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // 1. CORS Pre-flight Handling
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: CORS_HEADERS,
      });
    }

    // 2. API Endpoints (`/api/*`)
    if (url.pathname.startsWith("/api/")) {
      return handleApiRequest(url, request, env);
    }

    // 3. Flutter Web Static Assets & SPA Routing
    if (env.ASSETS) {
      let response = await env.ASSETS.fetch(request);

      // SPA fallback: Route all non-file subpaths to index.html
      if (response.status === 404 && !url.pathname.includes(".")) {
        const fallbackUrl = new URL("/index.html", request.url);
        response = await env.ASSETS.fetch(new Request(fallbackUrl.toString(), request));
      }

      // Ensure proper WebAssembly content type
      if (url.pathname.endsWith(".wasm")) {
        const headers = new Headers(response.headers);
        headers.set("Content-Type", "application/wasm");
        return new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers,
        });
      }

      return response;
    }

    // 4. Fallback landing page if ASSETS binding is absent
    return new Response(
      `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Omnispex Cloud Worker</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0c0f14; color: #e2e8f0; padding: 2rem; max-width: 800px; margin: 0 auto; line-height: 1.6; }
    h1 { color: #f59e0b; border-bottom: 1px solid #334155; padding-bottom: 0.5rem; }
    code { background: #1e293b; color: #38bdf8; padding: 0.2rem 0.4rem; border-radius: 4px; }
    .badge { display: inline-block; background: #065f46; color: #34d399; padding: 0.2rem 0.6rem; border-radius: 9999px; font-size: 0.875rem; font-weight: 600; margin-bottom: 1rem; }
    .card { background: #131923; border: 1px solid #202b3c; border-radius: 8px; padding: 1.5rem; margin-top: 1.5rem; }
  </style>
</head>
<body>
  <div class="badge">SYSTEM ONLINE // OMNISPEX CLOUD v1.0.0 (AUTHENTICATED)</div>
  <h1>Omnispex Cloud Cogitator & Sync Gateway</h1>
  <p>Edge cloud storage and synchronization service for Warhammer 40,000 & Kill Team army rosters, wishlists, and match analytics.</p>
  <div class="card">
    <h3>Active Endpoints</h3>
    <ul>
      <li><code>GET /api/health</code> — Gateway health and database status</li>
      <li><code>POST /api/auth/register</code> — Register or verify client device credentials</li>
      <li><code>GET /api/sync/:userId</code> — Retrieve full synchronized user store [Auth Required]</li>
      <li><code>POST /api/sync/:userId</code> — Upsert full user personal data store [Auth Required]</li>
      <li><code>GET /api/rosters/:userId</code> — Query user army rosters [Auth Required]</li>
      <li><code>POST /api/rosters/:userId</code> — Upsert individual army roster [Auth Required]</li>
      <li><code>DELETE /api/rosters/:userId/:rosterId</code> — Delete individual army roster [Auth Required]</li>
      <li><code>GET /api/wishlists/:userId</code> — Query faction wishlists [Auth Required]</li>
      <li><code>POST /api/wishlists/:userId</code> — Upsert faction wishlists [Auth Required]</li>
    </ul>
  </div>
</body>
</html>`,
      {
        headers: { "Content-Type": "text/html; charset=utf-8", ...CORS_HEADERS },
      }
    );
  },
};

async function handleApiRequest(url: URL, request: Request, env: Env): Promise<Response> {
  const path = url.pathname;

  // GET /api/health
  if (path === "/api/health") {
    try {
      const dbCheck = await env.DB.prepare("SELECT 1 as alive").first<{ alive: number }>();
      const userCount = await env.DB.prepare("SELECT count(*) as count FROM users").first<{ count: number }>();
      return jsonResponse({
        status: "ok",
        service: "omnispex-cloud",
        version: "1.0.0",
        database: dbCheck?.alive === 1 ? "connected" : "unknown",
        active_users: userCount?.count ?? 0,
        timestamp: new Date().toISOString(),
      });
    } catch (err: unknown) {
      return jsonResponse({
        status: "degraded",
        service: "omnispex-cloud",
        version: "1.0.0",
        database_error: err instanceof Error ? err.message : String(err),
        timestamp: new Date().toISOString(),
      });
    }
  }

  // POST /api/auth/register
  if (path === "/api/auth/register" && request.method === "POST") {
    interface AuthPayload {
      user_id?: string;
      secret_key?: string;
    }
    let payload: AuthPayload;
    try {
      payload = (await request.json()) as AuthPayload;
    } catch {
      return errorResponse("Invalid JSON payload");
    }

    const userId = payload.user_id || `user_${crypto.randomUUID().replace(/-/g, "").substring(0, 16)}`;
    const secretKey = payload.secret_key || `sec_${crypto.randomUUID().replace(/-/g, "")}`;

    const authRes = await authenticateUser(
      new Request(request.url, {
        headers: { Authorization: `Bearer ${secretKey}` },
      }),
      userId,
      env
    );

    if (!authRes.ok) {
      return errorResponse(authRes.error || "Authentication failed", 401);
    }

    return jsonResponse({
      ok: true,
      user_id: userId,
      secret_key: secretKey,
      message: "Device authenticated successfully",
    });
  }

  // --- /api/sync/:userId ---
  const syncMatch = path.match(/^\/api\/sync\/([^/]+)$/);
  if (syncMatch) {
    const userId = decodeURIComponent(syncMatch[1]);
    const auth = await authenticateUser(request, userId, env);
    if (!auth.ok) return errorResponse(auth.error || "Unauthorized", 401);

    if (request.method === "GET") {
      const row = await env.DB.prepare("SELECT data, updated_at FROM user_sync WHERE user_id = ?")
        .bind(userId)
        .first<{ data: string; updated_at: string }>();

      if (!row) {
        return jsonResponse({ ok: true, exists: false, data: null });
      }

      try {
        return jsonResponse({
          ok: true,
          exists: true,
          data: JSON.parse(row.data),
          updated_at: row.updated_at,
        });
      } catch {
        return jsonResponse({ ok: true, exists: true, data: row.data, updated_at: row.updated_at });
      }
    }

    if (request.method === "POST" || request.method === "PUT") {
      let body: unknown;
      try {
        body = await request.json();
      } catch {
        return errorResponse("Invalid JSON payload");
      }

      const jsonStr = typeof body === "string" ? body : JSON.stringify(body);

      await env.DB.prepare(
        `INSERT INTO user_sync (user_id, data, updated_at) 
         VALUES (?, ?, CURRENT_TIMESTAMP) 
         ON CONFLICT(user_id) DO UPDATE SET data = excluded.data, updated_at = CURRENT_TIMESTAMP`
      )
        .bind(userId, jsonStr)
        .run();

      return jsonResponse({
        ok: true,
        message: "Synchronized user store successfully",
        updated_at: new Date().toISOString(),
      });
    }

    return errorResponse(`Method ${request.method} not allowed`, 405);
  }

  // --- /api/rosters/:userId ---
  const rostersMatch = path.match(/^\/api\/rosters\/([^/]+)$/);
  if (rostersMatch) {
    const userId = decodeURIComponent(rostersMatch[1]);
    const auth = await authenticateUser(request, userId, env);
    if (!auth.ok) return errorResponse(auth.error || "Unauthorized", 401);

    if (request.method === "GET") {
      const { results } = await env.DB.prepare(
        "SELECT roster_id, name, faction, points, roster_json, updated_at FROM user_rosters WHERE user_id = ? ORDER BY updated_at DESC"
      )
        .bind(userId)
        .all<{
          roster_id: string;
          name: string;
          faction: string;
          points: number;
          roster_json: string;
          updated_at: string;
        }>();

      const rosters = (results || []).map((r) => {
        try {
          return { ...r, roster: JSON.parse(r.roster_json) };
        } catch {
          return r;
        }
      });

      return jsonResponse({ ok: true, rosters });
    }

    if (request.method === "POST" || request.method === "PUT") {
      interface RosterPayload {
        id?: string;
        roster_id?: string;
        name?: string;
        faction?: string;
        points?: number;
      }
      let payload: RosterPayload;
      try {
        payload = (await request.json()) as RosterPayload;
      } catch {
        return errorResponse("Invalid JSON payload");
      }

      const rosterId = payload.id || payload.roster_id || crypto.randomUUID();
      const name = payload.name || "Untitled Roster";
      const faction = payload.faction || "Unknown Faction";
      const points = typeof payload.points === "number" ? payload.points : 0;
      const jsonStr = JSON.stringify(payload);

      await env.DB.prepare(
        `INSERT INTO user_rosters (user_id, roster_id, name, faction, points, roster_json, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
         ON CONFLICT(user_id, roster_id) DO UPDATE SET 
           name = excluded.name, 
           faction = excluded.faction, 
           points = excluded.points, 
           roster_json = excluded.roster_json, 
           updated_at = CURRENT_TIMESTAMP`
      )
        .bind(userId, rosterId, name, faction, points, jsonStr)
        .run();

      return jsonResponse({
        ok: true,
        roster_id: rosterId,
        message: "Roster saved successfully",
      });
    }

    return errorResponse(`Method ${request.method} not allowed`, 405);
  }

  // --- /api/rosters/:userId/:rosterId ---
  const singleRosterMatch = path.match(/^\/api\/rosters\/([^/]+)\/([^/]+)$/);
  if (singleRosterMatch) {
    const userId = decodeURIComponent(singleRosterMatch[1]);
    const rosterId = decodeURIComponent(singleRosterMatch[2]);
    const auth = await authenticateUser(request, userId, env);
    if (!auth.ok) return errorResponse(auth.error || "Unauthorized", 401);

    if (request.method === "DELETE") {
      await env.DB.prepare("DELETE FROM user_rosters WHERE user_id = ? AND roster_id = ?")
        .bind(userId, rosterId)
        .run();
      return jsonResponse({ ok: true, message: "Roster deleted" });
    }
  }

  // --- /api/wishlists/:userId ---
  const wishlistsMatch = path.match(/^\/api\/wishlists\/([^/]+)$/);
  if (wishlistsMatch) {
    const userId = decodeURIComponent(wishlistsMatch[1]);
    const auth = await authenticateUser(request, userId, env);
    if (!auth.ok) return errorResponse(auth.error || "Unauthorized", 401);

    if (request.method === "GET") {
      const { results } = await env.DB.prepare(
        "SELECT faction_id, wishlist_json, updated_at FROM user_wishlists WHERE user_id = ? ORDER BY updated_at DESC"
      )
        .bind(userId)
        .all<{ faction_id: string; wishlist_json: string; updated_at: string }>();

      const wishlists = (results || []).map((w) => {
        try {
          return { ...w, wishlist: JSON.parse(w.wishlist_json) };
        } catch {
          return w;
        }
      });

      return jsonResponse({ ok: true, wishlists });
    }

    if (request.method === "POST" || request.method === "PUT") {
      interface WishlistPayload {
        faction_id?: string;
        id?: string;
      }
      let payload: WishlistPayload;
      try {
        payload = (await request.json()) as WishlistPayload;
      } catch {
        return errorResponse("Invalid JSON payload");
      }

      const factionId = payload.faction_id || payload.id || "general";
      const jsonStr = JSON.stringify(payload);

      await env.DB.prepare(
        `INSERT INTO user_wishlists (user_id, faction_id, wishlist_json, updated_at)
         VALUES (?, ?, ?, CURRENT_TIMESTAMP)
         ON CONFLICT(user_id, faction_id) DO UPDATE SET 
           wishlist_json = excluded.wishlist_json, 
           updated_at = CURRENT_TIMESTAMP`
      )
        .bind(userId, factionId, jsonStr)
        .run();

      return jsonResponse({
        ok: true,
        faction_id: factionId,
        message: "Wishlist saved successfully",
      });
    }

    return errorResponse(`Method ${request.method} not allowed`, 405);
  }

  return errorResponse("Endpoint not found", 404);
}
