# FunGames — Tech Stack

> **Last updated:** March 2026

---

## 1. Runtime & Framework

| Layer | Technology | Version |
|---|---|---|
| UI Framework | Flutter | SDK `>=3.0.0 <4.0.0` |
| Language | Dart | >=3.0.0 |
| Target Platforms | Android (primary), Web (secondary) |  |
| Min Android SDK | 23 (Android 6.0+) — required by `firebase-auth ^23` | |
| Orientation | Portrait locked by default; landscape override in FullscreenTicketScreen | |

---

## 2. Backend — Firebase

All backend services run on Firebase. Firebase was chosen over Supabase because Jio (India's largest ISP) blocks WebSocket connections to `*.supabase.co`, while Firestore `onSnapshot` uses `*.googleapis.com` which is universally accessible.

| Service | Package | Version | Purpose |
|---|---|---|---|
| Firebase Core | `firebase_core` | `^3.14.0` | SDK initialisation |
| Authentication | `firebase_auth` | `^5.5.2` | Email/password + anonymous auth |
| Firestore | `cloud_firestore` | `^5.6.9` | Real-time database + live listeners |
| Cloud Functions | Firebase Functions (Node.js) | — | AI card generation stub (not yet deployed) |

### Firebase Initialization
- Web: `DefaultFirebaseOptions.web` passed explicitly (different config object).
- Android/other: `Firebase.initializeApp()` without options (reads `google-services.json`).

---

## 3. State Management

| Package | Version | Usage |
|---|---|---|
| `flutter_bloc` | `^8.1.6` | BLoC pattern — all business logic lives in BLoC classes; screens are pure UI |
| `equatable` | `^2.0.5` | Value equality for BLoC states and events |

### BLoC Architecture

| BLoC | Scope | Responsibility |
|---|---|---|
| `AuthBloc` | Platform | Delegates entirely to `AuthService`; translates Firebase exceptions to typed states |
| `RoomsBloc` | Tambola | rxdart live stream of rooms + membership; pagination; filter state |
| `CreateRoomBloc` | Tambola | Form state for room creation (inline in `RoomsScreen`) |
| `GameBloc` | Tambola | Live game state; number calling; auto-call timer; Housie validation |
| `DraftLobbyBloc` | DraftClash | Room list stream; create/join flow; waiting-for-opponent subscription |
| `DraftGameBloc` | DraftClash | Card draw stream; turn countdown; assign/skip; auto-assign on timeout |

---

## 4. Real-Time Data Layer

### Tambola — rxdart Streams
`RoomService.watchRooms()` uses `Rx.combineLatest2` to merge two Firestore streams (all rooms + current user's memberships) without any sequential per-room fetches:

```dart
Rx.combineLatest2(roomsStream, membershipStream,
  (rooms, joinedIds) => _mergeRoomsWithMembership(rooms, joinedIds))
```

### DraftClash — Deterministic Deck
The card deck is **never stored in Firestore**. Both clients call `DraftService.buildDeck(cards, room.deckSeed)` with the same seed and get the identical shuffled sequence. Only `deck_seed` (an int) is stored on the room doc.

```dart
static List<String> buildDeck(List<DraftCard> cards, int seed) {
  final sorted = List<DraftCard>.from(cards)..sort((a, b) => a.id.compareTo(b.id));
  sorted.shuffle(Random(seed));
  return sorted.take(_maxDeckSize).map((c) => c.id).toList();
}
```

---

## 5. Reactive Streams

| Package | Version | Usage |
|---|---|---|
| `rxdart` | `^0.28.0` | `combineLatest2` for Tambola's merged room+membership live stream |

---

## 6. Persistence

| Package | Version | Usage |
|---|---|---|
| `shared_preferences` | `^2.3.2` | Guest UID + name persistence across app restarts |

---

## 7. UI & Theming

| Package | Version | Usage |
|---|---|---|
| `google_fonts` | `^6.1.0` | Poppins font family throughout the app |
| `flutter_animate` | `^4.5.0` | Entrance animations on cards, screens, and overlays |
| `shimmer` | `^3.0.0` | Loading skeleton states while Firestore data loads |
| `confetti` | `^0.7.0` | Winner celebration confetti burst (Tambola) |

---

## 8. Audio & Haptics

| Package | Version | Usage |
|---|---|---|
| `flutter_tts` | `4.0.2` (pinned) | TTS for Tambola number calls + DraftClash game events |
| Flutter `HapticFeedback` | Built-in | Light/medium/heavy haptic pulses at key moments |
| Flutter `SystemSound` | Built-in | Click sounds on UI interactions |

**Kotlin Version Note:** `flutter_tts 4.0.2` requires Kotlin `1.9.25`. Pinned in `android/settings.gradle.kts`:
```kotlin
id("org.jetbrains.kotlin.android") version "1.9.25" apply false
```

---

## 9. Networking & AI Services

### HTTP Client
| Package | Version | Usage |
|---|---|---|
| `http` | `^1.2.2` | REST calls to Groq, Jikan, Wikipedia, Cloudinary |

### AI Card Generation — Groq API
- **Endpoint:** `https://api.groq.com/openai/v1/chat/completions`
- **Model:** `llama-3.3-70b-versatile`
- **Key:** Injected at build time via `--dart-define=GROQ_API_KEY=gsk_...`
- **Free tier:** 14,400 requests/day · 30 RPM
- **Output:** JSON array of characters with `name`, `description`, `level`
- **Temperature:** 0.6 for generation; 0.2 for JSON normalisation

### Image Sources (AI Generation Pipeline)
| Source | Used For | Rate Limit |
|---|---|---|
| Jikan (MyAnimeList) | Anime franchise character images | 3 req/s (450ms delay applied) |
| Wikipedia API (`pageimages`) | Non-anime character images | None |
| DuckDuckGo | Fallback if Wikipedia fails | None |
| Cloudinary | Final CDN storage (upload on Save) | Account plan |

### Cloudinary
- Used only in the Admin panel.
- Raw preview images shown from Jikan/Wikipedia; Cloudinary upload happens only when the admin clicks Save.

---

## 10. Media

| Package | Version | Usage |
|---|---|---|
| `image_picker` | `^1.1.2` | Image selection in Admin panel (card image upload) |

---

## 11. Security & Utilities

| Package | Version | Usage |
|---|---|---|
| `crypto` | `^3.0.3` | SHA-256 password hashing utilities (not yet applied to room passwords — planned) |

---

## 12. Firestore Data Architecture

### Collections

```
profiles/{uid}                      ← Top-level (owned by AuthService)
      username, email, avatar_color,
      is_guest, created_at

fun_games/stats                     ← App stats document
      total_users, total_rooms,
      total_games_finished, updated_at

cards/{cardId}                      ← DraftClash card catalogue
      franchiseIds[], franchiseName,
      name, description, level,
      imageUrl, createdAt

franchises/{franchiseId}            ← Franchise catalogue
      name, imageUrl, cardCount, category, createdAt

tambola/app_data
  ├── rooms/{roomId}
  └── room_members/{memberId}

draftclash/app_data
  ├── rooms/{roomId}
  └── room_members/{memberId}
```

### DraftClash Room — What Is NOT Stored in Firestore
- `deck[]` — rebuilt locally from `deck_seed` by both clients.
- `total_score` — computed from board slots + `cardCache` in BLoC.

This minimises Firestore write costs and eliminates sync conflicts for computed values.

### Ticket Storage (Tambola)
- Stored as `int[30]` flat array (nested arrays are forbidden in Firestore).
- `0` = blank cell. `TicketGenerator.toJson()` / `fromJson()` handle serialization.

---

## 13. Android Build Config

| Setting | Value | Reason |
|---|---|---|
| `minSdk` | 23 | Required by `firebase-auth ^23` |
| `compileSdk` | Default Flutter | |
| `targetSdk` | Default Flutter | |
| Kotlin | 1.9.25 (pinned) | `flutter_tts 4.0.2` compatibility |
| Google Services Plugin | 4.4.3 | Firebase Android integration |

Key files:
- `android/app/google-services.json` — Firebase Android config
- `android/settings.gradle.kts` — Kotlin + Google Services plugin versions
- `android/app/build.gradle.kts` — `minSdk = 23`, Google Services plugin apply

---

## 14. Web Build Config

- `flutter run -d chrome` for development.
- `flutter build web --release` for production.
- Firebase initialized with `DefaultFirebaseOptions.web`.
- No special Web-specific packages beyond the standard Flutter Web embedding.

---

## 15. Project Structure

```
lib/
├── main.dart                    # Firebase init · AuthGate · MyApp
├── firebase_options.dart        # Platform-specific Firebase config
│
├── config/
│   └── app_theme.dart           # Dark theme · color tokens · Poppins text styles
│
├── blocs/
│   └── auth/                    # AuthBloc (delegates to AuthService)
│
├── screens/
│   ├── auth_screen.dart         # Login / Register / Guest
│   └── games_lobby_screen.dart  # Game selection hub
│
├── services/
│   ├── auth_service.dart        # Central auth + profiles logic
│   └── guest_service.dart       # Thin facade over AuthService
│
├── models/                      # Shared models (if any)
│
├── widgets/                     # Shared widgets (GameShell scaffold, etc.)
│
├── tambola/                     # Tambola module (self-contained)
│   ├── blocs/                   # RoomsBloc · GameBloc · CreateRoomBloc
│   ├── models/                  # Room · RoomMember · TicketModel
│   ├── screens/                 # RoomsScreen · GameScreen · SpectateScreen · FullscreenTicketScreen
│   ├── services/                # RoomService · TtsService
│   └── widgets/                 # TambolaTicketWidget · NumberBoardWidget
│
└── draftclash/                  # DraftClash module (self-contained)
    ├── blocs/                   # DraftLobbyBloc · DraftGameBloc
    ├── models/                  # DraftCard · DraftRoom · DraftMember · BoardSlot · DraftFranchise
    ├── screens/                 # DraftLobbyScreen · DraftGameScreen · AdminScreen · PassAndPlayScreen
    ├── services/                # DraftService · DraftSoundService · DeepSeekService · CloudinaryService · GeminiService
    ├── utils/                   # AdminTheme
    └── widgets/                 # DraftBoardWidget · DraftCardWidget
```

---

## 16. Development Workflow

```bash
# Install dependencies
flutter pub get

# Run on Android device
flutter run

# Run on Chrome (Web)
flutter run -d chrome

# Run with Groq API key for AI card generation
flutter run --dart-define=GROQ_API_KEY=gsk_...

# Release builds
flutter build apk --release
flutter build appbundle --release
flutter build web --release
```

---

## 17. Why Firebase Over Supabase

The original project used Supabase (PostgreSQL + Realtime WebSockets).

**Problem:** Jio (India's largest ISP) blocks WebSocket connections to `*.supabase.co`.

| | Supabase Realtime | Firestore `onSnapshot` |
|---|---|---|
| Domain | `*.supabase.co` — blocked by Jio ❌ | `*.googleapis.com` — works everywhere ✅ |
| Pricing | Free tier (limited) | Free tier generous for early-stage |
| Real-time | WebSocket | Long-polling / gRPC |
