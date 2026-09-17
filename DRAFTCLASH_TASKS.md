# DRAFTCLASH_TASKS.md
# DraftClash — Implementation Task Tracker

> Status key: ✅ DONE · 🔲 TODO · ⚠️ PARTIAL

---

## Phase 1 — Project Structure & Models

| # | Task | Status | File(s) |
|---|------|--------|---------|
| 1.1 | Create `lib/draftclash/` folder hierarchy | ✅ | `lib/draftclash/` |
| 1.2 | `DraftCard` model with Firestore (de)serialisation | ✅ | `lib/draftclash/models/draft_card.dart` |
| 1.3 | `BoardSlot` enum — 6 roles (Captain, Vice Captain, Tank, Duelist, Support, Traitor) | ✅ | `lib/draftclash/models/draft_room.dart` |
| 1.4 | `DraftRoom` model with Firestore (de)serialisation | ✅ | `lib/draftclash/models/draft_room.dart` |
| 1.5 | `DraftMember` model with flat board fields | ✅ | `lib/draftclash/models/draft_room.dart` |

---

## Phase 2 — Firebase / Firestore

| # | Task | Status | File(s) |
|---|------|--------|---------|
| 2.1 | Define Firestore structure: `cards/`, `draftclash/app_data/rooms/`, `draftclash/app_data/room_members/` | ✅ | `lib/draftclash/services/draft_service.dart` |
| 2.2 | Card catalogue CRUD (getAllCards, addCard, watchCards) | ✅ | `lib/draftclash/services/draft_service.dart` |
| 2.3 | Room creation — auto-join creator as Player 1 | ✅ | `lib/draftclash/services/draft_service.dart` |
| 2.4 | Join room by 6-digit code — auto-start draft on 2nd join | ✅ | `lib/draftclash/services/draft_service.dart` |
| 2.5 | `assignCard` — place card in slot, update score via batch write | ✅ | `lib/draftclash/services/draft_service.dart` |
| 2.6 | `skipCard` — one-time skip per player | ✅ | `lib/draftclash/services/draft_service.dart` |
| 2.7 | `autoAssign` — timer-expired fallback assignment | ✅ | `lib/draftclash/services/draft_service.dart` |
| 2.8 | `_advanceTurn` — pop next card, switch turn, set deadline | ✅ | `lib/draftclash/services/draft_service.dart` |
| 2.9 | `checkAndFinaliseIfDone` — score both boards and mark winner | ✅ | `lib/draftclash/services/draft_service.dart` |
| 2.10 | Real-time subscriptions: `subscribeToRoom`, `subscribeToMembers` | ✅ | `lib/draftclash/services/draft_service.dart` |
| 2.11 | Seed 20 sample cards across Naruto, AoT, Dragon Ball Z, Marvel | ✅ | `lib/draftclash/services/draft_service.dart` |
| 2.12 | Apply Firestore security rules (see README below) | 🔲 | Firebase Console |

---

## Phase 3 — State Management (BLoC)

| # | Task | Status | File(s) |
|---|------|--------|---------|
| 3.1 | `DraftLobbyBloc` — Create / JoinByCode / WaitForOpponent / Cancel | ✅ | `lib/draftclash/blocs/lobby/` |
| 3.2 | `DraftLobbyState` — Idle / Loading / Waiting / Ready / Error | ✅ | `lib/draftclash/blocs/lobby/draft_lobby_state.dart` |
| 3.3 | `DraftLobbyEvent` — CreateRequested / JoinByCode / OpponentJoined / Cancel | ✅ | `lib/draftclash/blocs/lobby/draft_lobby_event.dart` |
| 3.4 | `DraftGameBloc` — Init / RoomUpdated / MembersUpdated / Countdown | ✅ | `lib/draftclash/blocs/game/draft_game_bloc.dart` |
| 3.5 | `DraftGameBloc` — CardAssigned / SkipRequested / AutoAssign | ✅ | `lib/draftclash/blocs/game/draft_game_bloc.dart` |
| 3.6 | `DraftGameState.cardCache` — full card catalogue cached at init | ✅ | `lib/draftclash/blocs/game/draft_game_state.dart` |
| 3.7 | Side-effect states: `DraftGameHapticFeedback`, `DraftGameShowResult` | ✅ | `lib/draftclash/blocs/game/draft_game_state.dart` |

---

## Phase 4 — UI Screens

