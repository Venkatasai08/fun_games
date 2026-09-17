# 🎮 FunGames — Real-time Multiplayer Game Platform

A modular **Flutter + Firebase** game platform built for real-time multiplayer gaming. Currently ships with two games: **Tambola** (Housie/Bingo) and **DraftClash** (1v1 character draft). The architecture is designed to support additional games from a single codebase.

---

## 🕹️ Games

| Game | Status | Players | Description |
|---|---|---|---|
| 🎟️ **Tambola** | ✅ Live | 2–20 | Call numbers, mark your ticket, shout Housie! |
| ⚔️ **DraftClash** | 🧪 Beta | 1v1 only | Draft anime & movie characters into a 6-slot team. Highest total level wins! |

---

## ✨ Platform Features

| | |
|---|---|
| 🔐 **Auth** | Email/password login, registration & guest (anonymous) mode |
| 👤 **Guest Mode** | Play instantly — no account needed, session survives restarts |
| 🏠 **Games Lobby** | Hub screen for navigating between all available games |
| 📱 **Cross-platform** | Android + Web from a single codebase |

---

## 🗂️ Firestore Structure

```
profiles/{uid}                      ← TOP-LEVEL collection (owned by AuthService)
      username, email, avatar_color,
      is_guest, created_at

fun_games/stats                     ← top-level app stats document
      total_users, total_rooms,
      total_games_finished, updated_at

cards/{cardId}                      ← TOP-LEVEL card catalogue (DraftClash)
      franchise, name, description,
      level (1–10), imageUrl

tambola/app_data                    ← Tambola root document
  ├── rooms/{roomId}                ← subcollection
  │     name, host_id, host_username,
  │     password, room_code,
  │     max_number, status,
  │     called_numbers[], last_called,
  │     auto_call, auto_call_interval,
  │     suggestion_mode, sound_enabled,
  │     member_count, is_paused,
  │     winner_id, winner_username,
  │     created_at, updated_at
  │
  └── room_members/{memberId}       ← subcollection
        room_id, user_id, username,
        ticket (flat int[30] — 0 = blank),
        marked_numbers[],
        has_claimed_housie,
        joined_at

draftclash/app_data                 ← DraftClash root document
  ├── rooms/{roomId}                ← subcollection
  │     code, room_name, status,
  │     player1_id, player1_username,
  │     player2_id, player2_username,
  │     current_turn, deck[],
  │     current_card_id,
  │     skips_used{uid→bool},
  │     turn_deadline,
  │     player1_score, player2_score,
  │     winner_id, winner_username,
  │     franchise, password, is_public,
  │     created_at
  │
  └── room_members/{memberId}       ← subcollection
        room_id, user_id, username,
        board_captain, board_vice_captain,
        board_tank, board_duelist,
        board_support, board_traitor,
        total_score, joined_at
```

> **Profiles and stats are top-level** so `AuthService` owns them independently of any individual game.

---

## 🚀 Setup

### 1. Firebase Project

Manage at [console.firebase.google.com](https://console.firebase.google.com).

### 2. Enable Authentication Providers

| Provider | Used for |
|---|---|
| ✅ **Email / Password** | Registered users |
| ✅ **Anonymous** | Guest users — **must be enabled or guest login will fail** |

### 3. Firestore Security Rules

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /profiles/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == uid;
    }

    match /fun_games/stats {
      allow read, write: if request.auth != null;
    }

    match /cards/{cardId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null; // restrict to admin in production
    }

    match /tambola/app_data {
      allow read, write: if request.auth != null;
      match /rooms/{roomId} {
        allow read, write: if request.auth != null;
      }
      match /room_members/{memberId} {
        allow read, write: if request.auth != null;
      }
    }

    match /draftclash/app_data {
      allow read, write: if request.auth != null;
      match /rooms/{roomId} {
        allow read, write: if request.auth != null;
      }
      match /room_members/{memberId} {
        allow read, write: if request.auth != null;
      }
    }
  }
}
```

### 4. Android Setup

1. Firebase Console → **Add app** → Android
2. Package name: `com.example.fun_games`
3. Download `google-services.json` → place in `android/app/`
4. Update `lib/firebase_options.dart`

### 5. Run

```bash
flutter pub get

# Android
flutter run

# Web
flutter run -d chrome

