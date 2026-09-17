// lib/draftclash/widgets/lobby/lobby_mode_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';
import '../../cubit/draft_catalog_cubit.dart';
import '../lobby/pass_and_play_sheet.dart';
import '../lobby/quick_match_sheet.dart';
import 'lobby_arena_screen.dart';
import 'lobby_friend_sheet.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _ink     = Color(0xFF050510);
const _dusk    = Color(0xFF0A091A);
const _rim     = Color(0xFF1C1A35);
const _violet  = Color(0xFF7B5CFA);
const _violetD = Color(0xFF4A1FCC);
const _amber   = Color(0xFFF5A623);
const _amberD  = Color(0xFFB86B00);
const _teal    = Color(0xFF00D4AA);
const _tealD   = Color(0xFF007A62);
const _green   = Color(0xFF3ADE80);
const _greenD  = Color(0xFF1A7A40);
const _red     = Color(0xFFFF4D6A);
const _redD    = Color(0xFF9A0020);
const _txtPri  = Color(0xFFEEECFF);
const _txtSub  = Color(0xFF7A78A8);

class LobbyModeScreen extends StatelessWidget {
  /// When non-null, the Live Arena tile calls this instead of pushing a route.
  final VoidCallback? onArenaTab;
  const LobbyModeScreen({super.key, this.onArenaTab});

  void _openQuickMatch(BuildContext ctx) {
    final bloc = ctx.read<DraftLobbyBloc>();
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const QuickMatchSheet(),
      ),
    );
  }

  void _openFriendSheet(BuildContext ctx, {int initialTab = 0}) {
    final bloc = ctx.read<DraftLobbyBloc>();
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: LobbyFriendSheet(initialTab: initialTab),
      ),
    );
  }

  void _openPassAndPlay(BuildContext ctx) {
    final bloc   = ctx.read<DraftLobbyBloc>();
    final cubit  = ctx.read<DraftCatalogCubit>();
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: BlocProvider.value(
          value: cubit,
          child: const PassAndPlaySheet(),
        ),
      ),
    );
  }

  void _openArena(BuildContext ctx) {
    if (onArenaTab != null) {
      onArenaTab!();
      return;
    }
    final bloc = ctx.read<DraftLobbyBloc>();
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const LobbyArenaScreen(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DraftLobbyBloc, DraftLobbyState>(
      listenWhen: (_, s) => s is DraftLobbyError,
      listener: (ctx, state) {
        if (state is DraftLobbyError) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text(state.message,
                style: const TextStyle(color: _txtPri, decoration: TextDecoration.none)),
            backgroundColor: const Color(0xFF1E0A2A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ));
        }
      },
      child: BlocBuilder<DraftLobbyBloc, DraftLobbyState>(
        builder: (context, state) {
          final isJoining = state is DraftLobbyJoinLoading;
          final loaded    = state is DraftLobbyLoaded ? state : null;
          final liveCount = loaded?.ongoingRooms.length ?? 0;

          return Scaffold(
            backgroundColor: _ink,
            body: Stack(
              children: [
                const Positioned.fill(child: _AmbientBg()),
                SafeArea(
                  child: Column(
                    children: [
                      _TopBar(
                        onBack: () => Navigator.of(context).pop(),
                        onRefresh: () => context
                            .read<DraftLobbyBloc>()
                            .add(DraftLobbyLoadRequested()),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Arena hero
                              const _ArenaHero()
                                  .animate()
                                  .fadeIn(duration: 500.ms)
                                  .slideY(begin: -0.04, curve: Curves.easeOut),

                              const SizedBox(height: 28),
                              const _SectionLabel('SELECT GAME MODE'),
                              const SizedBox(height: 14),

                              // ── 1. Quick Match ──────────────────────────
                              _QuickMatchTile(
                                isJoining: isJoining,
                                onTap: () => _openQuickMatch(context),
                              )
                                  .animate()
                                  .fadeIn(delay: 60.ms, duration: 400.ms)
                                  .slideX(begin: -0.04, curve: Curves.easeOut),

                              const SizedBox(height: 10),

                              // ── 2. Play with Friend ─────────────────────
                              _ModeTile(
                                icon: Icons.group_add_rounded,
                                title: 'Play with Friend',
                                subtitle: 'Create a room or join by code',
                                accent: _amber,
                                accentDark: _amberD,
                                glowColor: _amber,
                                tagLabel: 'ONLINE',
                                tagColor: _amber,
                                onTap: () => _openFriendSheet(context, initialTab: 0),
                                trailing: _IconOnlyBtn(
                                  icon: Icons.dialpad_rounded,
                                  color: _teal,
                                  tooltip: 'Join by code',
                                  onTap: () => _openFriendSheet(context, initialTab: 1),
                                ),
                              )
                                  .animate()
                                  .fadeIn(delay: 130.ms, duration: 400.ms)
                                  .slideX(begin: -0.04, curve: Curves.easeOut),

                              const SizedBox(height: 10),

                              // ── 3. Pass & Play ──────────────────────────
                              _ModeTile(
                                icon: Icons.smartphone_rounded,
                                title: 'Pass & Play',
                                subtitle: 'Two players, one phone — local turns',
                                accent: _green,
                                accentDark: _greenD,
                                glowColor: _green,
                                tagLabel: 'LOCAL',
                                tagColor: _green,
                                onTap: () => _openPassAndPlay(context),
                              )
                                  .animate()
                                  .fadeIn(delay: 200.ms, duration: 400.ms)
                                  .slideX(begin: -0.04, curve: Curves.easeOut),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ambient Background
// ─────────────────────────────────────────────────────────────────────────────

class _AmbientBg extends StatelessWidget {
  const _AmbientBg();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _AmbientPainter());
}

class _AmbientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final topGlow = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF7B5CFA).withOpacity(0.14), Colors.transparent],
      ).createShader(Rect.fromCenter(
          center: Offset(size.width * 0.72, size.height * 0.05),
          width: size.width * 1.2, height: size.width * 1.2));
    canvas.drawRect(Offset.zero & size, topGlow);

    final bottomGlow = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF00D4AA).withOpacity(0.07), Colors.transparent],
      ).createShader(Rect.fromCenter(
          center: Offset(size.width * 0.2, size.height * 0.9),
          width: size.width, height: size.width));
    canvas.drawRect(Offset.zero & size, bottomGlow);
  }
  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  const _TopBar({required this.onBack, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(children: [
        _IconBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
        const Spacer(),
        Column(children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFBBA4FF), _violet, Color(0xFF5EDFFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(b),
            child: const Text('DRAFT CLASH',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                    letterSpacing: 3, color: Colors.white,
                    decoration: TextDecoration.none)),
          ),
          const Text('1v1 Anime Character Draft',
              style: TextStyle(fontSize: 10, color: _txtSub,
                  letterSpacing: 0.3, decoration: TextDecoration.none)),
        ]),
        const Spacer(),
        _IconBtn(icon: Icons.refresh_rounded, onTap: onRefresh),
      ]),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _dusk, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _rim)),
        child: Icon(icon, size: 17, color: _txtSub),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arena Hero