| # | Task | Status | File(s) |
|---|------|--------|---------|
| 4.1 | `DraftLobbyScreen` — Hero card, Create button, JoinByCode input | ✅ | `lib/draftclash/screens/draft_lobby_screen.dart` |
| 4.2 | `DraftLobbyScreen` — Waiting state: animated code display + copy-to-clipboard | ✅ | `lib/draftclash/screens/draft_lobby_screen.dart` |
| 4.3 | `DraftGameScreen` — Dual-board layout (opponent top, card centre, my board bottom) | ✅ | `lib/draftclash/screens/draft_game_screen.dart` |
| 4.4 | `DraftGameScreen` — Card panel with countdown ring, current card, Skip button | ✅ | `lib/draftclash/screens/draft_game_screen.dart` |
| 4.5 | `DraftGameScreen` — Score header with turn indicator | ✅ | `lib/draftclash/screens/draft_game_screen.dart` |
| 4.6 | `DraftGameScreen` — Result overlay (Win / Lose / Draw) with final scores | ✅ | `lib/draftclash/screens/draft_game_screen.dart` |
| 4.7 | `DraftAdminScreen` — Manual card add form + level slider | ✅ | `lib/draftclash/screens/admin_screen.dart` |
| 4.8 | `DraftAdminScreen` — AI generation panel (placeholder pending Cloud Function) | ✅ | `lib/draftclash/screens/admin_screen.dart` |
| 4.9 | `DraftAdminScreen` — Card catalogue list with tier colouring | ✅ | `lib/draftclash/screens/admin_screen.dart` |
| 4.10 | `DraftAdminScreen` — Seed sample cards button | ✅ | `lib/draftclash/screens/admin_screen.dart` |

---

## Phase 5 — Widgets

| # | Task | Status | File(s) |
|---|------|--------|---------|
| 5.1 | `DraftBoardWidget` — 3×2 grid of `_SlotTile` widgets | ✅ | `lib/draftclash/widgets/draft_board_widget.dart` |
| 5.2 | `_SlotTile` — empty / interactive (pulse) / filled (tier colour + level badge) states | ✅ | `lib/draftclash/widgets/draft_board_widget.dart` |
| 5.3 | `DraftCardWidget` — full card (image, franchise badge, name, description, level bar) | ✅ | `lib/draftclash/widgets/draft_card_widget.dart` |
| 5.4 | `DraftCardWidget` — compact mode for board slot thumbnails | ✅ | `lib/draftclash/widgets/draft_card_widget.dart` |
| 5.5 | Tier colour system: Common (green) · Rare (blue) · Epic (purple) · Legendary (gold) | ✅ | `lib/draftclash/widgets/draft_card_widget.dart` |

---

## Phase 6 — Integration & Navigation

| # | Task | Status | File(s) |
|---|------|--------|---------|
| 6.1 | Add DraftClash tile to `GamesLobbyScreen` grid | ✅ | `lib/screens/games_lobby_screen.dart` |
| 6.2 | Add Admin menu item (email-gated) to avatar popup | ✅ | `lib/screens/games_lobby_screen.dart` |
| 6.3 | Fix: remove stale `draft_service.dart` import from `DraftGameScreen` | ✅ | `lib/draftclash/screens/draft_game_screen.dart` |
| 6.4 | Wire `DraftLobbyReady` state to push `DraftGameScreen` | ✅ | `lib/draftclash/screens/draft_lobby_screen.dart` |
| 6.5 | Wire `DraftLobbyWaiting` → Firestore subscription → auto-navigate on opponent join | ✅ | `lib/draftclash/blocs/lobby/draft_lobby_bloc.dart` |

---

## Phase 7 — AI Card Generation (Cloud Function)

> Requires a Firebase project with Cloud Functions enabled (Blaze plan).