# Release builds
flutter build apk --release
flutter build appbundle --release
flutter build web --release
```

---

## 📁 Project Structure

```
lib/
├── main.dart                           # Firebase init + AuthGate → GamesLobbyScreen
├── firebase_options.dart               # Platform-specific Firebase config
│
├── config/
│   └── app_theme.dart                  # Dark theme, color tokens, text styles (Poppins)
│
├── blocs/
│   └── auth/                           # AuthBloc — delegates entirely to AuthService
│       ├── auth_bloc.dart
│       ├── auth_event.dart
│       └── auth_state.dart
│
├── screens/
│   ├── auth_screen.dart                # Login / Register / Join as Guest
│   └── games_lobby_screen.dart         # Game selection hub (Tambola + DraftClash cards)
│
├── services/
│   ├── auth_service.dart               # Central auth + profile logic (owns profiles/{uid})
│   └── guest_service.dart              # Thin facade over AuthService (backward compat)
│
├── tambola/                            ← Tambola game module
│   ├── blocs/
│   │   ├── rooms/                      # RoomsBloc — rxdart live stream, pagination, filters
│   │   ├── game/                       # GameBloc — live game state, number calling, claims
│   │   └── create_room/               # CreateRoomBloc — room creation form state
│   ├── models/
│   │   ├── room.dart                   # Room + RoomMember models
│   │   └── ticket_model.dart           # Ticket generation + flat int[30] serialization
│   ├── screens/
│   │   ├── rooms_screen.dart           # 3-tab shell: Home / Search / Create (inline)
│   │   ├── game_screen.dart            # Live gameplay screen
│   │   ├── create_room_screen.dart     # ⚠️ DEPRECATED — creation now in rooms_screen.dart
│   │   ├── fullscreen_ticket_screen.dart  # Landscape fullscreen ticket view
│   │   └── spectate_screen.dart        # Read-only live spectator view
│   ├── services/
│   │   ├── room_service.dart           # All Firestore reads/writes + rxdart streams
│   │   └── tts_service.dart            # Singleton TTS wrapper (flutter_tts)
│   └── widgets/
│       ├── tambola_ticket_widget.dart
│       └── number_board_widget.dart
│
└── draftclash/                         ← DraftClash game module
    ├── blocs/
    │   ├── lobby/                      # DraftLobbyBloc — room list, create, join, wait
    │   │   ├── draft_lobby_bloc.dart
    │   │   ├── draft_lobby_event.dart
    │   │   └── draft_lobby_state.dart
    │   └── game/                       # DraftGameBloc — card draw, assignment, countdown
    │       ├── draft_game_bloc.dart
    │       ├── draft_game_event.dart
    │       └── draft_game_state.dart
    ├── models/
    │   ├── draft_card.dart             # DraftCard (id, franchise, name, level, imageUrl)
    │   └── draft_room.dart             # DraftRoom + DraftMember + BoardSlot enum
    ├── screens/
    │   ├── draft_lobby_screen.dart     # 3-tab lobby: Home / Search / Create
    │   ├── draft_game_screen.dart      # Live 1v1 draft game screen
    │   └── admin_screen.dart           # Card catalogue admin (email-gated)
    ├── services/
    │   ├── draft_service.dart          # All Firestore logic for DraftClash
    │   └── draft_sound_service.dart    # TTS + haptics for DraftClash events
    └── widgets/
        ├── draft_board_widget.dart     # 6-slot board display
        └── draft_card_widget.dart      # Single card display widget
```

---

## 🧭 Navigation Flow

```
App start
    │
    └── AuthGate (StreamBuilder on Firebase authStateChanges)
          │
          ├── Not logged in ──► AuthScreen
          │                       ├── Login
          │                       ├── Register
          │                       └── Join as Guest
          │
          └── Logged in ──────► GamesLobbyScreen
                                    │
                                    ├── Tap Tambola ──► RoomsScreen (3-tab bottom nav)
                                    │                       ├── Home (ongoing + finished rooms)
                                    │                       ├── Search (by 6-digit code)
                                    │                       └── Create (inline form)
                                    │                               │
                                    │                         Join / Create ──► GameScreen
                                    │                                               │
                                    │                                         SpectateScreen
                                    │
                                    └── Tap DraftClash ──► DraftLobbyScreen (3-tab bottom nav)
                                                               ├── Home (ongoing + finished rooms)
                                                               ├── Search (by 6-digit code)
                                                               └── Create (room name, franchise, password)
                                                                       │
                                                                 Join / Create ──► DraftGameScreen
