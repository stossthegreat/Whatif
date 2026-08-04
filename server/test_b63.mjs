// Build 63 — Rivlr+ backbone: entitlement gating, webhook security and
// idempotency, the paid gender filter, and who-wants-to-meet-you.
// Run from server/: node test_b63.mjs   (server on :8091, local Postgres)
import WebSocket from 'ws';
import pg from 'pg';

const WS = 'ws://127.0.0.1:8091/ws';
const HTTP = 'http://127.0.0.1:8091';
const HOOK_AUTH = 'test_hook_secret_b63';
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
      wait: (pred, ms = 5000) => new Promise((res, rej) => {
        const hit = events.find(pred);
        if (hit) return res(hit);
        const t = setTimeout(() => rej(new Error('timeout')), ms);
        waiters.push({ pred, res: (m) => { clearTimeout(t); res(m); } });
      }),
      close: () => ws.close(),
    };
    ws.on('open', () => {
      api.send({ t: 'hello', uid, name, gender: 'Other', meet: 'Everyone', ...extra });
      api.wait((m) => m.t === 'welcome').then((w) => resolve({ ...api, welcome: w }));
    });
  });
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const hook = (body, auth = HOOK_AUTH) => fetch(`${HTTP}/api/rc/webhook`, {
  method: 'POST',
  headers: { 'content-type': 'application/json', authorization: auth },
  body: JSON.stringify(body),
});

const db = new pg.Client({ connectionString: 'postgres://rivlr:rivlr@127.0.0.1:54329/rivlr' });
await db.connect();
await db.query("DELETE FROM purchases WHERE uid LIKE '%_b63'");
await db.query("UPDATE users SET plus_until=NULL, meet='Everyone' WHERE uid LIKE '%_b63'");

const future = Date.now() + 7 * 24 * 3600_000;

// ---- 1. entitlement gating -------------------------------------------------
console.log('1. entitlement gating');
{
  const a = await connect('pA_b63', 'plusA', { gender: 'Man' });
  ok('free account: welcome says plus inactive', a.welcome.plus?.active === false,
      JSON.stringify(a.welcome.plus));

  a.send({ t: 'meetPref', meet: 'Women' });
  const err = await a.wait((m) => m.t === 'err' && m.code === 'needPlus');
  ok('free account cannot set a filter', err.code === 'needPlus');

  const row = await db.query("SELECT meet FROM users WHERE uid='pA_b63'");
  ok('rejected filter was NOT written to the db', row.rows[0]?.meet !== 'Women',
      JSON.stringify(row.rows[0]));
  a.close();
}

// ---- 2. webhook security + idempotency ------------------------------------
console.log('2. webhook security');
{
  const bad = await hook({ event: { id: 'evt_bad_b63', app_user_id: 'pA_b63' } }, 'wrong');
  ok('wrong auth rejected 401', bad.status === 401, String(bad.status));

  const none = await hook({ event: { id: 'evt_bad2_b63', app_user_id: 'pA_b63' } }, '');
  ok('missing auth rejected 401', none.status === 401, String(none.status));

  const anon = await hook({ event: { id: 'evt_anon_b63', app_user_id: '$RCAnonymousID:xyz' } });
  const anonJson = await anon.json();
  ok('anonymous subscriber skipped', anon.status === 200 && anonJson.skipped === true,
      JSON.stringify(anonJson));

  const good = await hook({ event: {
    id: 'evt_buy_b63', type: 'INITIAL_PURCHASE', app_user_id: 'pA_b63',
    product_id: 'rivlr_plus_weekly', expiration_at_ms: future } });
  ok('valid webhook accepted', good.status === 200, String(good.status));
  await sleep(400);

  const row = await db.query("SELECT plus_until FROM users WHERE uid='pA_b63'");
  ok('entitlement written to users.plus_until', row.rows[0]?.plus_until != null,
      JSON.stringify(row.rows[0]));

  const dupe = await hook({ event: {
    id: 'evt_buy_b63', type: 'INITIAL_PURCHASE', app_user_id: 'pA_b63',
    product_id: 'rivlr_plus_weekly', expiration_at_ms: future } });
  const dj = await dupe.json();
  ok('replayed event is a no-op', dj.duplicate === true, JSON.stringify(dj));

  const cnt = await db.query("SELECT count(*) c FROM purchases WHERE event_id='evt_buy_b63'");
  ok('purchase recorded exactly once', Number(cnt.rows[0].c) === 1, JSON.stringify(cnt.rows[0]));
}

