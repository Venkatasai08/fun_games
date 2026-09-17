// lib/cardroomgame/screens/card_rooms_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_theme.dart';
import '../blocs/rooms/card_rooms_bloc.dart';
import '../blocs/create_room/create_card_room_bloc.dart';
import '../models/card_room_model.dart';
import 'card_game_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CardRoomsScreen  –  Lobby with 3-tab bottom nav (Home | Search | Create)
// ─────────────────────────────────────────────────────────────────────────────

class CardRoomsScreen extends StatelessWidget {
  const CardRoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CardRoomsBloc, CardRoomsState>(
      listenWhen: (_, s) =>
          s is CardRoomsJoinSuccess || s is CardRoomsJoinFailure,
      listener: (context, state) {
        if (state is CardRoomsJoinSuccess) {
          context.read<CardRoomsBloc>().add(CardRoomsLoadRequested());
          _pushGame(context, state.roomId);
        }
        if (state is CardRoomsJoinFailure) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
          ));
        }
      },
      builder: (context, state) {
        final navIndex = state is CardRoomsLoaded
            ? state.navIndex
            : state is CardRoomsJoinLoading
                ? state.navIndex
                : (state is CardRoomsSearchLoading ||
                        state is CardRoomsSearchResult)
                    ? 1
                    : 0;

        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: IndexedStack(
            index: navIndex,
            children: const [
              _HomeTab(),
              _SearchTab(),
              _CreateTab(),
            ],
          ),
          bottomNavigationBar: _BottomNav(
            currentIndex: navIndex,
            onTap: (i) =>
                context.read<CardRoomsBloc>().add(CardRoomsNavChanged(i)),
          ),
        );
      },
    );
  }

  void _pushGame(BuildContext context, String roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CardGameScreen(roomId: roomId)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Nav
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: const Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Rooms',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.search_outlined,
                activeIcon: Icons.search_rounded,
                label: 'Search',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              // Create button (pill style)
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap(2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFE94560), Color(0xFFFF8C69)]),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE94560).withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(height: 4),
                      const Text('Create',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFE94560),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon,
                size: 24,
                color:
                    isActive ? AppTheme.primary : AppTheme.textSecondary),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                  fontWeight:
                      isActive ? FontWeight.bold : FontWeight.normal,
                )),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 3,
              width: isActive ? 20 : 0,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home Tab  –  Live & Finished room lists