```

---

## 🎟️ Tambola

### Features

| | |
|---|---|
| 🏠 **Room Browser** | Ongoing & finished tabs with live updates via rxdart streams |
| 🔍 **Room Search** | Find any room by 6-digit code |
| 🔒 **Room Passwords** | Optional password protection |
| 🎫 **Dynamic Tickets** | Auto-generated 3×10 tickets, 5 numbers per row |
| ⚡ **Real-time** | Firestore `onSnapshot` — works on Jio & all major Indian ISPs |
| 🤖 **Auto-Call** | 3 / 5 / 10 / 15 / 30 s configurable intervals |
| 💡 **Suggestion Mode** | Called numbers glow amber on ticket |
| 🔊 **TTS** | Text-to-speech number announcements; per-player sound toggle |
| 🏆 **Housie Claims** | Server-validated full house |
| ⏸️ **Pause / Resume** | Host can pause auto-call mid-game |
| 👁️ **Spectate** | Read-only live view of any room |
| 📺 **Fullscreen Ticket** | Landscape fullscreen mode |
| 🔖 **Pagination** | 6 rooms per page |
| 🔎 **Finished Filters** | All / My Rooms / Winners / Cancelled |
| 🎉 **Confetti** | Winner celebration burst |

### Game Flow

```
RoomsScreen
    │
    ├── Create Room (host only) — name, max number (default 100), auto-call,
    │                              hint mode, sound, password
    │
    └── Join Room ──► GameScreen
                          ├── [Host] Lobby — waiting for ≥2 members
                          ├── [Host] Start Game
                          ├── [Host] Call Number OR Auto-Call timer
                          ├── [Host] ⚙️ Settings dialog (auto-call, interval, hints, sound)
                          ├── [Host] Pause / Resume / Cancel
                          ├── [Players] Mark numbers on ticket
                          ├── [Players] Fullscreen ticket (landscape)
                          ├── [Players] Number Board dialog
                          ├── [Players] Sound toggle (local only)
                          └── HOUSIE! ──► server validates ──► winner + confetti
```

### Spectate Mode

Spectate button appears on playing, finished, and cancelled room cards. Zero write operations — 100% read-only Firestore streams. Players sorted: winner first, then by descending match count.

### Ticket Format

- **10 columns, 3 rows** = 30 cells; each row has exactly **5 numbers** and 5 blanks
- Column ranges scale with `max_number` (supports 50 / 100 / 150)
- Stored flat as `int[30]` in Firestore (nested arrays are forbidden); `0` = blank

```dart
TicketGenerator.toJson(ticket)    // 3×10 grid → flat int[30]
TicketGenerator.fromJson(flat)    // flat int[30] → 3×10 grid
```

### Sound Architecture

| Setting | Where stored | Who controls |
|---|---|---|
| `room.soundEnabled` | Firestore room doc | Host sets at creation — default for new joiners |
| `GameLoaded.soundEnabled` | BLoC state only (local) | Each player toggles for themselves |

Host defaults ON. Per-player toggle is never written to Firestore — resets to room default on rejoin.

---

## ⚔️ DraftClash

A real-time 1v1 character drafting game. Players alternate picking character cards into a 6-slot team board. The player with the highest total level sum wins.

### Game Concepts

**Cards** — Characters from popular franchises (Naruto, Attack on Titan, Dragon Ball Z, Marvel, etc.), each with a level 1–10:

| Tier | Level range |
|---|---|
| COMMON | 1–3 |
| RARE | 4–6 |
| EPIC | 7–8 |
| LEGENDARY | 9–10 |

**Board Slots** — Each player fills 6 slots: Captain, Vice Captain, Tank, Duelist, Support, Traitor.

**Scoring** — `total_score = sum of levels of all assigned cards`. Higher total wins; equal scores = draw.

### Game Flow

```
DraftLobbyScreen
    │
    └── Create Room ──► DraftLobbyWaiting (show 6-digit code, wait for opponent)
                              │
                        Opponent joins ──► DraftService._startDraft()
                                             - Shuffle card pool (filtered by franchise if set)
                                             - Take up to 50 cards as deck
                                             - Reveal first card, set 15s turn deadline
                                             │
                                        DraftGameScreen
                                             │
                                        Players alternate:
                                          ├── Pick a slot → card assigned, score updated
                                          ├── Skip (once per player) → pass current card
                                          └── Timer expires → auto-assign to first empty slot
                                             │
                                        Both boards full → scores tallied → winner announced
