<div align="center">

# 🎵 Resonate

### *Real-time, multi-device audio synchronization with sub-30ms drift*

**Resonate** is a distributed audio playback platform that keeps multiple devices playing the same track in lock-step — across any network — by combining a custom NTP-style clock synchronization protocol with latency-aware event scheduling and adaptive drift correction.

<br/>

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-20.x-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)
![Socket.IO](https://img.shields.io/badge/Socket.IO-4.x-010101?style=for-the-badge&logo=socketdotio&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)

</div>

---

## 📑 Table of Contents

- [🌟 Key Features](#-key-features)
- [🏗️ System Architecture](#️-system-architecture)
- [🧮 The Mathematics of Synchronization](#-the-mathematics-of-synchronization)
- [⚖️ Architectural Trade-offs & Engineering Decisions](#️-architectural-trade-offs--engineering-decisions)
- [🔐 Security & Robustness](#-security--robustness)
- [🚀 Future Enhancements](#-future-enhancements)
- [💻 Installation & Local Development](#-installation--local-development)
- [📁 Project Structure](#-project-structure)

---

## 🌟 Key Features

- **⚡ Near-Instant Socket Updates** — On a shared local network, playback commands (play, pause, seek) are acknowledged and executed within single-digit milliseconds of the host action.

- **🎯 Sub-30ms Distributed Drift** — A continuous, adaptive drift correction loop monitors each client's actual playback position against a mathematically computed expected position and silently corrects deviations — without ever interrupting the listening experience.

- **🌐 Proactive Network Jitter Compensation** — Rather than reacting to drift after it has accumulated, Resonate prevents it entirely. Every playback command carries a future execution timestamp computed from measured round-trip time, so all devices trigger audio start simultaneously regardless of individual network jitter.

- **🔄 Adaptive NTP-Style Clock Sync** — A custom ping/pong handshake protocol continuously measures and smooths the offset between each client's local clock and the server clock. The sync interval adapts dynamically: more frequent when variance is high, backing off to 30-second intervals when the offset is stable.

- **🎵 Collaborative Music Discovery** — Integrated iTunes Search API proxy for discovering and queuing tracks directly inside the session. Supports both URL-based loading and in-app search.

- **👥 Session Management** — Host-controlled sessions with automatic host migration when the host disconnects, participant tracking, and a collaborative queue.

- **🔐 Secure Authentication** — Firebase Authentication with automatic token refresh over the live WebSocket connection — the session stays valid for any duration without reconnecting.

- **🛡️ Production-Grade Hardening** — Per-event token-bucket rate limiting, safe async error boundaries on every socket event handler, input validation on both client and server, and automatic session cleanup via TTL.

---

## 🏗️ System Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLUTTER CLIENTS                          │
│                                                                 │
│  ┌───────────────────┐         ┌───────────────────────────┐   │
│  │     Host Device   │         │     Listener Devices      │   │
│  │                   │         │    (1 to N clients)       │   │
│  │  ┌─────────────┐  │         │  ┌─────────────────────┐  │   │
│  │  │ AudioPlayer │  │         │  │    AudioPlayer       │  │   │
│  │  │  (just_audio)│  │         │  │   (just_audio)       │  │   │
│  │  └──────┬──────┘  │         │  └─────────┬───────────┘  │   │
│  │         │          │         │            │               │   │
│  │  ┌──────▼──────┐  │         │  ┌─────────▼───────────┐  │   │
│  │  │DriftCorrector│  │         │  │   DriftCorrector     │  │   │
│  │  └──────┬──────┘  │         │  └─────────┬───────────┘  │   │
│  │         │          │         │            │               │   │
│  │  ┌──────▼──────┐  │         │  ┌─────────▼───────────┐  │   │
│  │  │TimeSyncService│  │         │  │  TimeSyncService    │  │   │
│  │  └──────┬──────┘  │         │  └─────────┬───────────┘  │   │
│  │         │          │         │            │               │   │
│  │  ┌──────▼──────┐  │         │  ┌─────────▼───────────┐  │   │
│  │  │SocketService│  │         │  │   SocketService      │  │   │
│  │  └──────┬──────┘  │         │  └─────────┬───────────┘  │   │
│  └─────────┼──────────┘         └────────────┼───────────────┘  │
└────────────┼────────────────────────────────┼──────────────────┘
             │  WebSocket (Socket.IO)          │
             │  wss://                         │
             ▼                                 ▼
┌────────────────────────────────────────────────────────────────┐
│                     NODE.JS SERVER                             │
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │socketHandler │  │sessionControl│  │   musicRouter      │  │
│  │(event router)│→ │ler (business │  │(iTunes proxy +     │  │
│  │              │  │   logic)     │  │  LRU cache)        │  │
│  └──────┬───────┘  └──────┬───────┘  └────────────────────┘  │
│         │                 │                                    │
│  ┌──────▼───────┐  ┌──────▼───────┐                          │
│  │ safeHandler  │  │sessionManager│                          │
│  │(async error  │  │(in-memory    │                          │
│  │  boundary)   │  │  session Map)│                          │
│  └──────────────┘  └──────────────┘                          │
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │ rateLimiter  │  │ socketAuth   │  │   timeUtils        │  │
│  │(token bucket │  │(Firebase JWT │  │(computeStartTime)  │  │
│  │ per event)   │  │ middleware)  │  │                    │  │
│  └──────────────┘  └──────────────┘  └────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

### Event Flow: Play Command

The following sequence illustrates how a single "Play" button press by the host propagates to all devices with synchronized execution:

```
Host Device                   Server                    Listener Device(s)
     │                           │                              │
     │  emit("play", {seq: N})   │                              │
     │──────────────────────────►│                              │
     │                           │  validate (host? stale seq?) │
     │                           │  computeStartTime()          │
     │                           │  = Date.now() + 1500ms       │
     │                           │                              │
     │                           │  emit("play_song", {         │
     │◄──────────────────────────│    startTime: T_future,      │
     │                           │    position: P               │
     │                           │  })──────────────────────────►
     │                           │                              │
     │  timeUntilPlay =          │          timeUntilPlay =     │
     │  T_future - serverNow()   │          T_future - serverNow()
     │                           │                              │
     │  await Future.delayed()   │          await Future.delayed()
     │  audio.play() ◄───────────┼──────────────── audio.play()│
     │         (simultaneous across all devices)                │
     │                           │                              │
```

The critical insight: `serverNow()` on each device is `Date.now() + smoothedOffset`, where `smoothedOffset` is derived from the NTP-style handshake. All devices therefore share a unified timeline despite having different hardware clocks.

---

## 🧮 The Mathematics of Synchronization

### 1. NTP-Style Clock Synchronization

Resonate implements a simplified version of Cristian's Algorithm to compute the clock offset between each client and the server.

**The Handshake:**

```
Client                        Server
  │                              │
  │  ping({id, t0})              │
  │─────────────────────────────►│  t1 = Date.now()
  │                              │  t2 = Date.now()
  │◄─────────────────────────────│  pong({id, t0, t1, t2})
  t3 = Date.now()               │
```

**Round-Trip Time (RTT):**

The network round-trip is computed by subtracting server processing time from the total elapsed time:

$$RTT = (t_3 - t_0) - (t_2 - t_1)$$

**Clock Offset:**

The offset assumes the one-way delay is symmetric (RTT/2 in each direction):

$$\theta = \frac{(t_1 - t_0) + (t_2 - t_3)}{2}$$

**Smoothed Offset (Exponential Moving Average):**

To prevent a single noisy ping from destabilizing playback, the offset is smoothed with a 90% weight on historical data:

$$\hat{\theta}_{n} = 0.1 \cdot median(\Theta_{buffer}) + 0.9 \cdot \hat{\theta}_{n-1}$$

**RTT Outlier Rejection:**

High-latency pings (network spike, background process) are discarded before updating the offset. A ping is accepted only if:

$$RTT \leq \max(50\text{ ms},\ P_{75}(RTT_{buffer}) \times 1.5)$$

**Server Time from Client:**

Once calibrated, any client can compute server time from its local clock:

$$T_{server} = T_{local} + \hat{\theta}$$

**Adaptive Sync Interval:**

The ping interval adapts to the variance of the offset buffer:

$$\text{interval} = \begin{cases} 30\text{ s} & \text{if } \sigma^2(\Theta) < 5 \\ 10\text{ s} & \text{if } \sigma^2(\Theta) < 20 \\ 2\text{ s} & \text{otherwise} \end{cases}$$

---

### 2. Latency-Aware Event Scheduling

Instead of commanding "play now" (which arrives at different real times on different devices due to network jitter), Resonate commands "play at time T":

**Future Start Time (server-side):**

$$T_{start} = T_{server\_now} + \Delta_{buffer}$$

where $\Delta_{buffer} = 1500\text{ ms}$ — the pre-play window that accounts for:
- Network propagation delay (50–300 ms typical)
- `just_audio` seek latency (50–200 ms)
- Audio buffer pre-fill (100–500 ms)

**Client Execution (Flutter):**

Each client independently computes how long to wait:

$$T_{wait} = T_{start} - T_{server\_now}^{(client)}$$
$$= T_{start} - (T_{local} + \hat{\theta})$$

If $T_{wait} > 0$: the client schedules `audio.play()` after that delay.

If $T_{wait} \leq 0$ (late delivery): the client corrects for the overrun before playing:

$$P_{corrected} = P_{base} + |T_{wait}|$$

**Post-Delay Drift Check:**

After the scheduled delay completes, a final drift check runs before `audio.play()`:

$$\delta_{post} = T_{server\_now}^{(client)} - T_{start}$$

If $|\delta_{post}| > 15\text{ ms}$, the seek position is corrected:

$$P_{adjusted} = P_{base} + \delta_{post}$$

This two-stage correction (schedule → verify → adjust) reduces the play-time error to the precision of a single timer tick on the device (~1–5 ms).

---

### 3. Adaptive Drift Correction

Even after synchronized playback starts, device clocks drift relative to each other due to oscillator variance and system load. The `DriftCorrector` runs a periodic monitoring loop every 3 seconds.

**Expected Position:**

Given the base position at start time and elapsed server time:

$$P_{expected}(t) = P_{base} + (T_{server\_now}(t) - T_{startedAt})$$

**Measured Drift:**

$$\Delta_{drift} = P_{expected}(t) - P_{actual}(t)$$

where $P_{actual}$ is read directly from `AudioPlayer.position`.

**Correction Strategy (three-tier):**

$$\text{action} = \begin{cases} \text{no-op} & \text{if } |\Delta_{drift}| \leq 20\text{ ms} \\ \text{speed ramp} & \text{if } 20\text{ ms} < |\Delta_{drift}| \leq 200\text{ ms} \\ \text{hard seek} & \text{if } |\Delta_{drift}| > 200\text{ ms} \end{cases}$$

**Speed Ramp (imperceptible correction):**

For minor drift, playback speed is nudged by ±3% for a calculated duration:

$$v = \begin{cases} 1.03 & \text{if } \Delta_{drift} > 0 \text{ (behind)} \\ 0.97 & \text{if } \Delta_{drift} < 0 \text{ (ahead)} \end{cases}$$

$$T_{ramp} = \frac{|\Delta_{drift}|}{0.03}$$

After $T_{ramp}$ milliseconds, speed returns to 1.0. The human ear is insensitive to speed changes below ~4%, making this correction completely inaudible.

---

## ⚖️ Architectural Trade-offs & Engineering Decisions

### Why WebSockets + Custom NTP Instead of WebRTC or Standard Streaming?

| Approach | Latency Model | Requires Audio Source | Custom Protocol | Complexity |
|---|---|---|---|---|
| **Resonate (WebSocket + NTP)** | Predictable, scheduled | Any HTTP audio URL | Yes (NTP-style) | Medium |
| WebRTC Data Channels | Low but variable | Peer-to-peer stream | Minimal | High |
| HLS / DASH | Buffered, segment-based | Dedicated media server | None | Low |
| RTSP / RTP | Low | Specialized server | None | Very High |

**The core problem WebRTC doesn't solve:** WebRTC excels at peer-to-peer media *streaming* but has no native concept of "all peers should be at position P at time T." Two WebRTC peers receiving the same stream still play back with independent clock references and buffer depths — they drift. You'd need the same NTP + scheduling layer on top of WebRTC anyway.

**Why HTTP audio URLs work better here:** Resonate separates the *audio data plane* (each device fetches its own stream via HTTP) from the *control plane* (the Node.js WebSocket server). This means the server doesn't need to handle any audio bytes — it only sends small JSON events. This makes the server trivially lightweight and the audio quality independent of server capacity.

---

### Latency-Aware Scheduling vs. Immediate Execution

| Strategy | Description | Result |
|---|---|---|
| **Immediate execution** | Server emits "play now"; clients play as soon as they receive it | 50–400 ms desync depending on individual connection latency |
| **Scheduled execution (Resonate)** | Server emits "play at T+1500ms"; all clients converge on the same moment | <30 ms desync across devices on the same network |

The 1500 ms pre-play window is a deliberate trade-off: it introduces 1.5 seconds of perceived latency between the host pressing "Play" and music starting. In exchange, all devices start with near-perfect alignment. This is acceptable for the use case (collaborative listening between friends) and is far less disruptive than music that drifts apart after 30 seconds.

---

### Smooth Speed Ramp vs. Hard Seek for Drift Correction

Hard seeking (jumping to the correct position) is the most accurate correction but produces an audible click or stutter. Speed ramping is inaudible but takes longer to resolve large drifts.

The two-threshold system (±20 ms ignore, ±200 ms ramp, >200 ms seek) means:
- Natural micro-drift (≤20 ms) from timer jitter is simply ignored — it's below human perception
- Accumulated drift from CPU load or clock variance (20–200 ms) is silently corrected
- Catastrophic drift from a paused device, network interruption, or seek operation (>200 ms) triggers a hard seek because a 200+ ms offset is already audible — ramping would take too long

---

## 🔐 Security & Robustness

| Layer | Mechanism |
|---|---|
| Authentication | Firebase JWT verified on every socket connection |
| Token expiry | Automatic client-side refresh via `idTokenChanges()` stream; server re-verifies and updates `socket.user` in place |
| Authorization | Every playback command server-side checks `socket.userId === session.hostUserId` |
| Rate limiting | Per-user token-bucket limiters per event group (ping, playback, session, queue) |
| Input validation | URL validation on both client (`_validateAudioUrl`) and server (`requireValidUrl`) |
| Payload safety | `safeHandler` wraps every socket event callback — malformed payloads default to `{}`, async throws are caught and logged without crashing the process |
| Session caps | `MAX_PARTICIPANTS = 20`, `MAX_QUEUE_LENGTH = 50` prevent memory exhaustion |
| Stale command rejection | Monotonically increasing sequence numbers; server silently drops out-of-order commands |

---

## 🚀 Future Enhancements

1. **Redis-backed session storage and multi-instance scaling**
   The current session store is an in-memory `Map`. Migrating to Redis with `@socket.io/redis-adapter` would enable horizontal scaling (multiple Node.js instances behind a load balancer) and session persistence across server restarts — the architecture is already designed for this transition.

2. **Proximity volume model**
   Each participant could have a virtual "distance" from the host, with volume attenuated by distance. This was listed in the original spec and maps naturally onto the existing `SessionState` — add a `distances: Map<userId, double>` field and send volume multipliers via the existing socket events.

3. **Collaborative queue with participant voting**
   Rather than host-only queue control, extend the queue with a voting mechanism: any participant proposes a track, and the track with the most votes plays next. The server already tracks participants per session and emits `queue_updated` — adding vote tallying is a server-side data model change with no protocol changes needed.

4. **Sync quality telemetry dashboard**
   The `TimeSyncService` already computes `syncQuality` (0.0–1.0) and `smoothedOffset`. Surfacing these in the `AudioPlay` UI (a small indicator showing "Sync: 98%" or "Offset: +12ms") would let users understand their connection quality and help diagnose network issues.

---

## 💻 Installation & Local Development

### Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter SDK | 3.x | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart | 3.x | Bundled with Flutter |
| Node.js | 20.x LTS | [nodejs.org](https://nodejs.org) |
| npm | 9.x+ | Bundled with Node.js |
| Firebase project | Any | [console.firebase.google.com](https://console.firebase.google.com) |

---

### Step 1 — Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/resonate.git
cd resonate
```

---

### Step 2 — Configure Firebase

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Email/Password** authentication
3. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) and place them in the appropriate Flutter directories
4. Download the **service account key** (Project Settings → Service Accounts → Generate new private key) and save it to:
   ```
   backend/serviceAccKey/firebase-key.json
   ```

---

### Step 3 — Start the Node.js backend

```bash
cd backend

# Install dependencies
npm install

# Set environment variables
# Create a .env file in the backend/ directory:
cat > .env << 'EOF'
NODE_ENV=development
PORT=3001
EOF

# Start the server
node server.js
```

You should see:
```
[INFO] Server running on port 3001 [development]
```

The server is now listening at `http://localhost:3001`.

---

### Step 4 — Configure the Flutter app

Find your development machine's local IP address:

```bash
# macOS / Linux
ipconfig getifaddr en0

# Windows
ipconfig
# Look for: IPv4 Address under your Wi-Fi adapter
```

Open `lib/config/app_config.dart` and update the `defaultValue`:

```dart
static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://192.168.1.X:3001', // ← replace with your IP
);
```

> **Android emulator note:** Use `http://10.0.2.2:3001` instead of `localhost` — the emulator maps `10.0.2.2` to the host machine.

---

### Step 5 — Run the Flutter app

```bash
cd frontend/resonate_app

# Install Flutter dependencies
flutter pub get

# Run on a connected device or emulator
flutter run

# To run on a specific device
flutter run -d <device-id>

# List available devices
flutter devices
```

---

### Step 6 — Test synchronization across devices

Testing real sync requires two physical devices (or one physical + one emulator) on the **same local network** as the backend.

```
Test setup:
  Phone A (Host)    ──WiFi──►  Node.js Server (your PC)  ◄──WiFi──  Phone B (Listener)
  192.168.1.10                  192.168.1.5:3001                      192.168.1.20
```

1. Install the Flutter app on both devices (build APK: `flutter build apk --release`)
2. Launch the app on **Phone A** → Create a session → note the session code
3. Launch the app on **Phone B** → Join session → enter the code
4. On Phone A (Host): paste an `.mp3` URL or use the music search → press Play
5. Both devices should begin playback within <30ms of each other

**Verifying sync:** Place both devices next to each other with volume up. You should hear a single, crisp audio signal — not an echo or phasing effect. Any audible echo indicates >20ms desync.

---

### Step 7 — Production build

```bash
# Android release build with production backend URL
flutter build apk --release \
  --dart-define=BASE_URL=https://your-production-server.com

# iOS release build
flutter build ipa --release \
  --dart-define=BASE_URL=https://your-production-server.com
```

---

## 📁 Project Structure

```
resonate/
├── backend/
│   ├── config/
│   │   ├── firebase.js           # Firebase Admin SDK init
│   │   └── socketConfig.js       # Socket.IO CORS and ping config
│   ├── constants/
│   │   ├── events.js             # CLIENT/SERVER event name constants
│   │   └── limits.js             # MAX_PARTICIPANTS, MAX_QUEUE_LENGTH
│   ├── controller/
│   │   └── sessionController.js  # All session & playback business logic
│   ├── middleware/
│   │   ├── httpCors.js           # Environment-aware HTTP CORS
│   │   └── socketAuth.js         # Firebase JWT verification + refresh
│   ├── models/
│   │   └── session.js            # Session data model
│   ├── routes/
│   │   └── musicRouter.js        # iTunes search proxy with LRU cache
│   ├── services/
│   │   ├── clientRegistry.js     # Socket ↔ userId mapping
│   │   ├── itunesClient.js       # iTunes API network layer
│   │   ├── musicService.js       # Music search business logic + cache
│   │   └── sessionManager.js     # In-memory session Map operations
│   ├── sockets/
│   │   └── socketHandler.js      # Socket event registration + rate limiting
│   └── utils/
│       ├── idGenerator.js        # Collision-free session ID generation
│       ├── logger.js             # Structured console logging
│       ├── rateLimiter.js        # Token-bucket rate limiter
│       ├── safeHandler.js        # Async error boundary for socket events
│       ├── timeUtils.js          # computeStartTime (sync contract docs)
│       └── validation.js         # URL and session validators
│
└── frontend/resonate_app/
    ├── lib/
    │   ├── config/
    │   │   └── app_config.dart       # BASE_URL and endpoint config
    │   ├── controllers/
    │   │   └── socket_controller.dart # Raw socket command emitter
    │   ├── providers/
    │   │   ├── audio_service.dart     # just_audio wrapper
    │   │   ├── audioservice_provider.dart
    │   │   ├── auth_controller_provider.dart
    │   │   ├── auth_provider.dart
    │   │   ├── session_notifier.dart  # Core state machine
    │   │   ├── session_provider.dart  # Riverpod providers
    │   │   └── session_state.dart     # Immutable state model
    │   ├── services/
    │   │   ├── drift_corrector.dart   # Periodic drift monitoring loop
    │   │   ├── music_service.dart     # MusicRepository + typed errors
    │   │   ├── socket_service.dart    # Socket.IO connection management
    │   │   └── time_sync_service.dart # NTP-style clock sync
    │   └── ui/
    │       ├── audio_play.dart        # Main player screen
    │       ├── auth_gate.dart
    │       ├── auth_screen.dart
    │       ├── home_screen.dart
    │       ├── join_session.dart
    │       └── music_search_screen.dart
    └── pubspec.yaml
```

---

<div align="center">

Built with precision. Synchronized to the millisecond.

**Resonate** — because music is better together.

</div>