// ---- 3. paid filter now works, and survives reconnect ---------------------
console.log('3. the paid filter');
{
  const a = await connect('pA_b63', 'plusA', { gender: 'Man' });
  ok('welcome now reports plus active', a.welcome.plus?.active === true,
      JSON.stringify(a.welcome.plus));

  a.send({ t: 'meetPref', meet: 'Women' });
  const set = await a.wait((m) => m.t === 'meetPref');
  ok('plus account can set the filter', set.meet === 'Women', JSON.stringify(set));
  ok('server reports honest reach', typeof set.reach === 'number', JSON.stringify(set));
  await sleep(300);

  a.close(); await sleep(300);
  // reinstall: client forgets everything and says Everyone — the DB must win
  const again = await connect('pA_b63', 'plusA', { gender: 'Man', meet: 'Everyone' });
  ok('paid filter survives a reinstall', again.welcome.plus?.meet === 'Women',
      JSON.stringify(again.welcome.plus));
  again.close();
}

// ---- 4. the filter actually filters (symmetric) ---------------------------
console.log('4. filter enforcement in the queue');
{
  const man = await connect('pA_b63', 'plusA', { gender: 'Man' });   // wants Women
  const otherMan = await connect('mB_b63', 'manB', { gender: 'Man' });
  man.send({ t: 'play', mode: 'hang' });
  otherMan.send({ t: 'play', mode: 'hang' });
  await sleep(1500);
  const matched = man.events.some((m) => m.t === 'cell') || otherMan.events.some((m) => m.t === 'cell');
  ok('filtered user is NOT matched with the wrong gender', !matched);

  const hint = man.events.filter((m) => m.t === 'queueHint').at(-1);
  ok('waiting user gets an honest reach hint', !!hint && hint.meet === 'Women',
      JSON.stringify(hint));

  // clear the other man out first, so the woman has exactly one possible
  // partner — otherwise she could legitimately match him and the assert
  // below would be testing the scheduler's coin flip, not the filter
  otherMan.close();
  await sleep(400);

  const woman = await connect('wC_b63', 'womanC', { gender: 'Woman' });
  woman.send({ t: 'play', mode: 'hang' });
  const cell = await man.wait((m) => m.t === 'cell', 8000).catch(() => null);
  ok('filtered user matches the right gender', !!cell);
  man.close(); woman.close();
  await sleep(300);
}

// ---- 4b. "meet anyone this once" never edits the saved filter -------------
console.log('4b. one-room widen');
{
  const man = await connect('pA_b63', 'plusA', { gender: 'Man' }); // filter: Women
  ok('filter still Women before widening', man.welcome.plus?.meet === 'Women',
      JSON.stringify(man.welcome.plus));

  man.send({ t: 'play', mode: 'hang' });
  await sleep(300);
  man.send({ t: 'widenOnce' });
  const relaxed = await man.wait((m) => m.t === 'meetPref' && m.relaxed === true);
  ok('widen acknowledged', relaxed.relaxed === true);
  ok('saved filter unchanged in the reply', relaxed.meet === 'Women', JSON.stringify(relaxed));

  const dbRow = await db.query("SELECT meet FROM users WHERE uid='pA_b63'");
  ok('saved filter unchanged in the database', dbRow.rows[0]?.meet === 'Women',
      JSON.stringify(dbRow.rows[0]));

  // now a man CAN match him, because he widened for this one room
  const otherMan = await connect('mB_b63', 'manB', { gender: 'Man' });
  otherMan.send({ t: 'play', mode: 'hang' });
  const cell = await man.wait((m) => m.t === 'cell', 8000).catch(() => null);
  ok('widened user matches outside the filter', !!cell);

  man.close(); otherMan.close();
  await sleep(400);

  // and the NEXT search is filtered again
  const back = await connect('pA_b63', 'plusA', { gender: 'Man' });
  ok('filter is back on the next session', back.welcome.plus?.meet === 'Women',
      JSON.stringify(back.welcome.plus));
  back.close();
  await sleep(200);
}