// ─────────────────────────────────────────────────────────────────────────────

class _ArenaHero extends StatelessWidget {
  const _ArenaHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: _dusk, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _rim)),
      clipBehavior: Clip.hardEdge,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),
        Positioned(left: -20, top: -20,
          child: Container(width: 100, height: 100,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_violet.withOpacity(0.18), Colors.transparent])))),
        Positioned(right: -20, bottom: -20,
          child: Container(width: 100, height: 100,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_teal.withOpacity(0.14), Colors.transparent])))),
        Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _AvatarSlot(label: 'YOU', color: _violet, icon: Icons.person_rounded),
          const SizedBox(width: 16),
          _VsBadge(),
          const SizedBox(width: 16),
          _AvatarSlot(label: 'RIVAL', color: _teal,
              icon: Icons.person_outline_rounded, faded: true),
        ])),
      ]),
    );
  }
}

class _AvatarSlot extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool faded;
  const _AvatarSlot({required this.label, required this.color,
      required this.icon, this.faded = false});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(faded ? 0.06 : 0.12),
          border: Border.all(color: color.withOpacity(faded ? 0.25 : 0.55), width: 1.5),
          boxShadow: faded ? null
              : [BoxShadow(color: color.withOpacity(0.3), blurRadius: 14, spreadRadius: 1)],
        ),
        child: Icon(icon, size: 26, color: color.withOpacity(faded ? 0.35 : 0.9)),
      ),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(
        fontSize: 9, fontWeight: FontWeight.w800,
        color: color.withOpacity(faded ? 0.35 : 0.7),
        letterSpacing: 1.5, decoration: TextDecoration.none)),
    ]);
  }
}

class _VsBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF9B5CFF), Color(0xFF5E3DB3)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(
            color: _violet.withOpacity(0.55), blurRadius: 16, spreadRadius: 1)],
      ),
      child: const Center(child: Text('VS',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
              color: Colors.white, letterSpacing: 1,
              decoration: TextDecoration.none))),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1C1A35).withOpacity(0.6)
      ..strokeWidth = 0.5;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Match Tile
