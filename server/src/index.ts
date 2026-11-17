/**
 * WonderWorld 3D — Cloudflare Durable Object room server.
 * No chat, no email addresses, no passwords, no analytics, no payments.
 * Up to eight clients per unlisted eight-character room code.
 * Godot sends compact JSON WebSocket frames. This server owns room membership,
 * the scoreboard and coin collection, and broadcasts player positions.
 *
 * MVP NOTE: movement is client-predicted and only lightly validated. Before
 * offering public play, add stronger authoritative movement/anti-cheat,
 * identity/abuse controls and a child-safety/privacy review.
 */
import { DurableObject } from "cloudflare:workers";

interface Env {
  ROOMS: DurableObjectNamespace<AdventureRoom>;
}

type Player = {
  id: string;
  n: string;
  c: number;
  x: number;
  y: number;
  z: number;
  r: number;
  score: number;
  lastMove: number;
  lastTravel: number;
};

type SavedPlayer = Pick<Player, "id" | "n" | "c" | "score">;
const ALIASES = ["Sunny", "Rocket", "Pixel", "Comet", "Star", "Sprout", "Bubbles", "Nova"];
const ROOM_PATTERN = /^[A-HJ-NP-Z2-9]{8}$/;
const MAX_PLAYERS = 8;
const WORLD_LIMIT = 56;
const TRAVEL_STOPS: ReadonlyArray<readonly [number, number, number]> = [
  [0, 1.55, 12.0], [0, 1.55, -25.0], [-34, 1.55, 21.0],
  [-32, 1.55, -31.0], [25, 1.55, 17.5], [24, 1.55, -25.0],
];
const COIN_REAPPEAR_MS = 24000;
const COINS: ReadonlyArray<readonly [number, number, number]> = [
  [0, 1.15, 6], [5, 1.15, 1], [-5, 1.15, 1],
  [10, 1.15, 10], [-10, 1.15, 10],
  [0, 1.15, -14], [0, 1.15, -24], [0, 1.15, -30],
  [-28, 1.15, 20], [-34, 1.15, 25],
  [-34, 1.15, -30], [-40, 1.15, -29],
  [20, 1.15, 17], [40, 1.15, 17],
  [40, 1.15, 35], [20, 1.15, 35],
  [17, 1.5, -29], [22, 1.65, -25],
  [27, 2.8, -26], [37, 3.85, -27],
];

function safeSend(socket: WebSocket, payload: unknown) {
  try {
    socket.send(JSON.stringify(payload));
  } catch {
    // Connection may have dropped; close/error callback will remove it.
  }
}

function playerPublic(p: Player) {
  return { id: p.id, n: p.n, c: p.c, x: p.x, y: p.y, z: p.z, r: p.r, score: p.score };
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/health") {
      return Response.json({ ok: true, game: "WonderWorld 3D", maxPlayers: MAX_PLAYERS });
    }
    const match = /^\/room\/([^/]+)$/.exec(url.pathname);
    if (!match || !ROOM_PATTERN.test(match[1])) {
      return new Response("Invalid room. Use /room/ABCDEFG2 (eight valid characters).", { status: 400 });
    }
    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("WebSocket required", { status: 426 });
    }
    // Same room code always goes to the same single-coordinator Durable Object.
    const id = env.ROOMS.idFromName(match[1]);
    return env.ROOMS.get(id).fetch(request);
  },
};

