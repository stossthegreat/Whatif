// b62: duo rooms only get duo-safe games; groups get everything.
import WebSocket from 'ws';
const WS = 'ws://127.0.0.1:8091/ws';
const DUO_SAFE = new Set(['Face Off', 'Eye Contact', 'Hot Takes', 'Confessions', 'Would You Rather']);
let pass = 0, fail = 0;
const ok = (n, c, x='') => c ? (pass++, console.log(`  ✓ ${n}`)) : (fail++, console.log(`  ✗ ${n} ${x}`));

function connect(uid, name) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(WS);
    const events = [];
    const waiters = [];
    ws.on('message', (d) => {
      const m = JSON.parse(d.toString());
      events.push(m);
      for (let i = waiters.length - 1; i >= 0; i--)
        if (waiters[i].pred(m)) { waiters[i].res(m); waiters.splice(i, 1); }
    });
    ws.on('error', reject);
    const api = { ws, events, send: (o) => ws.send(JSON.stringify(o)),
      wait: (pred, ms=5000) => new Promise((res, rej) => {
        const hit = events.find(pred); if (hit) return res(hit);
        const t = setTimeout(() => rej(new Error('timeout')), ms);
        waiters.push({ pred, res: (m) => { clearTimeout(t); res(m); } });
      }), close: () => ws.close() };
    ws.on('open', () => {
      api.send({ t: 'hello', uid, name, gender: 'Other', meet: 'Everyone' });
      api.wait((m) => m.t === 'welcome').then(() => resolve(api));
    });
  });
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// duo room via party (2 members, start)
const a = await connect('dA_b62', 'duoA');
const b = await connect('dB_b62', 'duoB');
a.send({ t: 'host' });
const party = await a.wait((m) => m.t === 'party');
b.send({ t: 'joinParty', code: party.code });
await a.wait((m) => m.t === 'party' && (m.members ?? []).length === 2);
a.send({ t: 'startParty' });
await a.wait((m) => m.t === 'cell');
await b.wait((m) => m.t === 'cell');

// roll unnamed games repeatedly — every round must be duo-safe
const seen = new Set();
for (let i = 0; i < 14; i++) {
  a.send({ t: 'pickGame' });
  const r = await a.wait((m) => m.t === 'round' && !seen.has(m.name + i), 6000).catch(() => null);
  const last = a.events.filter((m) => m.t === 'round').at(-1);
  if (last) seen.add(last.name);
  await sleep(250);
  a.send({ t: 'leave' }); // end round fast? no — leave kills cell. Skip.
  break;
}
// simpler: pickGame chains beats; watch rounds arriving over time
a.send({ t: 'pickGame', name: 'Roast Circle' }); // group-only → must fall back
const r1 = await a.wait((m) => m.t === 'round', 6000);
ok('group-only pick in duo falls back to duo-safe', DUO_SAFE.has(r1.game?.name), r1.game?.name);
const names = new Set([r1.game?.name]);
for (let i = 0; i < 6; i++) {
  await sleep(400);
  a.send({ t: 'pickGame' });
  await sleep(600);
}
for (const m of a.events) if (m.t === 'round' && m.game?.name) names.add(m.game.name);
ok('all duo rounds are duo-safe', [...names].every((n) => DUO_SAFE.has(n)), [...names].join(','));
a.close(); b.close();

// group room: 4 members → group-only game starts by name
const g = [];
for (let i = 0; i < 4; i++) g.push(await connect(`g${i}_b62`, `grp${i}`));
g[0].send({ t: 'host' });
const gp = await g[0].wait((m) => m.t === 'party');
for (let i = 1; i < 4; i++) {
  g[i].send({ t: 'joinParty', code: gp.code });
  await sleep(150);
}
g[0].send({ t: 'startParty' });
await g[0].wait((m) => m.t === 'cell');
await sleep(300);
g[0].send({ t: 'pickGame', name: 'Roast Circle' });
const gr = await g[0].wait((m) => m.t === 'round', 6000);
ok('group room starts Roast Circle by name', gr.game?.name === 'Roast Circle', gr.game?.name);
for (const x of g) x.close();

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
