// lib/draftclash/widgets/lobby/lobby_shell.dart
//
// DraftClashLobbyShell — wraps Home + Live Arena in a persistent bottom nav.
//
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';
import 'lobby_mode_screen.dart';
import 'lobby_arena_screen.dart';
import 'lobby_live_dot.dart';

// ── Palette (matches lobby screens) ──────────────────────────────────────────
const _ink    = Color(0xFF050510);
const _dusk   = Color(0xFF0A091A);
const _rim    = Color(0xFF1C1A35);
const _violet = Color(0xFF7B5CFA);
const _amber  = Color(0xFFF5A623);
const _txtSub = Color(0xFF7A78A8);
const _txtPri = Color(0xFFEEECFF);

class DraftClashLobbyShell extends StatefulWidget {
  const DraftClashLobbyShell({super.key});

  @override
  State<DraftClashLobbyShell> createState() => _DraftClashLobbyShellState();
}

class _DraftClashLobbyShellState extends State<DraftClashLobbyShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  void _switchTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final state    = context.watch<DraftLobbyBloc>().state;
    final loaded   = state is DraftLobbyLoaded ? state : null;
    final liveCount = loaded?.ongoingRooms.length ?? 0;

    return Scaffold(
      backgroundColor: _ink,
      // ── Body: IndexedStack keeps both screens alive ──────────────────
      body: IndexedStack(
        index: _index,
        children: [
          // Tab 0 — Home
          LobbyModeScreen(onArenaTab: () => _switchTab(1)),
          // Tab 1 — Live Arena (no back button; nav is via bottom bar)
          const LobbyArenaScreen(showBackButton: false),
        ],
      ),

      // ── Bottom nav ───────────────────────────────────────────────────
      bottomNavigationBar: _LobbyBottomNav(
        selectedIndex: _index,
        liveCount: liveCount,
        onTap: _switchTab,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Nav Bar
// ─────────────────────────────────────────────────────────────────────────────

class _LobbyBottomNav extends StatelessWidget {
  final int selectedIndex;
  final int liveCount;
  final ValueChanged<int> onTap;
  const _LobbyBottomNav({
    required this.selectedIndex,
    required this.liveCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _dusk,
        border: Border(top: BorderSide(color: _rim, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _NavItem(
              index: 0,
              selected: selectedIndex == 0,
              icon: Icons.home_rounded,
              iconOutlined: Icons.home_outlined,
              label: 'Home',
              activeColor: _violet,
              onTap: onTap,
            ),
            _NavItem(
              index: 1,
              selected: selectedIndex == 1,
              icon: Icons.sports_esports_rounded,
              iconOutlined: Icons.sports_esports_outlined,
              label: 'Live Arena',
              activeColor: _amber,
              liveCount: liveCount,
              onTap: onTap,
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual nav item
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final int index;
  final bool selected;
  final IconData icon;
  final IconData iconOutlined;
  final String label;
  final Color activeColor;
  final int liveCount;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.selected,
    required this.icon,
    required this.iconOutlined,
    required this.label,
    required this.activeColor,
    required this.onTap,
    this.liveCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? activeColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? activeColor.withOpacity(0.35) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon + live badge stack
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      selected ? icon : iconOutlined,
                      key: ValueKey(selected),
                      size: 22,
                      color: selected ? activeColor : _txtSub,
                    ),
                  ),
                  // Live count badge for arena tab
                  if (liveCount > 0 && !selected)
                    Positioned(
                      top: -4,
                      right: -8,
                      child: _PulsingDot(color: activeColor),
                    ),
                  if (liveCount > 0 && selected)
                    Positioned(
                      top: -4,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$liveCount',
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.normal,
                  color: selected ? activeColor : _txtSub,
                  decoration: TextDecoration.none,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing dot badge (when not selected but live games exist)
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _scale = Tween(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.6),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
