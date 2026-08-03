// Build 61 pipeline harness — codes, media claims, thumbs, search, explore,
// offline requests. Run from server/: node test_b61.mjs
import WebSocket from 'ws';

const WS = 'ws://127.0.0.1:8091/ws';
const HTTP = 'http://127.0.0.1:8091';
let pass = 0, fail = 0;
const ok = (name, cond, extra = '') => {
  if (cond) { pass++; console.log(`  ✓ ${name}`); }
  else { fail++; console.log(`  ✗ ${name} ${extra}`); }
};

function connect(uid, name) {
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
      wait: (pred, ms = 4000) => new Promise((res, rej) => {
        const hit = events.find(pred);
        if (hit) return res(hit);
        const t = setTimeout(() => rej(new Error('timeout waiting')), ms);
        waiters.push({ pred, res: (m) => { clearTimeout(t); res(m); } });
      }),
      close: () => ws.close(),
    };
    ws.on('open', () => {
      api.send({ t: 'hello', uid, name, gender: 'Other', meet: 'Everyone' });
      api.wait((m) => m.t === 'welcome').then((w) => resolve({ ...api, welcome: w }));
    });
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---- 1. permanent room codes ----
console.log('1. permanent room codes');
{
  let a = await connect('uidA_b61', 'alpha61');
  a.send({ t: 'host' });
  const p1 = await a.wait((m) => m.t === 'party');
  ok('code minted, 5 chars', typeof p1.code === 'string' && p1.code.length === 5, p1.code);
  const code = p1.code;
  a.close(); await sleep(300);
  a = await connect('uidA_b61', 'alpha61');
  a.send({ t: 'host' });
  const p2 = await a.wait((m) => m.t === 'party');
  ok('same code after reconnect', p2.code === code, `${p2.code} vs ${code}`);

  // guest joins
  const b = await connect('uidB_b61', 'bravo61');
  b.send({ t: 'joinParty', code });
  const pj = await b.wait((m) => m.t === 'party' && (m.members ?? []).length === 2);
  ok('guest joined, 2 members with uids', pj.members.every((x) => x.uid), JSON.stringify(pj.members));

  // guest tries a code whose host is away
  a.close(); await sleep(300);
  b.send({ t: 'joinParty', code: 'ZZZZZ' });
  const err1 = await b.wait((m) => m.t === 'partyError');
  ok('unknown code says doesn’t exist', /doesn’t exist/.test(err1.reason), err1.reason);
  b.close();
}

// ---- restart the server? covered logically by DB persistence: verify code is in DB
import pg from 'pg';
const db = new pg.Client({ connectionString: 'postgres://rivlr:rivlr@127.0.0.1:54329/rivlr' });
await db.connect();
{
  const r = await db.query("SELECT room_code FROM users WHERE uid='uidA_b61'");
  ok('code persisted in users.room_code', r.rows[0]?.room_code?.length === 5, JSON.stringify(r.rows));
  // away-host message
  const c = await connect('uidC_b61', 'charlie61');
  c.send({ t: 'joinParty', code: r.rows[0].room_code });
  const err = await c.wait((m) => m.t === 'partyError');
  ok('away host says room isn’t open', /isn’t open/.test(err.reason), err.reason);
  c.close();
}

