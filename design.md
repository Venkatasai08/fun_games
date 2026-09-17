# FunGames — Design System

> **Last updated:** March 2026  
> **Theme:** Neon Noir — dark backgrounds, vibrant violet/pink/green accents, Poppins typography.

---

## 1. Color Palette

All colors defined in `lib/config/app_theme.dart` as `AppTheme` static constants.

### Core Colors

| Token | Hex | Usage |
|---|---|---|
| `primary` | `#6C63FF` | Buttons, active states, focus rings, icons |
| `primaryLight` | `#9C94FF` | Gradients, called-number cell highlights |
| `secondary` | `#FF6584` | Last-called number glow, LIVE card accent |
| `accent` | `#43E97B` | Winner badge, Housie button, "Create Account" CTA |
| `warning` | `#FFC107` | Lock icons, password indicators, guest notices |

### Background Colors

| Token | Hex | Usage |
|---|---|---|
| `bgDark` | `#0F0E1A` | Scaffold / screen background |
| `bgCard` | `#1A1830` | Card surfaces, dialogs, bottom sheets |
| `bgCardLight` | `#221F3A` | Input fields, pill backgrounds, secondary surfaces |

### Text & Border Colors

| Token | Hex | Usage |
|---|---|---|
| `textPrimary` | `#FFFFFF` | Headings, body text, labels |
| `textSecondary` | `#B0AECF` | Subtitles, placeholders, secondary metadata |
| `border` | `#2E2B50` | All dividers, container outlines |

### DraftClash Tier Colors

| Tier | Color | Hex | Level Range |
|---|---|---|---|
| COMMON | Green | `#4CAF50` | 1.0–3.4 |
| RARE | Blue | `#2196F3` | 3.5–5.9 |
| EPIC | Purple | `#9C27B0` | 6.0–7.9 |
| LEGENDARY | Gold | `#FF9800` / `#FFD700` | 8.0–9.4 |
| MYTHIC | Red/Gold gradient | `#FF5722` → `#FFD700` | 9.5–10.0 |

### Game Status Colors

| Status | Color | Hex |
|---|---|---|
| LIVE / Playing | `secondary` pink | `#FF6584` |
| WAITING | `primary` violet | `#6C63FF` |
| FINISHED / ENDED | Muted grey | System default |
| CANCELLED | Warning amber | `#FFC107` |

---

## 2. Typography

**Font:** Poppins (via `google_fonts` package). Applied globally through `AppTheme.darkTheme.textTheme`.

### Type Scale

| Style Token | Font Size | Weight | Color | Used For |
|---|---|---|---|---|
| `headlineLarge` | 28px | Bold (700) | `textPrimary` | Screen titles |
| `headlineMedium` | 22px | Bold (700) | `textPrimary` | Section headers |
| `titleLarge` | 18px | SemiBold (600) | `textPrimary` | Card titles, tab headers |
| `bodyLarge` | 16px | Regular (400) | `textPrimary` | Main body text |
| `bodyMedium` | 14px | Regular (400) | `textSecondary` | Subtitles, metadata |

### Extended Weight Usage

| Weight | Used For |
|---|---|
| 400 | Body text, descriptions |
| 600 | Labels, metadata chips, button text |
| 700 | Headings, section titles |
| 800–900 | Winner names, big score numbers, game result overlays |

### Letter Spacing
- App title ("FUN GAMES" splash): `letterSpacing: 5`
- Status badges and pill labels: uppercase with slight tracking

---

## 3. Spacing & Layout

### Border Radius

| Context | Radius |
|---|---|
| Room cards | `borderRadius: 20` with `ClipRRect` |
| Buttons | `12px` |
| Input fields | `12px` |
| Cards (Material) | `16px` |
| Pill chips / badges | `999px` (fully rounded) |
| Status badge | Rounded pill |

### Elevation
All cards use `elevation: 0` with border outlines instead of shadows — consistent with the flat Neon Noir aesthetic.

### Padding Conventions
- Screen horizontal padding: `16–24px`
- Card internal padding: `16px`
- Button padding: `24px horizontal · 14px vertical`
- Bottom sheet safe area: `SafeArea(top: false)` applied consistently

---

## 4. Component Library

### 4.1 Room Card (Tambola)

Structure:
- `borderRadius: 20`, `ClipRRect`
- **4px left accent bar** — gradient from status color to transparent (communicates game state at a glance)
- **Background gradient** — dark with subtle tint based on status
- **44px rounded-square host avatar** — colored circle with initial letter
- **Status badge pill** — "LIVE" with pulsing dot · "WAITING" · "ENDED" · "CANCELLED"
- **`_MiniPill` chips** — compact metadata: player count, number range, called count, auto-call interval, hint mode

### 4.2 Buttons

| Variant | Style |
|---|---|
| Primary (ElevatedButton) | `bgColor: primary (#6C63FF)`, white text, `radius: 12`, Poppins 600 |
| Accent CTA | `bgColor: accent (#43E97B)`, dark text |
| Destructive | `bgColor: secondary (#FF6584)` or system red |
| Text/Ghost | `TextButton` with `textSecondary` color |
| Icon button | `IconButton` with `AppTheme.primary` icon color |

### 4.3 Input Fields

- Filled style with `bgCardLight (#221F3A)` fill
- Border: `border (#2E2B50)` at rest; `primary (#6C63FF)` 2px on focus
- `radius: 12px`
- Label and hint color: `textSecondary (#B0AECF)`

### 4.4 Dialogs & Bottom Sheets

- Background: `bgCard (#1A1830)`
- `borderRadius: 20` on top corners for bottom sheets
- `SafeArea(top: false)` applied consistently to all bottom sheets across the project
- Divider color: `border (#2E2B50)`

