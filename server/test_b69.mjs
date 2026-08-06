// Build 69 — your age is one number everywhere.
//
// hello carries the age the app derived from your date of birth, but
// upsertUser dropped it: the column was written ONLY by Edit Profile. So your
// own profile showed the real age while every Explore card showed whatever
// stale number the database still held.
// Run from server/: node test_b69.mjs   (server on :8091, local Postgres)
import WebSocket from 'ws';
import pg from 'pg';

const WS = 'ws://127.0.0.1:8091/ws';
const DB = process.env.DATABASE_URL || 'postgres://rivlr@127.0.0.1:54329/rivlr';
let pass = 0, fail = 0;
const ok = (n, c, x = '') => c
  ? (pass++, console.log(`  ✓ ${n}`))
  : (fail++, console.log(`  ✗ ${n} ${x}`));

function connect(uid, name, extra = {}) {
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
      api.send({ t: 'hello', uid, name, gender: 'Other', meet: 'Everyone',
        discoverable: true, ...extra });
      api.wait((m) => m.t === 'welcome').then((w) => resolve({ ...api, welcome: w }));
    });
  });
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const run = async () => {
  const pool = new pg.Pool({ connectionString: DB });
  const ageOf = async (uid) => {
    const r = await pool.query('SELECT age FROM users WHERE uid=$1', [uid]);
    return r.rows[0]?.age ?? null;
  };
  const S = Date.now();
  const meUid = `t69me${S}`, peerUid = `t69peer${S}`;

  console.log('\n— hello carries your age all the way to the database —');
  const me = await connect(meUid, 'agey', { age: 35 });
  await sleep(700);
  ok('age from hello is stored', Number(await ageOf(meUid)) === 35,
    String(await ageOf(meUid)));

  console.log('\n— and that is the number other people see on your card —');
  const peer = await connect(peerUid, 'peery');
  peer.send({ t: 'explore' });
  const grid = await peer.wait((m) => m.t === 'explore');
  const card = (grid.people ?? []).find((p) => p.uid === meUid);
  ok('your card is in the grid', !!card);
  ok('the card shows the same age your profile does', card && card.age === 35,
    card ? String(card.age) : 'no card');

  console.log('\n— a birthday changes it everywhere at once —');
  me.close();
  await sleep(400);
  const me2 = await connect(meUid, 'agey', { age: 36 });
  await sleep(700);
  ok('the stored age follows', Number(await ageOf(meUid)) === 36,
    String(await ageOf(meUid)));

  console.log('\n— a client that sends nothing cannot wipe it —');
  me2.close();
  await sleep(400);
  const me3 = await connect(meUid, 'agey'); // no age at all
  await sleep(700);
  ok('a missing age leaves the good one alone', Number(await ageOf(meUid)) === 36,
    String(await ageOf(meUid)));

  console.log('\n— and nonsense is refused —');
  me3.close();
  await sleep(400);
  const me4 = await connect(meUid, 'agey', { age: 4 });
  await sleep(700);
  ok('an under-18 age is not written', Number(await ageOf(meUid)) === 36,
    String(await ageOf(meUid)));
  me4.close();
  await sleep(400);
  const me5 = await connect(meUid, 'agey', { age: 'lol' });
  await sleep(700);
  ok('a non-number is not written', Number(await ageOf(meUid)) === 36,
    String(await ageOf(meUid)));

  for (const c of [me5, peer]) c.close();
  await pool.end();
  await sleep(200);
  console.log(`\n${pass} passed, ${fail} failed\n`);
  process.exit(fail ? 1 : 0);
};

run().catch((e) => { console.error('HARNESS ERROR', e); process.exit(1); });