// ---- 2. media: upload, claim, idempotent resend, thumb kind ----
console.log('2. media pipeline');
{
  const a = await connect('uidA_b61', 'alpha61');
  const b = await connect('uidB_b61', 'bravo61');
  const tokA = a.welcome.http.token;
  // make them friends so dm works
  a.send({ t: 'friendRequest', target: 'uidB_b61' });
  await sleep(200);
  b.send({ t: 'friendAccept', target: 'uidA_b61' });
  await sleep(300);

  const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(500, 7)]);
  const up = await fetch(`${HTTP}/api/media?kind=photo`, {
    method: 'POST', headers: { 'content-type': 'image/jpeg', authorization: `Bearer ${tokA}` },
    body: jpeg });
  const upj = await up.json();
  ok('photo upload 200 with id', up.status === 200 && upj.id > 0, JSON.stringify(upj));

  a.send({ t: 'dm', to: 'uidB_b61', kind: 'photo', mediaId: upj.id, tmp: 'x1' });
  const dmB = await b.wait((m) => m.t === 'dm' && m.msg?.kind === 'photo');
  ok('recipient got the photo dm', dmB.msg.mediaId === upj.id);
  // duplicate resend (reconnect retry) must not err
  a.send({ t: 'dm', to: 'uidB_b61', kind: 'photo', mediaId: upj.id, tmp: 'x2' });
  await sleep(400);
  const gotErr = a.events.some((m) => m.t === 'err' && m.code === 'badMedia');
  ok('idempotent resend: no badMedia', !gotErr);

  // recipient can GET it
  const tokB = b.welcome.http.token;
  const get = await fetch(`${HTTP}/api/media/${upj.id}?tk=${encodeURIComponent(tokB)}`);
  ok('recipient GET 200 image/jpeg', get.status === 200 && get.headers.get('content-type').includes('image/jpeg'), String(get.status));

  // voice: audio/mp4 accepted, served as audio/mp4
  const voice = Buffer.alloc(400, 3);
  const vu = await fetch(`${HTTP}/api/media?kind=voice`, {
    method: 'POST', headers: { 'content-type': 'audio/mp4', authorization: `Bearer ${tokA}` },
    body: voice });
  const vuj = await vu.json();
  ok('voice upload 200', vu.status === 200 && vuj.id > 0, JSON.stringify(vuj));
  a.send({ t: 'dm', to: 'uidB_b61', kind: 'voice', mediaId: vuj.id, tmp: 'v1', meta: { durMs: 1200 } });
  await b.wait((m) => m.t === 'dm' && m.msg?.kind === 'voice');
  const vg = await fetch(`${HTTP}/api/media/${vuj.id}?tk=${encodeURIComponent(tokB)}`);
  ok('voice served as audio/mp4', vg.headers.get('content-type').includes('audio/mp4'), vg.headers.get('content-type'));

  // avatar + thumb: full photo must SURVIVE the thumb upload
  const av = await fetch(`${HTTP}/api/media?kind=avatar`, {
    method: 'POST', headers: { 'content-type': 'image/jpeg', authorization: `Bearer ${tokA}` },
    body: jpeg });
  const avj = await av.json();
  const th = await fetch(`${HTTP}/api/media?kind=thumb`, {
    method: 'POST', headers: { 'content-type': 'image/jpeg', authorization: `Bearer ${tokA}` },
    body: jpeg.subarray(0, 300) });
  const thj = await th.json();
  const row = await db.query("SELECT photo_media_id, photo_thumb_id FROM users WHERE uid='uidA_b61'");
  ok('photo_media_id still = full avatar', Number(row.rows[0].photo_media_id) === avj.id,
      JSON.stringify(row.rows[0]) + ' vs ' + avj.id);
  ok('photo_thumb_id = thumb', Number(row.rows[0].photo_thumb_id) === thj.id);
  const fullAlive = await db.query('SELECT id FROM media WHERE id=$1', [avj.id]);
  ok('full avatar blob NOT deleted', fullAlive.rows.length === 1);
  // welcome carries the ids
  a.close(); await sleep(200);
  const a2 = await connect('uidA_b61', 'alpha61');
  ok('welcome.photo has healed ids',
      a2.welcome.photo?.id === avj.id && a2.welcome.photo?.thumbId === thj.id,
      JSON.stringify(a2.welcome.photo));
  a2.close(); b.close();
}

// ---- 3. offline friend request + hydrate-on-hello ----
console.log('3. friend pipeline');
{
  const a = await connect('uidA_b61', 'alpha61');
  a.send({ t: 'friendRequest', target: 'uidD_b61' }); // D has never connected... create D first
  await sleep(200);
  a.close();
  // D connects fresh — the snapshot on hello must carry the pending request
  const d = await connect('uidD_b61', 'delta61');
  const snap = await d.wait((m) => m.t === 'friends', 5000);
  ok('hello hydrates friends snapshot', Array.isArray(snap.friends));
  ok('offline request visible on connect',
      (snap.reqsIn ?? []).some((r) => r.uid === 'uidA_b61'), JSON.stringify(snap.reqsIn));
  d.close();
}

// ---- 4. search ----
console.log('4. search');
{
  const a = await connect('uidA_b61', 'alpha61');
  a.send({ t: 'searchUsers', q: '@brav' });
  const res = await a.wait((m) => m.t === 'searchResults');
  ok('prefix search finds bravo61', (res.people ?? []).some((p) => p.uid === 'uidB_b61'),
      JSON.stringify(res.people));
  a.send({ t: 'searchUsers', q: 'zzzznope' });
  const none = await a.wait((m) => m.t === 'searchResults' && m.q === 'zzzznope');
  ok('no-match returns empty', (none.people ?? []).length === 0);
  a.close();
}

// ---- 5. explore shows away people ----
console.log('5. explore');
{
  const a = await connect('uidA_b61', 'alpha61');
  // B and D are offline now; both discoverable
  a.send({ t: 'explore' });
  const ex = await a.wait((m) => m.t === 'explore');
  const b = (ex.people ?? []).find((p) => p.uid === 'uidB_b61');
  ok('away user appears', !!b, JSON.stringify(ex.people?.map((p) => p.uid)));
  ok('away user marked online:false', b && b.online === false, JSON.stringify(b));
  ok('self absent', !(ex.people ?? []).some((p) => p.uid === 'uidA_b61'));
  // hide via discoverable=false
  await db.query("UPDATE users SET discoverable=false WHERE uid='uidB_b61'");
  a.send({ t: 'explore' });
  await sleep(500);
  const ex2 = a.events.filter((m) => m.t === 'explore').at(-1);
  ok('non-discoverable hidden', !(ex2.people ?? []).some((p) => p.uid === 'uidB_b61'));
  await db.query("UPDATE users SET discoverable=true WHERE uid='uidB_b61'");
  a.close();
}

await db.end();
console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