```

### Turn Timer

- **15 seconds** per turn, stored as `turn_deadline` (Firestore Timestamp)
- Countdown shown live in `DraftGameBloc` via a local `Timer.periodic`
- If timer expires and it's your turn, `DraftGameAutoAssign` fires → first empty slot gets the card

### Room Options

| Option | Details |
|---|---|
| Room name | Display name for the room |
| Franchise filter | Restrict the card deck to one franchise (`null` = all) |
| Password | Optional 6-char password; guests and players must enter it to join |
| Public | All rooms are public (searchable by code) in the current build |

### Sound (DraftSoundService)

Uses `flutter_tts` + `HapticFeedback`/`SystemSound`. Announces game events in English TTS: room created, opponent joined, draft starting, your turn, card drawn, slot filled, skip used, 5-second warning, round over, victory/defeat/draw. Global toggle stored as `DraftSoundService.soundEnabled`.

### Admin Panel

Accessible via the avatar menu in `GamesLobbyScreen` for accounts whose email matches `@admin` or `admin@` (replace with Firebase Custom Claims for production).

Features:
- View card catalogue stats (total cards, franchise count)
- Seed 20 sample cards across 4 franchises
- Add cards manually (franchise, name, description, level 1–10, image URL)
- AI generation placeholder — wired to a Firebase Cloud Function stub (not yet deployed)

---

## 🏗️ Architecture

### BLoC Pattern

All business logic lives in BLoC classes. Screens are pure UI.

| BLoC | Game | Responsibility |
|---|---|---|
| `AuthBloc` | Platform | Delegates 100% to `AuthService`; translates Firebase exceptions |
| `RoomsBloc` | Tambola | rxdart live stream of rooms + membership; pagination; filter state |
| `CreateRoomBloc` | Tambola | Form state for room creation (inline in rooms_screen) |
| `GameBloc` | Tambola | Live game state; number calling; auto-call timer; Housie validation |
| `DraftLobbyBloc` | DraftClash | Room list stream; create/join flow; waiting-for-opponent subscription |
| `DraftGameBloc` | DraftClash | Card draw stream; turn countdown; assign/skip; auto-assign on timeout |

### Live Streams with rxdart (Tambola)

`RoomService.watchRooms()` uses `Rx.combineLatest2` to merge the rooms stream with the current user's membership stream — each room card instantly knows if you're a member.

```dart
Rx.combineLatest2(roomsStream, membershipStream,
  (rooms, joinedIds) => _mergeRoomsWithMembership(rooms, joinedIds))
```

### AuthService

Central owner of all authentication and profile logic. `GuestService` is a thin backward-compatible facade.

```dart
await AuthService.signIn(email: e, password: p);
await AuthService.register(email: e, password: p, username: u);
await AuthService.signInAsGuest(guestName);
await AuthService.upgradeGuestToAccount(email: e, password: p, username: u);
await AuthService.signOut();
await AuthService.getUsername(uid);
```

---

## 👤 Guest Mode

Guests use **Firebase Anonymous Authentication** — real `uid`, all game features work.

| Feature | Guest | Signed-in |
|---|---|---|
| Browse & search rooms | ✅ | ✅ |
| Join & play Tambola | ✅ | ✅ |
| Play DraftClash | ✅ | ✅ |
| Spectate rooms | ✅ | ✅ |
| Create Tambola rooms | ❌ | ✅ |
| Create DraftClash rooms | ✅ | ✅ |
| Persistent session | ✅ SharedPreferences | ✅ Firebase Auth |
| Upgrade to full account (name kept) | ✅ | — |

---

## 🎨 Design System

### Color Palette

| Token | Hex | Used for |
|---|---|---|
| `primary` | `#6C63FF` | Buttons, active states, focus rings |
| `primaryLight` | `#9C94FF` | Gradients, called number cells |
| `secondary` | `#FF6584` | Last-called glow, LIVE card accent |
| `accent` | `#43E97B` | Winner badge, Housie button, "Create Account" |
| `warning` | `#FFC107` | Lock icons, guest notices |
| `bgDark` | `#0F0E1A` | Scaffold background |
| `bgCard` | `#1A1830` | Card surfaces, dialogs |
| `bgCardLight` | `#221F3A` | Input fill, pill backgrounds |
| `border` | `#2E2B50` | All dividers and container borders |
| `textSecondary` | `#B0AECF` | Subtitles, placeholders, labels |