| # | Task | Status | Notes |
|---|------|--------|-------|
| 7.1 | Set up `functions/` Node.js project in repo root | 🔲 | `firebase init functions` |
| 7.2 | Install deps: `firebase-admin`, `@google/generative-ai`, `axios` | 🔲 | `npm install` in `functions/` |
| 7.3 | Implement `generateFranchiseCards` HTTPS callable function | 🔲 | See template below |
| 7.4 | Call Gemini API to generate characters JSON for a given franchise | 🔲 | Use `gemini-1.5-flash` |
| 7.5 | Fetch portrait image URL per character (e.g. Google Custom Search or placeholder) | 🔲 | Store in Firestore `imageUrl` field |
| 7.6 | Write batch of generated cards to Firestore `/cards` collection | 🔲 | |
| 7.7 | Add Firebase Auth check: only admins can call the function | 🔲 | Check `context.auth.token.email` |
| 7.8 | Deploy: `firebase deploy --only functions` | 🔲 | |
| 7.9 | Uncomment Cloud Function call in `DraftAdminScreen._generateWithAI()` | 🔲 | `lib/draftclash/screens/admin_screen.dart` |

### Cloud Function template (`functions/index.js`):
```javascript
const { onCall } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { GoogleGenerativeAI } = require('@google/generative-ai');

initializeApp();

exports.generateFranchiseCards = onCall(async (request) => {
  // Auth guard
  if (!request.auth) throw new Error('Unauthenticated');

  const franchise = request.data.franchise;
  if (!franchise) throw new Error('franchise is required');

  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

  const prompt = `List the top 8 most iconic characters from "${franchise}".
Return ONLY a JSON array. Each object must have:
- name (string)
- description (string, max 2 sentences)
- level (integer 1-10, where 10 = most powerful)
No markdown, no extra text.`;

  const result = await model.generateContent(prompt);
  const text = result.response.text().replace(/```json|```/g, '').trim();
  const characters = JSON.parse(text);

  const db = getFirestore();
  const batch = db.batch();
  let count = 0;

  for (const char of characters) {
    const ref = db.collection('cards').doc();
    batch.set(ref, {
      franchise,
      name: char.name,
      description: char.description,
      level: Math.min(10, Math.max(1, parseInt(char.level) || 5)),
      imageUrl: '',  // Optionally integrate an image search API here
      createdAt: new Date(),
    });
    count++;
  }

  await batch.commit();
  return { cardsAdded: count, franchise };
});
```

---

## Phase 8 — Firestore Security Rules

Apply these rules in the Firebase Console → Firestore → Rules:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Card catalogue — anyone authenticated can read; only Cloud Functions write
    match /cards/{cardId} {
      allow read: if request.auth != null;
      allow write: if false; // managed by Cloud Functions + Admin SDK
    }

    // DraftClash game data
    match /draftclash/app_data {
      allow read, write: if request.auth != null;

      match /rooms/{roomId} {
        allow read: if request.auth != null;
        allow create: if request.auth != null;
        allow update: if request.auth != null &&
          (request.auth.uid == resource.data.player1_id ||
           request.auth.uid == resource.data.player2_id);
      }

      match /room_members/{memberId} {
        allow read: if request.auth != null;
        allow create: if request.auth != null;
        allow update: if request.auth != null &&
          request.auth.uid == resource.data.user_id;
      }
    }
  }
}
```

---

## Phase 9 — Polish & Future Enhancements

| # | Task | Status |
|---|------|--------|
| 9.1 | Card flip animation when a new card is drawn (using `flutter_animate` or Rive) | 🔲 |
| 9.2 | Network image loading with shimmer placeholder in `DraftCardWidget` | 🔲 |
| 9.3 | Confetti burst on win (reuse `confetti` package already in pubspec) | 🔲 |
| 9.4 | Push notification when opponent joins your waiting room | 🔲 |
| 9.5 | Rematch button on result screen | 🔲 |
| 9.6 | Match history screen per user | 🔲 |
| 9.7 | Room timeout — auto-cancel waiting rooms after 10 minutes | 🔲 |
| 9.8 | SHA-256 hash for admin check instead of email pattern | 🔲 |
| 9.9 | iOS build: register bundle ID in Firebase console | 🔲 |

---

## Quick-Start Checklist (Getting DraftClash Running)

1. **Seed cards** — Log in with an admin email (`*@admin.*`), go to Games Lobby → avatar menu → DraftClash Admin → tap **Seed Sample**. This adds 20 cards across 4 franchises.
2. **Firestore rules** — Apply Phase 8 rules in Firebase Console.
3. **Create a room** — Open DraftClash → Create Room. Share the 6-digit code.
4. **Join from another device** — Open DraftClash → Enter the code → draft begins automatically.
5. **AI generation** (optional) — Deploy the Cloud Function from Phase 7, then use the Admin → AI Generation panel.

---

*Last updated: $(date). Completed tasks: 28/37*