### 4.5 SnackBars

- Background: `bgCardLight (#221F3A)`
- Text: Poppins, `textPrimary`
- Shape: `borderRadius: 12`, floating behavior

### 4.6 AppBar

- Background: `bgDark (#0F0E1A)`
- Elevation: 0
- Icon color: `textPrimary (#FFFFFF)`
- Title: Poppins 20px Bold

### 4.7 Tab Bar (3-Tab Shell)

Used in both Tambola (`RoomsScreen`) and DraftClash (`DraftLobbyScreen`):
- Bottom navigation with 3 tabs: **Home / Search / Create**
- Active tab: `primary (#6C63FF)`
- Inactive tab: `textSecondary (#B0AECF)`

### 4.8 Status Badge Pills

```
┌──────────────────┐
│  ● LIVE          │  — pulsing dot + pink background
│  WAITING         │  — violet background
│  ENDED           │  — muted grey
│  CANCELLED       │  — amber
└──────────────────┘
```

### 4.9 Loading States

- **Shimmer** (`shimmer` package): skeleton placeholders while Firestore data loads
- Color: transitions between `bgCard` and `bgCardLight`
- Used in room lists, card catalogues

### 4.10 Animations

- **`flutter_animate`**: entrance animations (fade + slide up) on cards and overlays
- **Confetti** (`confetti` package): winner celebration burst in Tambola
- **Pulsing dot**: CSS-style `AnimationController` loop on LIVE status badge

---

## 5. DraftClash Card Design

### Card Anatomy (Full Size)

```
┌─────────────────────────────┐
│  [Franchise badge]  [Level] │  ← Gradient overlay (bottom-to-top) for badge legibility
│                             │
│         [Image]             │
│                             │
│  Character Name             │
│  Description text...        │
│                             │
│  ████████░░  Level Bar      │  ← Color-coded by tier
└─────────────────────────────┘
```

- **Franchise badge**: pill chip, top-left corner, franchise name
- **Level badge**: colored circle, top-right corner, shows decimal level (e.g. "8.5")
- **Level bar**: horizontal progress bar, color matches tier
- **Bottom gradient overlay**: `LinearGradient` from transparent to `bgCard` — ensures badge text is always legible over busy images
- **Tier color coding**: border and accent elements color-match the card's tier

### Compact Mode (Board Slot Thumbnail)
- Smaller aspect ratio
- Shows only: franchise badge, character name, level badge
- No description text, no level bar
- Tier border highlight instead of full card

### Admin Card Grid Item
- No power bar displayed (removed in Mar 2026 refinement)
- Smaller grid cell size
- Bottom-to-top gradient overlay on image for badge legibility
- Shows: name, franchise, level badge, tier color

---

## 6. DraftClash Board Widget

6-slot grid (3×2 layout) of `_SlotTile` widgets:

| Slot State | Visual |
|---|---|
| Empty (my turn) | Pulsing purple border — indicates interactive |
| Empty (not my turn) | Dim grey border — non-interactive |
| Filled | Tier-colored border + compact card thumbnail |

Role labels: **Captain · Vice Captain · Tank · Duelist · Support · Traitor**

---

## 7. Navigation Flow & Screen Transitions

```
Splash Screen (bgDark + primary icon)
    │
AuthGate (StreamBuilder)
    │
    ├── AuthScreen
    │     Login / Register / Guest — card-based centered layout
    │
    └── GamesLobbyScreen
          Grid of game tiles (Tambola, DraftClash)
          │
          ├── Tambola → RoomsScreen (3-tab bottom nav)
          │     └── GameScreen
          │           └── SpectateScreen / FullscreenTicketScreen
          │
          └── DraftClash → DraftLobbyScreen (3-tab bottom nav)
                └── DraftGameScreen
```

**All game screen navigations** (from lobby tiles) currently show a "Coming Soon" `SnackBar` — actual navigation is behind the BLoC-driven lobby flow.

---

## 8. Iconography

- **Primary icon set:** Material Icons rounded (`Icons.*_rounded`)
- **Game icons:** `Icons.sports_esports_rounded` (platform), `Icons.grid_on_rounded` (Tambola), `Icons.swap_horiz_rounded` (DraftClash)
- **Status icons:** `Icons.lock_rounded` (password), `Icons.people_rounded` (players), `Icons.timer_rounded` (auto-call)
- **Admin icon:** `Icons.admin_panel_settings_rounded`

---

## 9. Splash Screen

- Background: `bgDark (#0F0E1A)`
- Center column:
  - `Icons.sports_esports_rounded` — 64px, `primary (#6C63FF)`
  - "FUN GAMES" — 26px, weight 900, `letterSpacing: 5`, white
  - `CircularProgressIndicator` — `primary (#6C63FF)` color

---

## 10. Design Principles

1. **Dark first** — `bgDark (#0F0E1A)` as the universal background. No light mode.
2. **State communicates through color** — every game state (LIVE/WAITING/ENDED/CANCELLED, tier rarity, turn ownership) has a distinct color.
3. **Elevation-free** — flat cards with border outlines instead of shadows; keeps the Neon Noir aesthetic clean.
4. **Poppins everywhere** — single font family, different weights to establish hierarchy.
5. **Status at a glance** — room cards reveal state (4px accent bar, status pill, mini-pill metadata) without opening the room.
6. **Safe areas respected** — `SafeArea(top: false)` applied consistently to bottom sheets; landscape override only for FullscreenTicketScreen.
7. **Shimmer on load** — never show empty or broken states; always show skeletons while data loads.
8. **Sound is opt-in** — TTS and haptics respect per-player toggles; never forced on users.
