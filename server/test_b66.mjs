// Build 66 — one way to link up: the party ring.
// A host pulls a friend straight into the room they're holding; the friend's
// screen lights up with one Join. Offline friends fall back to a DM'd code so
// an invite is never silently lost.
// Run from server/: node test_b66.mjs   (server on :8091, local Postgres)
import WebSocket from 'ws';

const WS = 'ws://127.0.0.1:8091/ws';
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

/// Accepting before the request has actually committed is a silent no-op, so
/// wait for the request to LAND on the other side rather than guessing a delay.
async function befriend(a, b, aUid, bUid) {
  a.send({ t: 'friendRequest', target: bUid });
  await b.wait((m) => m.t === 'friends' &&
    (m.reqsIn ?? []).some((f) => f.uid === aUid));
  b.send({ t: 'friendAccept', target: aUid });
  await a.wait((m) => m.t === 'friends' &&
    (m.friends ?? []).some((f) => f.uid === bUid));
}

const run = async () => {
  const S = Date.now();
  const hostUid = `t66host${S}`, palUid = `t66pal${S}`, strangerUid = `t66str${S}`;

  console.log('\n— live ring —');
  const host = await connect(hostUid, 'hostie');
  const pal = await connect(palUid, 'pally');
  await befriend(host, pal, hostUid, palUid);

  host.send({ t: 'host' });
  const party = await host.wait((m) => m.t === 'party');
  const code = party.code;
  ok('host holds a room with a code', typeof code === 'string' && code.length >= 4, code);

  host.send({ t: 'partyRing', to: palUid });
  const ring = await pal.wait((m) => m.t === 'partyRing');
  ok('friend gets a live knock', ring.code === code, JSON.stringify(ring));
  ok('the knock names who is asking', ring.from?.uid === hostUid, JSON.stringify(ring.from));
  const sent = await host.wait((m) => m.t === 'partyRingSent');
  ok('host is told the ring landed live', sent.live === true && sent.uid === palUid);

  console.log('\n— the knock actually joins —');
  pal.send({ t: 'joinParty', code });
  const joined = await pal.wait((m) => m.t === 'party' &&
    (m.members ?? []).length === 2);
  ok('one Join puts them in the room', joined.code === code &&
    joined.members.some((x) => x.uid === palUid));

  console.log('\n— offline friend falls back —');
  const ghostUid = `t66ghost${S}`;
  const ghost = await connect(ghostUid, 'ghosty');
  await befriend(host, ghost, hostUid, ghostUid);
  ghost.close();
  await sleep(400);
  host.send({ t: 'partyRing', to: ghostUid });
  const off = await host.wait((m) => m.t === 'partyRingSent' && m.uid === ghostUid);
  ok('offline friend reports live:false so the client DMs the code',
    off.live === false);

  console.log('\n— the rules —');
  const stranger = await connect(strangerUid, 'strangey');
  host.send({ t: 'partyRing', to: strangerUid });
  const err = await host.wait((m) => m.t === 'err' && m.code === 'notFriends');
  ok('you cannot pull in someone who is not a friend', err.code === 'notFriends');
  let leaked = false;
  try {
    await stranger.wait((m) => m.t === 'partyRing', 900);
    leaked = true;
  } catch (_) {/* expected */}
  ok('...and no knock reaches them', !leaked);

  // a guest is not the host and must not be able to ring on the host's behalf
  pal.send({ t: 'partyRing', to: strangerUid });
  let guestRang = false;
  try {
    await stranger.wait((m) => m.t === 'partyRing', 900);
    guestRang = true;
  } catch (_) {/* expected */}
  ok('a guest cannot ring people into someone else’s room', !guestRang);

  host.send({ t: 'partyRing', to: hostUid });
  let selfRang = false;
  try {
    await host.wait((m) => m.t === 'partyRing', 900);
    selfRang = true;
  } catch (_) {/* expected */}
  ok('you cannot ring yourself', !selfRang);

  console.log('\n— blocked people stay unreachable —');
  const blockUid = `t66blk${S}`;
  const blocked = await connect(blockUid, 'blocky');
  await befriend(host, blocked, hostUid, blockUid);
  blocked.send({ t: 'block', target: hostUid });
  await sleep(400);
  host.send({ t: 'partyRing', to: blockUid });
  let blockedRang = false;
  try {
    await blocked.wait((m) => m.t === 'partyRing', 900);
    blockedRang = true;
  } catch (_) {/* expected */}
  ok('someone who blocked you cannot be pulled in', !blockedRang);

  for (const c of [host, pal, stranger, blocked]) c.close();
  await sleep(200);
  console.log(`\n${pass} passed, ${fail} failed\n`);
  process.exit(fail ? 1 : 0);
};

run().catch((e) => { console.error('HARNESS ERROR', e); process.exit(1); });