export class AdventureRoom extends DurableObject<Env> {
  private players = new Map<WebSocket, Player>();
  private collected = new Map<number, number>(); // coin id -> expiration epoch ms
  private lastSweep = 0;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    // Restore connected clients after WebSocket hibernation.
    for (const ws of ctx.getWebSockets()) {
      const saved = ws.deserializeAttachment() as SavedPlayer | null;
      if (!saved) continue;
      this.players.set(ws, {
        ...saved, x: 0, y: 1.55, z: 5, r: 0, lastMove: 0, lastTravel: 0,
      });
    }
    // Collected coins persist across hibernation for predictable gameplay.
    ctx.blockConcurrencyWhile(async () => {
      const stored = (await ctx.storage.get<Record<string, number>>("taken")) ?? {};
      const now = Date.now();
      for (const [key, expires] of Object.entries(stored)) {
        const cid = Number(key);
        if (Number.isInteger(cid) && expires > now && cid >= 0 && cid < COINS.length) {
          this.collected.set(cid, expires);
        }
      }
    });
  }

  async fetch(request: Request): Promise<Response> {
    if (this.ctx.getWebSockets().length >= MAX_PLAYERS) {
      return new Response("Room full (maximum eight players).", { status: 429 });
    }
    const url = new URL(request.url);
    const rawAlias = url.searchParams.get("alias") ?? "Sunny";
    const alias = ALIASES.includes(rawAlias) ? rawAlias : "Sunny";
    const rawColor = Number(url.searchParams.get("avatar") ?? "0");
    const color = Number.isInteger(rawColor) ? Math.max(0, Math.min(7, rawColor)) : 0;
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    const id = crypto.randomUUID().slice(0, 12);
    const newcomer: Player = {
      id, n: alias, c: color, x: 0, y: 1.55, z: 5, r: 0, score: 0, lastMove: 0, lastTravel: 0,
    };
    const others = [...this.players.values()].map(playerPublic);
    server.serializeAttachment({ id, n: alias, c: color, score: 0 } satisfies SavedPlayer);
    this.ctx.acceptWebSocket(server);
    this.players.set(server, newcomer);
    safeSend(server, {
      t: "welcome", id, room: url.pathname.split("/").at(-1),
      score: 0, players: others, taken: [...this.collected.keys()],
    });
    this.broadcast({ t: "join", player: playerPublic(newcomer) }, server);
    return new Response(null, { status: 101, webSocket: client });
  }

  private broadcast(data: unknown, except?: WebSocket) {
    for (const ws of this.ctx.getWebSockets()) {
      if (ws !== except) safeSend(ws, data);
    }
  }

  private async persistCoins() {
    await this.ctx.storage.put("taken", Object.fromEntries(this.collected));
  }

  private async sweepExpired() {
    const now = Date.now();
    if (now - this.lastSweep < 2600) return;
    this.lastSweep = now;
    const reset: number[] = [];
    for (const [coin, expiration] of this.collected) {
      if (expiration <= now) {
        this.collected.delete(coin);
        reset.push(coin);
      }
    }
    if (reset.length > 0) {
      await this.persistCoins();
      this.broadcast({ t: "reset", coins: reset });
    }
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer) {
    const p = this.players.get(ws);
    if (!p || typeof message !== "string" || message.length > 256) return;
    let msg: Record<string, unknown>;
    try {
      msg = JSON.parse(message);
      if (!msg || typeof msg !== "object" || Array.isArray(msg)) return;
    } catch {
      return;
    }
    await this.sweepExpired();
    if (msg.t === "ping") {
      return;
    }
    if (msg.t === "travel") {
      // Enumerated map destinations prevent arbitrary-position teleport cheating.
      const stop = msg.stop;
      if (typeof stop !== "number" || !Number.isInteger(stop) || stop < 0 || stop >= TRAVEL_STOPS.length) {
        safeSend(ws, { t: "travel_reject", reason: "Unknown destination" });
        return;
      }
      const now = Date.now();
      if (now - p.lastTravel < 1200) {
        safeSend(ws, { t: "travel_reject", reason: "Travel cooldown — try again" });
        return;
      }
      const [x, y, z] = TRAVEL_STOPS[stop];
      p.x = x; p.y = y; p.z = z;
      p.lastMove = now;
      p.lastTravel = now;
      safeSend(ws, { t: "travel_ok", stop, x, y, z });
      this.broadcast({ t: "move", id: p.id, x, y, z, r: p.r }, ws);
      return;
    }
    if (msg.t === "move") {
      const values = [msg.x, msg.y, msg.z, msg.r];
      if (!values.every((n) => typeof n === "number" && Number.isFinite(n))) return;
      const [x, y, z, r] = values as number[];
      if (Math.abs(x) > WORLD_LIMIT || Math.abs(z) > WORLD_LIMIT || y < -8 || y > 15 || Math.abs(r) > 7) return;
      const now = Date.now();
      if (now - p.lastMove < 120) return; // protect CPU and free request budgets
      const seconds = Math.max(0.16, (now - p.lastMove) / 1000);
      const dist = Math.hypot(x - p.x, y - p.y, z - p.z);
      if (p.lastMove && dist > Math.max(3.5, seconds * 12.0)) return;
      p.x = x; p.y = y; p.z = z; p.r = r; p.lastMove = now;
      this.broadcast({ t: "move", id: p.id, x, y, z, r }, ws);
      return;
    }
    if (msg.t === "collect") {
      const coin = msg.coin;
      if (typeof coin !== "number" || !Number.isInteger(coin) || coin < 0 || coin >= COINS.length) return;
      const [cx, cy, cz] = COINS[coin];
      const dist = Math.hypot(p.x - cx, p.y - cy, p.z - cz);
      if (this.collected.has(coin) || dist > 2.6) {
        safeSend(ws, { t: "reject", coin });
        return;
      }
      this.collected.set(coin, Date.now() + COIN_REAPPEAR_MS);
      p.score += 10;
      ws.serializeAttachment({ id: p.id, n: p.n, c: p.c, score: p.score } satisfies SavedPlayer);
      await this.persistCoins();
      this.broadcast({ t: "score", id: p.id, score: p.score, coin });
      return;
    }
  }

  private removePlayer(ws: WebSocket) {
    const p = this.players.get(ws);
    if (!p) return;
    this.players.delete(ws);
    this.broadcast({ t: "leave", id: p.id }, ws);
  }

  webSocketClose(ws: WebSocket, code: number, reason: string) {
    this.removePlayer(ws);
    try { ws.close(code, reason); } catch { /* already closed */ }
  }

  webSocketError(ws: WebSocket) {
    this.removePlayer(ws);
    try { ws.close(1011, "Socket error"); } catch { /* already closed */ }
  }
}
