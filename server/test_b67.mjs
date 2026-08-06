// Build 67 — the cold-start room code.
//
// A brand-new account that presses Groups in its first moments used to race
// its own hello: the users row wasn't written yet, so the permanent 5-char
// code couldn't be minted and the server handed out a throwaway 4-char one.
// That code belongs to nobody, so a friend typing it got "that code doesn't
// exist", and the host's "permanent" code changed on the next reconnect.
// Run from server/: node test_b67.mjs   (server on :8091, local Postgres)
import WebSocket from 'ws';

const WS = 'ws://127.0.0.1:8091/ws';
let pass = 0, fail = 0;
const ok = (n, c, x = '') => c
  ? (pass++, console.log(`  ✓ ${n}`))
  : (fail++, console.log(`  ✗ ${n} ${x}`));

function connect(uid, name, { hostImmediately = false } = {}) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(WS);
    const events = [];
    const waiters = [];
    ws.on('message', (d) => {
      const m = JSON.parse(d.toString());
      events.push(m);
      for (let i = waiters.length - 1; i >= 0; i--) {
        if (waiters[i].pred(m)) { waiters[i].res(m); waiters.splice(i, 1); }
      }
    });
    ws.on('error', reject);
    const api = {
      ws, events,
      send: (o) => ws.send(JSON.stringify(o)),
      wait: (pred, ms = 6000) => new Promise((res, rej) => {
        const hit = events.find(pred);
        if (hit) return res(hit);
        const t = setTimeout(() => rej(new Error('timeout')), ms);
        waiters.push({ pred, res: (m) => { clearTimeout(t); res(m); } });
      }),
      close: () => ws.close(),
    };
    ws.on('open', () => {
      api.send({ t: 'hello', uid, name, gender: 'Other', meet: 'Everyone' });
      // the whole point: no breath between arriving and opening a room
      if (hostImmediately) api.send({ t: 'host' });
      api.wait((m) => m.t === 'welcome').then((w) => resolve({ ...api, welcome: w }));
    });
  });
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const run = async () => {
  const S = Date.now();
  const uid = `t67cold${S}`;

  console.log('\n— a brand-new account opens a room instantly —');
  const a = await connect(uid, 'coldy', { hostImmediately: true });
  const p1 = await a.wait((m) => m.t === 'party');
  ok('the code is the permanent 5-char kind, not a throwaway',
    typeof p1.code === 'string' && p1.code.length === 5, p1.code);

  console.log('\n— and a friend can actually find it —');
  const friendUid = `t67pal${S}`;
  const b = await connect(friendUid, 'pally');
  b.send({ t: 'joinParty', code: p1.code });
  const joined = await b.wait((m) => m.t === 'party' || m.t === 'partyError');
  ok('typing that code joins the room, not "code doesn’t exist"',
    joined.t === 'party' && (joined.members ?? []).length === 2,
    JSON.stringify(joined).slice(0, 120));

  console.log('\n— and it survives a reconnect —');
  a.close();
  await sleep(600);
  const a2 = await connect(uid, 'coldy', { hostImmediately: true });
  const p2 = await a2.wait((m) => m.t === 'party');
  ok('same code after reconnect', p2.code === p1.code, `${p2.code} vs ${p1.code}`);

  console.log('\n— a code nobody owns is still reported honestly —');
  b.send({ t: 'joinParty', code: 'ZZZZZ' });
  const err = await b.wait((m) => m.t === 'partyError');
  ok('unknown code says so', typeof err.reason === 'string' && err.reason.length > 0,
    err.reason);

  for (const c of [a2, b]) c.close();
  await sleep(200);
  console.log(`\n${pass} passed, ${fail} failed\n`);
  process.exit(fail ? 1 : 0);
};

run().catch((e) => { console.error('HARNESS ERROR', e); process.exit(1); });
