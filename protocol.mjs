// Fast protocol smoke test with a tiny in-memory Cloudflare runtime mock.
// Run: npm install && npm test  (tests core protocol; does not replace Cloudflare/live phone testing)
import assert from 'node:assert/strict';
import fs from 'node:fs';
import ts from 'typescript';

const source = fs.readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8')
  .replace('import { DurableObject } from "cloudflare:workers";', '');
const { outputText, diagnostics } = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 },
  reportDiagnostics: true,
});
assert.equal(diagnostics?.length ?? 0, 0);

class MockSocket {
  messages = [];
  saved = null;
  serializeAttachment(value) { this.saved = value; }
  deserializeAttachment() { return this.saved; }
  send(text) { this.messages.push(JSON.parse(text)); }
  close() {}
}
globalThis.WebSocketPair = class {
  constructor() { return { client: new MockSocket(), server: new MockSocket() }; }
};
globalThis.Response = class {
  constructor(body, opts = {}) { this.body = body; this.status = opts.status ?? 200; this.webSocket = opts.webSocket; }
  static json(value) { return { status: 200, json: () => value }; }
};
const prefix = `class DurableObject { constructor(ctx, env) { this.ctx = ctx; this.env = env; } }\n`;
const mod = await import(`data:text/javascript;base64,${Buffer.from(prefix + outputText).toString('base64')}`);

const storage = new Map();
const ctx = {
  sockets: [],
  acceptWebSocket(ws) { this.sockets.push(ws); },
  getWebSockets() { return this.sockets; },
  storage: {
    async get(k) { return storage.get(k); },
    async put(k, v) { storage.set(k, v); },
  },
  blockConcurrencyWhile(fn) { this.ready = fn(); },
};
const room = new mod.AdventureRoom(ctx, {});
await ctx.ready;
const env = { ROOMS: { idFromName: (name) => name, get: () => ({ fetch: (req) => room.fetch(req) }) } };
const health = await mod.default.fetch(new Request('https://example.workers.dev/health'), env);
assert.equal((await health.json()).ok, true);

const connect = async (alias, avatar = 0) => {
  const req = new Request(`https://example.workers.dev/room/ABCDEFG2?alias=${alias}&avatar=${avatar}`, { headers: { Upgrade: 'websocket' } });
  const response = await mod.default.fetch(req, env);
  assert.equal(response.status, 101);
  return ctx.sockets.at(-1);
};
const alice = await connect('Sunny', 0);
const bob = await connect('Rocket', 1);
assert.equal(alice.messages[0].t, 'welcome');
assert.equal(bob.messages[0].players.length, 1);
assert.equal(alice.messages.at(-1).t, 'join');

await room.webSocketMessage(alice, JSON.stringify({ t: 'move', x: 0, y: 1.1, z: -5, r: 0 }));
assert.equal(bob.messages.at(-1).t, 'move');
await room.webSocketMessage(alice, JSON.stringify({ t: 'collect', coin: 0 }));
assert.equal(bob.messages.at(-1).t, 'score');
assert.equal(bob.messages.at(-1).score, 10);
await room.webSocketMessage(bob, JSON.stringify({ t: 'collect', coin: 0 }));
assert.equal(bob.messages.at(-1).t, 'reject');
assert.equal(storage.get('taken')['0'] > Date.now(), true);
for (let i=0;i<6;i++) await connect('Star');
const ninth = await mod.default.fetch(new Request('https://example.workers.dev/room/ABCDEFG2', { headers: { Upgrade: 'websocket' } }), env);
assert.equal(ninth.status, 429);
const malformed = await mod.default.fetch(new Request('https://example.workers.dev/room/OOPS', { headers: { Upgrade: 'websocket' } }), env);
assert.equal(malformed.status, 400);
room.webSocketClose(alice, 1000, 'left');
assert.equal(bob.messages.at(-1).t, 'leave');
console.log('PASS: health, rooms, joining, live move, shared coins, leaderboard, room capacity, invalid codes, leave');