// ─────────────────────────────────────────────────────────────────────────────

class _QuickMatchTile extends StatelessWidget {
  final bool isJoining;
  final VoidCallback onTap;
  const _QuickMatchTile({required this.isJoining, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isJoining ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF221560), Color(0xFF0F0B2E)]),
          border: Border.all(color: _violet.withOpacity(0.4), width: 1.5),
          boxShadow: [BoxShadow(
              color: _violet.withOpacity(0.25), blurRadius: 24,
              offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(children: [
          Positioned(left: -10, top: -10,
            child: Container(width: 120, height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_violet.withOpacity(0.2), Colors.transparent])))),
          Positioned.fill(child: CustomPaint(painter: _ShineLinePainter(_violet))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(children: [
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _violet.withOpacity(0.15),
                  border: Border.all(color: _violet.withOpacity(0.5), width: 1.5),
                  boxShadow: [BoxShadow(
                      color: _violet.withOpacity(0.4), blurRadius: 18, spreadRadius: 1)]),
                child: isJoining
                    ? Padding(padding: const EdgeInsets.all(16),
                        child: CircularProgressIndicator(strokeWidth: 2, color: _violet))
                    : const Icon(Icons.bolt_rounded, color: _violet, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    const Text('Quick Match',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                            color: _txtPri, letterSpacing: 0.2,
                            decoration: TextDecoration.none)),
                    const SizedBox(width: 10),
                    _Tag('INSTANT', _violet),
                  ]),
                  const SizedBox(height: 5),
                  const Text('Spin a series · instantly match a random player',
                      style: TextStyle(fontSize: 12, color: _txtSub,
                          height: 1.4, decoration: TextDecoration.none)),
                ],
              )),
              const SizedBox(width: 10),
              Container(width: 30, height: 30,
                decoration: BoxDecoration(
                  color: _violet.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _violet.withOpacity(0.3))),
                child: Icon(Icons.arrow_forward_rounded, size: 15,
                    color: _violet.withOpacity(0.8))),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic Mode Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color accentDark;
  final Color glowColor;
  final String tagLabel;
  final Color tagColor;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.accentDark,
    required this.glowColor,
    required this.tagLabel,
    required this.tagColor,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _dusk, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(
              color: glowColor.withOpacity(0.1), blurRadius: 20,
              offset: const Offset(0, 6))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(children: [
          Positioned(top: 0, left: 0, right: 0,
            child: Container(height: 2,
              decoration: BoxDecoration(gradient: LinearGradient(
                colors: [accent, accent.withOpacity(0)])))),
          Positioned(right: -20, top: -20,
            child: Container(width: 90, height: 90,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [accent.withOpacity(0.1), Colors.transparent])))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: accent.withOpacity(0.1),
                    border: Border.all(color: accent.withOpacity(0.4), width: 1.5)),
                  child: Icon(icon, color: accent, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(title,
                              overflow: TextOverflow.ellipsis, maxLines: 1,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800,
                                  color: _txtPri, decoration: TextDecoration.none)),
                        ),
                        const SizedBox(width: 8),
                        _Tag(tagLabel, tagColor),
                      ]),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          overflow: TextOverflow.ellipsis, maxLines: 2,
                          style: const TextStyle(
                              fontSize: 12, color: _txtSub, height: 1.4,
                              decoration: TextDecoration.none)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
                Container(width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withOpacity(0.3))),
                  child: Icon(Icons.arrow_forward_rounded, size: 15,
                      color: accent.withOpacity(0.8))),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Icon-only button (fixed 32×32)
// ─────────────────────────────────────────────────────────────────────────────

class _IconOnlyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _IconOnlyBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.45)),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _ShineLinePainter extends CustomPainter {
  final Color color;
  const _ShineLinePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(0.05)..strokeWidth = 1;
    for (int i = 0; i < 6; i++) {
      final x = size.width * 0.15 * i;
      canvas.drawLine(Offset(x, 0), Offset(x + size.height * 0.6, size.height), paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35), width: 1)),
      child: Text(label, style: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w800,
          color: color, letterSpacing: 1, decoration: TextDecoration.none)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 12,
          decoration: BoxDecoration(color: _violet,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(
          fontSize: 10.5, fontWeight: FontWeight.w700,
          color: _txtSub, letterSpacing: 1.6, decoration: TextDecoration.none)),
    ]);
  }
}