// ─────────────────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CardRoomsBloc, CardRoomsState>(
      builder: (context, state) {
        final loaded = state is CardRoomsLoaded
            ? state
            : state is CardRoomsJoinLoading
                ? CardRoomsLoaded(
                    rooms: state.rooms,
                    tabIndex: state.tabIndex,
                    navIndex: state.navIndex)
                : null;

        final tabIndex = loaded?.tabIndex ?? 0;
        final ongoing = loaded?.ongoingRooms ?? [];
        final finished = loaded?.finishedRooms ?? [];
        final isLoading = state is CardRoomsLoading;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F0E1A), Color(0xFF1A1040), Color(0xFF0F0E1A)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildTabs(context, tabIndex),
                Expanded(
                  child: isLoading && loaded == null
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primary))
                      : RefreshIndicator(
                          onRefresh: () async => context
                              .read<CardRoomsBloc>()
                              .add(CardRoomsLoadRequested()),
                          color: AppTheme.primary,
                          child: tabIndex == 0
                              ? _buildList(context, ongoing,
                                  emptyMsg: 'No active rooms. Create one!')
                              : _buildList(context, finished,
                                  emptyMsg: 'No finished games yet.'),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFE94560), Color(0xFFFF8C69)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.style_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CARD ROOM',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: Colors.white)),
              Text('Live Rooms',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () =>
                context.read<CardRoomsBloc>().add(CardRoomsLoadRequested()),
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context, int current) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          _tabBtn(context, 'Active', 0, Icons.play_circle_outline, current),
          _tabBtn(context, 'Finished', 1, Icons.flag_outlined, current),
        ]),
      ),
    );
  }

  Widget _tabBtn(BuildContext context, String label, int idx, IconData icon,
      int current) {
    final sel = current == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            context.read<CardRoomsBloc>().add(CardRoomsTabChanged(idx)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: sel
                ? const LinearGradient(
                    colors: [Color(0xFFE94560), Color(0xFFFF8C69)])
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 16,
                color: sel ? Colors.white : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: sel ? Colors.white : AppTheme.textSecondary,
                  fontWeight:
                      sel ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                )),
          ]),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<CardRoom> rooms,
      {required String emptyMsg}) {
    if (rooms.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        Column(children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(Icons.style_outlined,
                size: 44, color: AppTheme.textSecondary),
          ).animate().scale(curve: Curves.elasticOut),
          const SizedBox(height: 16),
          Text(emptyMsg,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ]);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: rooms.length,
      itemBuilder: (ctx, i) {
        final room = rooms[i];
        return _RoomCard(
          room: room,
          onJoin: () => context
              .read<CardRoomsBloc>()
              .add(CardRoomsJoinRequested(room.id)),
        )
            .animate(key: ValueKey(room.id))
            .fadeIn(duration: 220.ms)
            .slideX(begin: 0.04);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search Tab
// ─────────────────────────────────────────────────────────────────────────────

class _SearchTab extends StatefulWidget {
  const _SearchTab();

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CardRoomsBloc, CardRoomsState>(
      builder: (context, state) {
        final isSearching = state is CardRoomsSearchLoading;
        final result =
            state is CardRoomsSearchResult ? state : null;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Join by Code',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Enter the 6-digit room code',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      onSubmitted: (_) => _search(context),
                      decoration: const InputDecoration(
                        labelText: 'Room Code',
                        hintText: '123456',
                        prefixIcon: Icon(Icons.tag_rounded),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSearching ? null : () => _search(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE94560)),
                      child: isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Search'),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                if (result != null)
                  result.error != null
                      ? Center(
                          child: Text(result.error!,
                              style: const TextStyle(color: Colors.red)))
                      : result.room != null
                          ? _RoomCard(
                              room: result.room!,
                              onJoin: () => context
                                  .read<CardRoomsBloc>()
                                  .add(CardRoomsJoinRequested(
                                      result.room!.id)),
                            ).animate().fadeIn().slideY(begin: 0.1)
                          : const SizedBox.shrink(),
              ],
            ),
          ),
        );
      },
    );
  }

  void _search(BuildContext context) {
    context
        .read<CardRoomsBloc>()
        .add(CardRoomsSearchByCode(_ctrl.text));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Tab
// ─────────────────────────────────────────────────────────────────────────────

class _CreateTab extends StatefulWidget {
  const _CreateTab();

  @override
  State<_CreateTab> createState() => _CreateTabState();
}

class _CreateTabState extends State<_CreateTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateCardRoomBloc, CreateCardRoomState>(
      listener: (context, state) {
        if (state is CreateCardRoomSuccess) {
          context.read<CreateCardRoomBloc>().add(CreateCardRoomReset());
          context
              .read<CardRoomsBloc>()
              .add(const CardRoomsNavChanged(0));
          context
              .read<CardRoomsBloc>()
              .add(CardRoomsLoadRequested());
          _nameCtrl.clear();
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CardGameScreen(roomId: state.roomId)),
          );
        }
        if (state is CreateCardRoomFailure) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
          ));
          context.read<CreateCardRoomBloc>().add(CreateCardRoomReset());
        }
      },
      builder: (context, state) {
        final s = state is CreateCardRoomInitial
            ? state
            : const CreateCardRoomInitial();
        final isLoading = state is CreateCardRoomLoading;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create Room',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Set up your card game session',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 24),

                  // ── Room name ───────────────────────────────────────────
                  _section('Room Details', Icons.meeting_room_outlined, [
                    TextFormField(
                      controller: _nameCtrl,
                      onChanged: (v) => context
                          .read<CreateCardRoomBloc>()
                          .add(CreateCardRoomNameChanged(v)),
                      decoration: const InputDecoration(
                        labelText: 'Room Name',
                        hintText: 'e.g. Family Cards Night',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Room name is required';
                        if (v.trim().length < 3) return 'Min 3 characters';
                        return null;
                      },
                    ),
                  ]).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1),
                  const SizedBox(height: 16),

                  // ── Max players ─────────────────────────────────────────
                  _section('Number of Players', Icons.people_outline, [
                    Row(children: [
                      const Text('Max players',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      const Spacer(),
                      for (final n in [2, 3, 4, 5, 6])
                        GestureDetector(
                          onTap: () => context
                              .read<CreateCardRoomBloc>()
                              .add(CreateCardRoomMaxPlayersChanged(n)),
                          child: AnimatedContainer(
                            duration: 180.ms,
                            margin: const EdgeInsets.only(left: 8),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: s.maxPlayers == n
                                  ? const Color(0xFFE94560)
                                  : AppTheme.bgCardLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: s.maxPlayers == n
                                      ? const Color(0xFFE94560)
                                      : AppTheme.border),
                            ),
                            child: Center(
                              child: Text('$n',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: s.maxPlayers == n
                                          ? Colors.white
                                          : AppTheme.textSecondary)),
                            ),
                          ),
                        ),
                    ]),
                  ]).animate().fadeIn(delay: 140.ms).slideY(begin: 0.1),
                  const SizedBox(height: 16),

                  // ── Cards per player ────────────────────────────────────
                  _section('Cards per Player', Icons.style_outlined, [
                    Row(children: [
                      const Text('Cards dealt',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      const Spacer(),
                      for (final n in [5, 7, 10, 13])
                        GestureDetector(
                          onTap: () => context
                              .read<CreateCardRoomBloc>()
                              .add(CreateCardRoomCardsPerPlayerChanged(n)),
                          child: AnimatedContainer(
                            duration: 180.ms,
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: s.cardsPerPlayer == n
                                  ? const Color(0xFFE94560)
                                  : AppTheme.bgCardLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: s.cardsPerPlayer == n
                                      ? const Color(0xFFE94560)
                                      : AppTheme.border),
                            ),
                            child: Text('$n',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: s.cardsPerPlayer == n
                                        ? Colors.white
                                        : AppTheme.textSecondary)),
                          ),
                        ),
                    ]),
                  ]).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                  const SizedBox(height: 16),

                  // ── Host mode ───────────────────────────────────────────
                  _section('Host Mode', Icons.manage_accounts_outlined, [
                    Row(children: [
                      _hostModeCard(
                        context,
                        mode: HostMode.player,
                        current: s.hostMode,
                        icon: Icons.sports_esports_rounded,
                        label: 'Play',
                        subtitle: 'Host plays with cards',
                      ),
                      const SizedBox(width: 12),
                      _hostModeCard(
                        context,
                        mode: HostMode.spectator,
                        current: s.hostMode,
                        icon: Icons.visibility_rounded,
                        label: 'Spectate',
                        subtitle: 'Host watches & controls',
                      ),
                    ]),
                  ]).animate().fadeIn(delay: 260.ms).slideY(begin: 0.1),
                  const SizedBox(height: 28),

                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                context
                                    .read<CreateCardRoomBloc>()
                                    .add(CreateCardRoomSubmitted());
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE94560),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.rocket_launch, size: 20),
                                SizedBox(width: 8),
                                Text('Create Room',
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                  ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.1),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _hostModeCard(BuildContext context,
      {required HostMode mode,
      required HostMode current,
      required IconData icon,
      required String label,
      required String subtitle}) {
    final sel = current == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => context
            .read<CreateCardRoomBloc>()
            .add(CreateCardRoomHostModeChanged(mode)),
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sel
                ? const Color(0xFFE94560).withOpacity(0.12)
                : AppTheme.bgDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel
                    ? const Color(0xFFE94560)
                    : AppTheme.border,
                width: sel ? 2 : 1),
          ),
          child: Column(children: [
            Icon(icon,
                color: sel
                    ? const Color(0xFFE94560)
                    : AppTheme.textSecondary,
                size: 24),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: sel
                        ? const Color(0xFFE94560)
                        : AppTheme.textPrimary)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  Widget _section(
      String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Icon(icon, color: const Color(0xFFE94560), size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Room Card
// ─────────────────────────────────────────────────────────────────────────────

class _RoomCard extends StatelessWidget {
  final CardRoom room;
  final VoidCallback onJoin;

  const _RoomCard({required this.room, required this.onJoin});

  Color get _accentColor {
    if (room.isPlaying) return const Color(0xFF43E97B);
    if (room.isWaiting) return const Color(0xFFE94560);
    if (room.isFinished) return const Color(0xFFFFD700);
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    final isMyRoom = room.hostId == myId;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: _accentColor.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
              color: _accentColor.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 5))
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_accentColor, _accentColor.withOpacity(0.1)],
                ),
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18)),
              ),
            ),
            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  // Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _accentColor.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Text(
                        room.hostUsername.isNotEmpty
                            ? room.hostUsername[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _accentColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(room.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(room.hostUsername,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary)),
                        const SizedBox(height: 5),
                        Wrap(spacing: 5, children: [
                          _tag('${room.memberCount}/${room.maxPlayers}',
                              Icons.people_outline),
                          _tag('${room.cardsPerPlayer} cards',
                              Icons.style_outlined),
                          _tag(
                              room.hostMode == HostMode.spectator
                                  ? 'Host: Spectator'
                                  : 'Host: Player',
                              Icons.manage_accounts_outlined),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Action
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _statusPill(),
                      const SizedBox(height: 8),
                      if (!room.isFinished && !room.isCancelled)
                        _actionButton(isMyRoom),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill() {
    String label;
    if (room.isPlaying) label = 'LIVE';
    else if (room.isWaiting) label = 'WAITING';
    else if (room.isFinished) label = 'ENDED';
    else label = 'CANCELLED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: _accentColor,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0)),
    );
  }

  Widget _actionButton(bool isMyRoom) {
    final label = isMyRoom ? 'Open' : 'Join';
    return GestureDetector(
      onTap: onJoin,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFE94560), Color(0xFFFF8C69)]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFE94560).withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
    );
  }

  Widget _tag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: AppTheme.textSecondary),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