### Typography

Poppins throughout (`google_fonts`). Weight scale: 400 body · 600 labels · 700 headings · 800/900 winner names & big numbers.

### Card Design Language (Tambola rooms)

- `borderRadius: 20` with `ClipRRect`
- 4px left accent bar — gradient fade from status colour to transparent
- Background gradient communicates game state
- 44px rounded-square host avatar
- Status badge pill ("LIVE" + pulsing dot · "WAITING" · "ENDED" · "CANCELLED")
- `_MiniPill` chips for metadata (players, range, called count, auto-call, hints)

---

## 📦 Dependencies

| Package | Version | Purpose |
|---|---|---|
| `firebase_core` | `^3.14.0` | Firebase SDK initialisation |
| `firebase_auth` | `^5.5.2` | Email/password + anonymous auth |
| `cloud_firestore` | `^5.6.9` | Database + real-time listeners |
| `flutter_bloc` | `^8.1.6` | BLoC state management |
| `equatable` | `^2.0.5` | Value equality for BLoC states/events |
| `rxdart` | `^0.28.0` | `combineLatest2` for merged live streams |
| `flutter_tts` | `4.0.2` | TTS for Tambola numbers + DraftClash events |
| `shared_preferences` | `^2.3.2` | Guest name + UID persistence |
| `google_fonts` | `^6.1.0` | Poppins font family |
| `flutter_animate` | `^4.5.0` | Entrance animations |
| `shimmer` | `^3.0.0` | Loading skeleton states |
| `confetti` | `^0.7.0` | Tambola winner celebration |
| `crypto` | `^3.0.3` | Password hashing utilities |

---

## 🤖 Android Build Notes

### Kotlin Version

Pinned to **1.9.25** in `android/settings.gradle.kts` for `flutter_tts 4.0.2` compatibility:

```kotlin
id("org.jetbrains.kotlin.android") version "1.9.25" apply false
```

### `minSdk = 23`

`firebase-auth ^23` requires Android SDK 23 (Android 6.0+). Set in `android/app/build.gradle.kts`:

```kotlin
minSdk = 23
```

### Google Services Plugin

`android/settings.gradle.kts`:
```kotlin
id("com.google.gms.google-services") version "4.4.3" apply false
```

`android/app/build.gradle.kts`:
```kotlin
id("com.google.gms.google-services")
```

---

## ⚡ Why Firebase Instead of Supabase

The original project used Supabase (PostgreSQL + Realtime WebSockets).

**Problem:** Jio (India's largest ISP) blocks WebSocket connections to `*.supabase.co`.

| | Supabase Realtime | Firestore `onSnapshot` |
|---|---|---|
| Domain | `*.supabase.co` — **blocked by Jio** ❌ | `*.googleapis.com` — works everywhere ✅ |

---

## 🛡️ Security Notes

- All Firestore reads/writes require `request.auth != null`
- Profile writes scoped: `request.auth.uid == uid`
- Tambola Housie claims server-validated — clients cannot fake a win
- DraftClash score tallied server-side in `checkAndFinaliseIfDone`
- DraftClash admin screen gated by email pattern — replace with Firebase Custom Claims for production
- Room passwords stored in plain text — hash with SHA-256 (`crypto` package) before production

---

## 🔮 Roadmap

**Tambola**
- [ ] Early prize claims — First Row, Second Row, Four Corners, Top Line, Bottom Line
- [ ] In-game chat
- [ ] Player avatars / profile pictures
- [ ] Game history and personal leaderboard
- [ ] Hash room passwords with SHA-256

**DraftClash**
- [ ] AI card generation via Firebase Cloud Function (stub already in admin screen)
- [ ] Image support for cards (imageUrl field already stored)
- [ ] Post-game board comparison screen
- [ ] Best-of-3 match mode
- [ ] Spectate mode for ongoing drafts

**Platform**
- [ ] Push notifications
- [ ] iOS support (register bundle ID in Firebase)
- [ ] More games
- [ ] Admin dashboard using `watchAppStats()` stream
