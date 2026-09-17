// lib/draftclash/widgets/lobby/lobby_arena_screen.dart
//
// Separate "Live Arena" screen — shows all active + finished rooms.
// Search bar at the top filters by room code (6-digit or partial).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';
import '../../models/draft_room.dart';
import 'lobby_room_card.dart';
import 'lobby_live_dot.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _ink    = Color(0xFF050510);
const _dusk   = Color(0xFF0A091A);
const _raised = Color(0xFF14122A);
const _rim    = Color(0xFF1C1A35);
const _violet = Color(0xFF7B5CFA);
const _amber  = Color(0xFFF5A623);
const _teal   = Color(0xFF00D4AA);
const _green  = Color(0xFF3ADE80);
const _txtPri = Color(0xFFEEECFF);
const _txtSub = Color(0xFF7A78A8);

class LobbyArenaScreen extends StatefulWidget {
  final bool showBackButton;
  const LobbyArenaScreen({super.key, this.showBackButton = true});

  @override
  State<LobbyArenaScreen> createState() => _LobbyArenaScreenState();
}

class _LobbyArenaScreenState extends State<LobbyArenaScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  // Tab: 0 = Live, 1 = Finished
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim());
    });
    // Refresh rooms when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DraftLobbyBloc>().add(DraftLobbyLoadRequested());
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<DraftRoom> _filter(List<DraftRoom> rooms) {
    if (_query.isEmpty) return rooms;
    return rooms
        .where((r) => r.code.contains(_query) || r.roomName != null && r.roomName!.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DraftLobbyBloc, DraftLobbyState>(
      builder: (context, state) {
        final loaded    = state is DraftLobbyLoaded ? state : null;
        final isLoading = state is DraftLobbyLoading;
        final ongoing   = _filter(loaded?.ongoingRooms ?? []);
        final finished  = _filter(loaded?.finishedRooms ?? []);
        final myUid     = FirebaseAuth.instance.currentUser?.uid;

        return Scaffold(
          backgroundColor: _ink,
          body: Stack(
            children: [
              // Ambient glow
              Positioned(top: -30, right: -30,
                child: Container(width: 180, height: 180,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [_amber.withOpacity(0.08), Colors.transparent])))),
              Positioned(bottom: -40, left: -40,
                child: Container(width: 160, height: 160,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [_teal.withOpacity(0.06), Colors.transparent])))),

              SafeArea(
                child: Column(
                  children: [
                    // ── Top bar ───────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Row(children: [
                        if (widget.showBackButton)
                          _IconBtn(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.of(context).pop(),
                          )
                        else
                          const SizedBox(width: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (b) => const LinearGradient(
                                  colors: [_amber, Color(0xFFFF8C42)],
                                ).createShader(b),
                                child: const Text('LIVE ARENA',
                                    style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w900,
                                      letterSpacing: 2, color: Colors.white,
                                      decoration: TextDecoration.none)),
                              ),
                              Row(children: [
                                LobbyLiveDot(color: _amber),
                                const SizedBox(width: 5),
                                Text(
                                  loaded != null
                                      ? '${loaded.ongoingRooms.length} active · ${loaded.finishedRooms.length} finished'
                                      : 'Loading…',
                                  style: const TextStyle(fontSize: 11, color: _txtSub,
                                      decoration: TextDecoration.none),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        _IconBtn(
                          icon: Icons.refresh_rounded,
                          onTap: () => context.read<DraftLobbyBloc>().add(DraftLobbyLoadRequested()),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 14),

                    // ── Search bar ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SearchBar(
                        ctrl: _searchCtrl,
                        focus: _searchFocus,
                        onClear: () {
                          _searchCtrl.clear();
                          _searchFocus.unfocus();
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Tab bar ───────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ArenaTabs(ctrl: _tabCtrl),
                    ),

                    const SizedBox(height: 4),

                    // ── Tab content ───────────────────────────────────────
                    Expanded(
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: [
                          // Live tab
                          _RoomTab(
                            rooms: ongoing,
                            myUid: myUid,
                            isLoading: isLoading,
                            isFinished: false,
                            query: _query,
                            emptyIcon: Icons.sports_esports_outlined,
                            emptyTitle: _query.isNotEmpty ? 'No rooms match "$_query"' : 'No active games right now',
                            emptySubtitle: _query.isNotEmpty
                                ? 'Try a different room code'
                                : 'Create a room or wait for someone to start a game.',
                            onJoin: (id) => context.read<DraftLobbyBloc>().add(DraftLobbyJoinRequested(id)),
                            onRefresh: () => context.read<DraftLobbyBloc>().add(DraftLobbyLoadRequested()),
                          ),
                          // Finished tab
                          _RoomTab(
                            rooms: finished,
                            myUid: myUid,
                            isLoading: isLoading,
                            isFinished: true,
                            query: _query,
                            emptyIcon: Icons.flag_outlined,
                            emptyTitle: _query.isNotEmpty ? 'No rooms match "$_query"' : 'No finished games yet',
                            emptySubtitle: _query.isNotEmpty
                                ? 'Try a different room code'
                                : 'Completed drafts will appear here.',
                            onJoin: (_) {},
                            onRefresh: () => context.read<DraftLobbyBloc>().add(DraftLobbyLoadRequested()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final VoidCallback onClear;
  const _SearchBar({required this.ctrl, required this.focus, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _rim),
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        const Icon(Icons.search_rounded, color: _txtSub, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: ctrl,
            focusNode: focus,
            keyboardType: TextInputType.number,
            inputFormatters: [
              // Allow digits AND letters so room name search also works
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
            ],
            style: const TextStyle(
              color: _txtPri, fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              decoration: TextDecoration.none,
            ),
            decoration: InputDecoration(
              hintText: 'Search by room code…',
              hintStyle: TextStyle(
                color: _txtSub.withOpacity(0.5),
                fontSize: 13,
                fontWeight: FontWeight.normal,
                letterSpacing: 0.3,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (ctrl.text.isNotEmpty) ...[
          GestureDetector(
            onTap: onClear,
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _rim, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 12, color: _txtSub),
            ),
          ),
        ] else ...[
          const SizedBox(width: 14),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arena tab bar
// ─────────────────────────────────────────────────────────────────────────────

class _ArenaTabs extends StatelessWidget {
  final TabController ctrl;
  const _ArenaTabs({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: _raised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _rim),
      ),
      child: TabBar(
        controller: ctrl,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [Color(0xFFB07010), Color(0xFFF5A623)],
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: _txtSub,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              LobbyLiveDot(color: _amber),
              SizedBox(width: 6),
              Text('Live'),
            ]),
          ),
          Tab(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.flag_rounded, size: 13),
              SizedBox(width: 6),
              Text('Finished'),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Room list tab
// ─────────────────────────────────────────────────────────────────────────────

class _RoomTab extends StatelessWidget {
  final List<DraftRoom> rooms;
  final String? myUid;
  final bool isLoading;
  final bool isFinished;
  final String query;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final void Function(String) onJoin;
  final VoidCallback onRefresh;

  const _RoomTab({
    required this.rooms,
    required this.myUid,
    required this.isLoading,
    required this.isFinished,
    required this.query,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onJoin,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && rooms.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _violet, strokeWidth: 2.5),
      );
    }

    if (rooms.isEmpty) {
      return _EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: _violet,
      backgroundColor: _dusk,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: rooms.length,
        itemBuilder: (_, i) {
          final room = rooms[i];
          return LobbyRoomCard(
            room: room,
            isMyRoom: myUid != null && room.isHost(myUid!),
            onJoin: isFinished ? () {} : () => onJoin(room.id),
          ).animate(delay: Duration(milliseconds: 30 * i))
              .fadeIn(duration: 200.ms)
              .slideY(begin: 0.04, curve: Curves.easeOut);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _dusk, shape: BoxShape.circle,
              border: Border.all(color: _rim)),
            child: Icon(icon, color: _txtSub, size: 30),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold,
                color: _txtPri, decoration: TextDecoration.none)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12, color: _txtSub, height: 1.6,
                decoration: TextDecoration.none)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

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
