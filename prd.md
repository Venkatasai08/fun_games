# FunGames — Product Requirements Document (PRD)

> **Version:** 1.0  
> **Last updated:** March 2026  
> **Platform:** Android (primary) · Web (secondary)  
> **Status:** Beta / Active Development

---

## 1. Product Overview

FunGames is a real-time multiplayer game platform built for casual gaming, primarily targeting Indian users. The platform ships two games from a single Flutter + Firebase codebase:

| Game | Genre | Players |
|---|---|---|
| **Tambola** | Number-calling / Bingo variant | 2–20 per room |
| **DraftClash** | 1v1 character drafting strategy | Exactly 2 players |

The platform is intentionally modular — additional games can be plugged in without rearchitecting the shared foundation (auth, lobby, theming, navigation).

---

## 2. Goals & Success Metrics

### Primary Goals
- Deliver lag-free real-time multiplayer gaming over Indian mobile networks (including Jio).
- Support both registered accounts and frictionless guest play.
- Keep infrastructure costs near zero during early growth (Firebase free tier, Groq free tier, Jikan free API).

### Key Metrics
- Rooms created per day
- Games completed vs. abandoned (tracked via `fun_games/stats`)
- Guest-to-registered upgrade rate
- Average session length per game

---

## 3. User Personas

### 3.1 Casual Player (Guest)
- Wants to join a game instantly without creating an account.
- Plays Tambola with family/friends during gatherings.
- Expects intuitive UI — no learning curve.

### 3.2 Registered Player
- Hosts Tambola rooms regularly; wants persistent username and history.
- Plays DraftClash competitively; cares about card strategy and tier system.
- May upgrade from Guest after enjoying a session.

### 3.3 Admin
- Internal role (email-gated in current build).
- Manages the DraftClash card catalogue: seeding, adding, AI-generating, editing cards.
- Accesses the admin panel from the Games Lobby avatar menu.

---

## 4. Authentication & User Management

### 4.1 Auth Flows

| Flow | Method | Notes |
|---|---|---|
| Register | Email + Password + Username | Stored in `profiles/{uid}` |
| Login | Email + Password | |
| Guest | Firebase Anonymous Auth | Name stored in SharedPreferences |
| Upgrade | Anonymous → Email/Password | Username preserved on upgrade |
| Sign Out | Firebase sign-out | Clears session |

### 4.2 Guest Mode Capabilities

| Feature | Guest | Registered |
|---|---|---|
| Browse & search rooms | ✅ | ✅ |
| Join & play Tambola | ✅ | ✅ |
| Play DraftClash | ✅ | ✅ |
| Spectate rooms | ✅ | ✅ |
| Host Tambola rooms | ❌ | ✅ |
| Host DraftClash rooms | ✅ | ✅ |
| Persistent session | SharedPreferences | Firebase Auth |

### 4.3 Session Persistence
On app start, `AuthService.restoreSession()` checks Firebase Auth state before `runApp`. Guest sessions survive app restarts via SharedPreferences storing the anonymous UID.

---

## 5. Games Lobby

The **GamesLobbyScreen** is the post-login hub. It displays game tiles (Tambola, DraftClash) and an avatar menu in the top-right for sign-out and admin access. Future games will be added as additional tiles here.

---

## 6. Tambola

### 6.1 Overview
Tambola is the Indian Housie (Bingo) variant. The host calls numbers; players mark their tickets; the first player to complete a full house and claim it wins.

### 6.2 Room Management

| Feature | Details |
|---|---|
| Create room | Name, max number (50/100/150), optional password, auto-call settings, hint mode, sound |
| Browse rooms | Ongoing tab + Finished tab; live updates via rxdart streams |
| Search | Find any room by its 6-digit code |
| Pagination | 6 rooms per page |
| Finished filters | All / My Rooms / Winners / Cancelled |
| Password protection | Optional; verified server-side before join |

### 6.3 Gameplay

| Feature | Details |
|---|---|
| Ticket | Auto-generated 3×10 grid; 5 numbers per row; adapts to max_number |
| Number calling | Manual (host tap) or Auto-call (3/5/10/15/30s intervals) |
| Suggestion mode | Called numbers glow amber on ticket |
| Pause / Resume | Host can pause auto-call mid-game |
| Mark numbers | Players tap numbers on their ticket |
| Fullscreen ticket | Landscape fullscreen view for easier number tracking |
| Number board | Dialog showing all called numbers |
| Housie claim | Server-validated full house — clients cannot fake a win |
| Sound | TTS number announcements; per-player toggle (not synced to Firestore) |
| Winner | Confetti burst; winner name stored on room doc |
| Spectate | Read-only real-time view of any room; zero writes |

### 6.4 Ticket Format
- 10 columns, 3 rows = 30 cells; each row has exactly 5 numbers and 5 blanks.
- Stored flat as `int[30]` in Firestore (nested arrays forbidden); `0` = blank.
- Column number ranges scale with `max_number`.

### 6.5 Sound Architecture
- `room.soundEnabled` — host sets at room creation; default for new joiners.
- Per-player toggle is BLoC state only (never written to Firestore); resets on rejoin.