// ---- 5. expiry revokes -----------------------------------------------------
console.log('5. expiry');
{
  await db.query("UPDATE users SET plus_until = now() - interval '1 day' WHERE uid='pA_b63'");
  const a = await connect('pA_b63', 'plusA', { gender: 'Man' });
  ok('expired subscription is not active', a.welcome.plus?.active === false,
      JSON.stringify(a.welcome.plus));
  ok('expired subscription drops the filter', a.welcome.plus?.meet === 'Everyone',
      JSON.stringify(a.welcome.plus));
  a.send({ t: 'meetPref', meet: 'Men' });
  const err = await a.wait((m) => m.t === 'err' && m.code === 'needPlus');
  ok('expired account cannot re-filter', err.code === 'needPlus');
  a.close();
  // restore for the next section
  await hook({ event: { id: 'evt_renew_b63', type: 'RENEWAL', app_user_id: 'pA_b63',
    product_id: 'rivlr_plus_weekly', expiration_at_ms: future } });
  await sleep(400);
}

// ---- 6. who wants to meet you ---------------------------------------------
console.log('6. who wants to meet you');
{
  // seed: two people rated pA Friend+, one of whom pA already rated back,
  // plus one rating that's too old to count
  await db.query("DELETE FROM ratings WHERE target='pA_b63' OR rater='pA_b63'");
  await db.query(`INSERT INTO users (uid, name) VALUES
      ('likeA_b63','likerA'), ('likeB_b63','likerB'), ('oldC_b63','oldC')
      ON CONFLICT (uid) DO NOTHING`);
  await db.query(`INSERT INTO ratings (rater, target, cell_id, score) VALUES
      ('likeA_b63','pA_b63','c1',2),
      ('likeB_b63','pA_b63','c2',3),
      ('oldC_b63','pA_b63','c3',2)`);
  await db.query("UPDATE ratings SET created_at = now() - interval '45 days' WHERE rater='oldC_b63'");
  // pA already rated likeB back → likeB must NOT appear
  await db.query("INSERT INTO ratings (rater, target, cell_id, score) VALUES ('pA_b63','likeB_b63','c2',2)");

  const a = await connect('pA_b63', 'plusA', { gender: 'Man' });
  a.send({ t: 'likesMe' });
  const list = await a.wait((m) => m.t === 'likesMe');
  const uids = (list.people ?? []).map((p) => p.uid);
  ok('plus sees the faces', list.locked === false, JSON.stringify(list.locked));
  ok('includes someone who liked me', uids.includes('likeA_b63'), uids.join(','));
  ok('excludes someone I already rated back', !uids.includes('likeB_b63'), uids.join(','));
  ok('excludes ratings older than 30 days', !uids.includes('oldC_b63'), uids.join(','));
  a.close();

  // free account: count only, no faces
  await db.query("DELETE FROM ratings WHERE target='fD_b63'");
  await db.query(`INSERT INTO users (uid, name) VALUES ('fD_b63','freeD') ON CONFLICT (uid) DO NOTHING`);
  await db.query("INSERT INTO ratings (rater, target, cell_id, score) VALUES ('likeA_b63','fD_b63','c9',2)");
  const f = await connect('fD_b63', 'freeD', { gender: 'Man' });
  f.send({ t: 'likesMe' });
  const locked = await f.wait((m) => m.t === 'likesMe');
  ok('free account gets the count', locked.count === 1, JSON.stringify(locked));
  ok('free account gets NO faces', (locked.people ?? []).length === 0, JSON.stringify(locked.people));
  f.close();
}

// ---- 7. sync endpoint auth -------------------------------------------------
console.log('7. sync endpoint');
{
  const noAuth = await fetch(`${HTTP}/api/iap/sync`, { method: 'POST' });
  ok('sync requires a token', noAuth.status === 401, String(noAuth.status));
}

await db.end();
console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
