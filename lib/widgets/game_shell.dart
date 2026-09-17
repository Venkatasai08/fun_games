// lib/widgets/game_shell.dart
//
// ─────────────────────────────────────────────────────────────────────────────
// GameShell — Shared game screen scaffold used by every game module.
//
// Usage:
//
//   GameShell(
//     isLoading: state is Loading,
//     loadingMessage: 'Joining game…',
//     errorMessage: state is Error ? state.message : null,
//     topBar: MyGameTopBar(…),
//     bottomBar: MyNumberBoardBar(…),           // optional
//     overlay: state is Finished ? ResultWidget() : null,  // optional
//     body: MyGameContent(…),
//   )
//
// The shell owns:
//   • Scaffold + background colour
//   • SafeArea (top only; games own bottom-safe insets via their bottomBar)
//   • Loading screen  (CircularProgressIndicator + message)
//   • Error screen    (icon + message + back button)
//   • Column structure: topBar → Expanded(body) → bottomBar
//   • Full-screen overlay stacked above everything (results, winners, etc.)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../config/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GameShell
// ─────────────────────────────────────────────────────────────────────────────

class GameShell extends StatelessWidget {
  /// Show the full-screen loading state instead of [body].
  final bool isLoading;

  /// Message shown below the spinner. Defaults to "Loading…".
  final String loadingMessage;

  /// When non-null, show the error screen instead of [body].
  final String? errorMessage;

  /// Called when the user taps "Go Back" on the error screen.
  /// Defaults to [Navigator.pop] when null.
  final VoidCallback? onErrorBack;

  /// Scaffold/body background colour. Defaults to [AppTheme.bgDark].
  final Color? backgroundColor;

  /// The top bar widget (sits above [body], below the system status bar).
  /// Required — every game must provide a top bar.
  final Widget topBar;

  /// The main scrollable content area. Shown when not loading / no error.
  final Widget body;

  /// Optional sticky bar at the bottom of the screen (above system nav).
  final Widget? bottomBar;

  /// Optional full-screen overlay stacked above the entire scaffold
  /// (result screens, winner banners, etc.).
  final Widget? overlay;

  const GameShell({
    super.key,
    this.isLoading = false,
    this.loadingMessage = 'Loading…',
    this.errorMessage,
    this.onErrorBack,
    this.backgroundColor,
    required this.topBar,
    required this.body,
    this.bottomBar,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppTheme.bgDark;

    // ── Loading screen ────────────────────────────────────────────────────
    if (isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Center(
            child: GameShellLoadingView(message: loadingMessage),
          ),
        ),
      );
    }

    // ── Error screen ──────────────────────────────────────────────────────
    if (errorMessage != null) {
      return GameShellErrorScreen(
        message: errorMessage!,
        backgroundColor: bg,
        onBack: onErrorBack ?? () => Navigator.of(context).pop(),
      );
    }

    // ── Normal game screen ────────────────────────────────────────────────
    final scaffold = Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: bottomBar == null, // let bottomBar control its own safe-area
        child: Column(
          children: [
            topBar,
            Expanded(child: body),
            if (bottomBar != null)
              SafeArea(
                top: false,
                child: bottomBar!,
              ),
          ],
        ),
      ),
    );

    if (overlay == null) return scaffold;

    return Stack(
      children: [
        scaffold,
        overlay!,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GameShellTopBar
//
// A ready-made top bar that follows the Neon Noir design language.
// Games can either use this directly or build their own.
//
//  ┌───────────────────────────────────────────────────────────┐
//  │  [◀]   Title                  [trailing widgets…]        │
//  │         Subtitle (optional)                               │
//  └───────────────────────────────────────────────────────────┘
// ─────────────────────────────────────────────────────────────────────────────

class GameShellTopBar extends StatelessWidget {
  /// Main title (room name, game name, etc.).
  final String title;

  /// Secondary line below the title (player count, room code, etc.).
  final String? subtitle;

  /// Widgets placed to the right of the title (status badges, icon buttons).
  final List<Widget> trailing;

  /// Called when the back arrow is tapped. Defaults to [Navigator.pop].
  final VoidCallback? onBack;

  /// Pad between the back button and the title area.
  final double leadingGap;

  const GameShellTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing = const [],
    this.onBack,
    this.leadingGap = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          // ── Back button ────────────────────────────────────────────────
          _BackButton(onTap: onBack ?? () => Navigator.of(context).pop()),
          SizedBox(width: leadingGap),

          // ── Title + subtitle ───────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Trailing actions ───────────────────────────────────────────
          if (trailing.isNotEmpty) ...[
            const SizedBox(width: 8),
            ...trailing.map((w) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: w,
                )),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GameShellStatusBadge
//
// A standardised pill badge (LIVE · WAITING · ENDED · CANCELLED).
// Used inside [GameShellTopBar]'s trailing list.
// ─────────────────────────────────────────────────────────────────────────────

class GameShellStatusBadge extends StatelessWidget {
  final String status;

  /// Override label text. If null, a sensible default is used per status.
  final String? label;

  const GameShellStatusBadge({
    super.key,
    required this.status,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final (Color color, String text) = switch (status.toLowerCase()) {
      'playing'   => (AppTheme.secondary, '● LIVE'),
      'finished'  => (AppTheme.textSecondary, 'ENDED'),
      'cancelled' => (Colors.red, 'CANCELLED'),
      _           => (AppTheme.accent, 'WAITING'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label ?? text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GameShellIconPill
//
// Small pill with an icon + text label — e.g. player count, sound toggle.
// Used inside [GameShellTopBar]'s trailing list.
// ─────────────────────────────────────────────────────────────────────────────

class GameShellIconPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? activeColor;
  final VoidCallback? onTap;

  const GameShellIconPill({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? (activeColor ?? AppTheme.primary) : AppTheme.textSecondary;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.15) : AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? color.withOpacity(0.55) : AppTheme.border,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ]),
    );

    if (onTap == null) return pill;
    return GestureDetector(onTap: onTap, child: pill);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GameShellLoadingView
//
// Inline loading widget — can be used standalone or embedded by GameShell.
// ─────────────────────────────────────────────────────────────────────────────

class GameShellLoadingView extends StatelessWidget {
  final String message;

  const GameShellLoadingView({
    super.key,
    this.message = 'Loading…',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border),
          ),
          child: const Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GameShellErrorScreen
//
// Full-screen error shown when the BLoC emits an unrecoverable error.
// ─────────────────────────────────────────────────────────────────────────────

class GameShellErrorScreen extends StatelessWidget {
  final String message;
  final Color? backgroundColor;
  final VoidCallback? onBack;

  const GameShellErrorScreen({
    super.key,
    required this.message,
    this.backgroundColor,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppTheme.bgDark,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.withOpacity(0.35)),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: onBack ?? () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.bgCard,
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BackButton  (private helper)
// ─────────────────────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppTheme.textSecondary,
          size: 16,
        ),
      ),
    );
  }
}
