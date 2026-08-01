# Rivlr Server

Matchmaking + live-video signaling for Rivlr. One PLAY → the server composes an
unpredictable **cell** (group size + game), mints a **LiveKit** room token per
member (the live group video), and relays game events between members.

- **Node + TypeScript + `ws`** (WebSocket). Runs on Railway with zero config.
- **LiveKit** does the actual media (an SFU built for live group video). The
  server only mints room tokens — it never touches video.
- **Fail-soft:** no LiveKit keys → matching still works, video disabled. `ALLOW_SOLO`
  drops a lone tester into a solo cell so you can demo with one device.

## Deploy to Railway

1. Push this repo to GitHub (already done).
2. In Railway: **New Project → Deploy from GitHub repo** → pick this repo.
3. Set the service **Root Directory** to `server`. Railway auto-detects Node
   (Nixpacks), runs `npm install`, then `npm start`.
4. **Variables** (from `.env.example`):
   - `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` — from a free
     [LiveKit Cloud](https://cloud.livekit.io) project (Settings → Keys).
   - `ALLOW_SOLO=true` while testing; `false` once you have real traffic.
   - `PORT` is provided by Railway automatically.
5. **Networking → Generate Domain.** Your WebSocket URL is
   `wss://<your-domain>/ws`. Health check: `https://<your-domain>/health`.

Local dev:
```bash
cd server
cp .env.example .env    # fill in LiveKit keys (optional)
npm install
npm run dev             # ws://localhost:8080/ws
```

## Protocol (JSON over WebSocket `/ws`)

**Server → client**
| msg | meaning |
|---|---|
| `{t:'welcome', id, name, hue, live}` | your assigned anonymous identity |
| `{t:'presence', live}` | people online (every 3s) |
| `{t:'searching'}` | you're in the queue |
| `{t:'cell', room, url, token, people:[{id,name,hue}], game:{kind,name,hint,prompt}}` | matched — join `url` with `token` for video |
| `{t:'peerLeft', id}` / `{t:'ended'}` | cell recomposed / dissolved |
| `{t:'answer'\|'react', from, v\|e}` | a peer's game event |

**Client → server**
`{t:'hello', name?}` · `{t:'play'}` · `{t:'next'}` · `{t:'leave'}` ·
`{t:'answer', v}` · `{t:'react', e}` · `{t:'report'|'block', target}`

## Wiring the Flutter app to this backend (the video flip)

The app runs fully simulated today. To go live, add two deps and point it at
your Railway URL:

```yaml
# pubspec.yaml
dependencies:
  web_socket_channel: ^3.0.1   # matchmaking (pure Dart)
  livekit_client: ^2.3.0       # live group video
```

1. **Config** — `lib/config.dart`:
   ```dart
   class AppConfig {
     // empty = simulated; set to your Railway wss URL to go live
     static const backend = String.fromEnvironment('RIVLR_BACKEND', defaultValue: '');
   }
   ```
   Run live with: `flutter run --dart-define=RIVLR_BACKEND=wss://<domain>/ws`

2. **Matchmaking** — connect on Finding, wait for `cell`, then build the `Cell`
   from `people` + `game.prompt` and go to Live. On NEXT send `{t:'next'}` and
   re-enter Finding; on LEAVE send `{t:'leave'}`.

3. **Video** — on `cell`, join LiveKit:
   ```dart
   final room = Room();
   await room.connect(msg['url'], msg['token']);
   await room.localParticipant?.setCameraEnabled(true);
   // render each remote participant's VideoTrack into the PresenceTile slot,
   // and the local track into the self PiP.
   ```
   Swap `PresenceTile`'s placeholder for a `VideoTrackRenderer(track)` when a
   remote track is available (keep the placeholder as the pre-video state).

That's the whole path to real, live, on-par-with-anyone video. The game engine,
reveal beats, reconnect and report already work against `people`/`game` — they
just start being driven by real strangers instead of the local simulator.