### 6.6 Spectate Mode
- Spectate button on playing, finished, and cancelled room cards.
- 100% read-only Firestore streams — zero write operations.
- Players sorted: winner first, then by descending match count.

---

## 7. DraftClash

### 7.1 Overview
A real-time 1v1 character drafting game. Players alternate picking character cards into a 6-slot team board. The player with the higher total level sum wins.

### 7.2 Card System

| Tier | Level Range |
|---|---|
| COMMON | 1.0–3.4 |
| RARE | 3.5–5.9 |
| EPIC | 6.0–7.9 |
| LEGENDARY | 8.0–9.4 |
| MYTHIC | 9.5–10.0 |

Cards belong to franchises (Naruto, Attack on Titan, Dragon Ball Z, Marvel, FC Barcelona, etc.). Each card has: `name`, `description`, `level` (decimal 1.0–10.0), `imageUrl`, and `franchiseIds[]`.

### 7.3 Board Slots
Each player fills 6 slots: **Captain, Vice Captain, Tank, Duelist, Support, Traitor**.

Scoring: `total_score = sum of levels of all assigned cards`. Higher total wins; equal scores = draw.

### 7.4 Lobby & Room Options

| Option | Details |
|---|---|
| Room name | Display name for the room |
| Franchise filter | Restrict card deck to one or multiple franchises (`null` = all) |
| Password | Optional; guests/players must enter it to join |
| Public | All rooms searchable by code |
| Pass & Play | Local 2-player mode on one device |

### 7.5 Gameplay Flow

1. Host creates room → gets 6-digit code.
2. Opponent joins by code → `_startDraft()` fires automatically.
3. Cards shuffled deterministically via `deck_seed` (both clients build the same deck locally — no deck stored in Firestore).
4. Players alternate turns: Pick a slot → card assigned → turn switches.
5. Each turn: 15-second countdown. Timer expiry → auto-assign to first empty slot.
6. Skip: each player can skip once per game (pass the current card).
7. All 6 slots filled for both players → scores tallied → winner announced.

### 7.6 Turn Timer
- 15 seconds per turn; stored as `turn_deadline` (Firestore Timestamp).
- Live countdown rendered in `DraftGameBloc` via `Timer.periodic`.
- Expiry triggers `DraftGameAutoAssign` event → first empty slot.

### 7.7 Sound (DraftSoundService)
TTS announcements for: room created, opponent joined, draft starting, your turn, card drawn, slot filled, skip used, 5-second warning, round over, victory/defeat/draw. Global toggle via `DraftSoundService.soundEnabled`.

### 7.8 Admin Panel
Email-gated (pattern: `@admin` or `admin@` — replace with Firebase Custom Claims in production).

Features:
- View catalogue stats (total cards, franchise count).
- Seed 20 sample cards across 4 franchises.
- Add cards manually (franchise, name, description, level 1–10, image URL).
- AI card generation (Groq API / Llama 3.3 70B) with image fetching from Jikan (anime) or Wikipedia (other).
- Cloudinary upload on Save.
- Franchise management (add, edit, delete, category tagging).
- Card edit and delete.
- Bulk card import via paste JSON + AI normalisation.

### 7.9 AI Card Generation
- Model: Llama 3.3 70B via Groq API (free tier: 14,400 req/day, 30 RPM).
- Franchise categories: `anime`, `movie`, `game`, `comics`, `sports`, `other`.
- Sequential batch logic: uses `existingCards.length` as offset; adjusts tier targets per batch (Legendary first → Epic → Rare/Common).
- Franchise Centrality scoring ensures iconic characters are prioritised over obscure-but-powerful ones.
- Images: Jikan (MyAnimeList, no key) for anime; Wikipedia API for others; DuckDuckGo fallback.
- Cloudinary stores final CDN URLs.

---

## 8. Roadmap

### Tambola
- [ ] Early prize claims — First Row, Second Row, Four Corners, Top/Bottom Line
- [ ] In-game chat
- [ ] Player avatars / profile pictures
- [ ] Game history and personal leaderboard
- [ ] SHA-256 hash for room passwords

### DraftClash
- [ ] Post-game board comparison screen
- [ ] Best-of-3 match mode
- [ ] Spectate mode for ongoing drafts
- [ ] Confetti burst on win
- [ ] Rematch button
- [ ] Room auto-cancel after 10 minutes waiting
- [ ] Push notification when opponent joins

### Platform
- [ ] Push notifications
- [ ] iOS support (Firebase bundle ID registration)
- [ ] More games
- [ ] Admin dashboard with live `watchAppStats()` stream
- [ ] Firestore security rules tightened (Phase 8 rules)
- [ ] Firebase Custom Claims for admin instead of email pattern

---

## 9. Out of Scope (Current Version)
- iOS release (build config not set up)
- Monetisation / in-app purchases
- Global leaderboards
- Social features (friends list, direct messaging)
- In-game image generation for DraftClash cards (Cloudinary upload on Save only)
