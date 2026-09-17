// lib/tambola/screens/rooms_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../models/room.dart';
import '../blocs/rooms/rooms_bloc.dart';
import '../blocs/create_room/create_room_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../screens/auth_screen.dart';
import 'spectate_screen.dart';
import 'game_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared "coming soon" snackbar helper
// ─────────────────────────────────────────────────────────────────────────────

void _showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Row(children: [
        Icon(Icons.construction_rounded, color: Colors.white, size: 18),
        SizedBox(width: 10),
        Text('Game screen coming soon!'),
      ]),
      backgroundColor: AppTheme.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// RoomsScreen — Shell with 3-tab bottom nav
// ─────────────────────────────────────────────────────────────────────────────

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoomsBloc, RoomsState>(
      listenWhen: (_, s) =>
          s is RoomsPasswordRequired ||
          s is RoomsPasswordWrong ||
          s is RoomsJoinSuccess ||
          s is RoomsJoinFailure,
      listener: (context, state) async {
        if (state is RoomsPasswordRequired) {
          _showPasswordDialog(context, state.roomId, state.roomName);
        }
        if (state is RoomsPasswordWrong) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Incorrect password!'),
            backgroundColor: Colors.red,
          ));
        }
        if (state is RoomsJoinSuccess) {
          context.read<RoomsBloc>().add(RoomsLoadRequested());
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameScreen(roomId: state.roomId),
            ),
          );
        }
        if (state is RoomsJoinFailure) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
          ));
        }
      },
      builder: (context, state) {
        final navIndex = state is RoomsLoaded
            ? state.navIndex
            : state is RoomsJoinLoading
                ? state.navIndex
                : (state is RoomsSearchLoading || state is RoomsSearchResult)
                    ? 1  // stay on Search tab while searching / showing result
                    : 0;
        final isGuest = AuthService.isGuest;

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
            isGuest: isGuest,
            onTap: (i) {
              if (i == 2 && isGuest) {
                _showGuestCreatePrompt(context);
                return;
              }
              context.read<RoomsBloc>().add(RoomsNavChanged(i));
            },
          ),
        );
      },
    );
  }

  void _showGuestCreatePrompt(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.lock_outline, color: AppTheme.warning, size: 22),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'Guests Cannot Create Rooms',
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ]),
        content: const Text(
          'Only registered users can host a Tambola room.\n\nCreate a free account to unlock room creation!',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final name = await AuthService.getGuestName();
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider(
                    create: (_) => AuthBloc(),
                    child: AuthScreen(
                      prefilledUsername: name,
                      isGuestUpgrade: true,
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.how_to_reg, size: 18),
            label: const Text('Create Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showPasswordDialog(
      BuildContext context, String roomId, String roomName) {
    showDialog<void>(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<RoomsBloc>(),
        child: _PasswordDialog(roomId: roomId, roomName: roomName),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isGuest;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.isGuest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: const Border(top: BorderSide(color: AppTheme.border, width: 1)),
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
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
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
                          gradient: isGuest
                              ? null
                              : const LinearGradient(colors: [
                                  AppTheme.primary,
                                  AppTheme.primaryLight
                                ]),
                          color: isGuest ? AppTheme.bgCardLight : null,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: isGuest
                              ? null
                              : [
                                  BoxShadow(
                                    color: AppTheme.primary.withOpacity(0.45),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: Icon(
                          isGuest ? Icons.lock_outline : Icons.add_rounded,
                          color:
                              isGuest ? AppTheme.textSecondary : Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Create',
                          style: TextStyle(
                            fontSize: 11,
                            color: isGuest
                                ? AppTheme.textSecondary
                                : AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          )),
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                size: 24,
                color: isActive ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                )),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 3,
              width: isActive ? 20 : 0,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryLight]),
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
// Home Tab
// ─────────────────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return BlocBuilder<RoomsBloc, RoomsState>(
      builder: (context, state) {
        final rooms = state is RoomsLoaded
            ? state
            : state is RoomsJoinLoading
                ? RoomsLoaded(
                    rooms: state.rooms,
                    tabIndex: state.tabIndex,
                    navIndex: state.navIndex)
                : null;

        final tabIndex = rooms?.tabIndex ?? 0;
        final isLoading = state is RoomsLoading || state is RoomsJoinLoading;
        final ongoingRooms = rooms?.ongoingRooms ?? [];
        final finishedRooms = rooms?.finishedRooms ?? [];
        final ongoingPage = rooms?.ongoingPage ?? 0;
        final finishedPage = rooms?.finishedPage ?? 0;
        final ongoingPageCount = rooms?.ongoingPageCount ?? 1;
        final finishedPageCount = rooms?.finishedPageCount ?? 1;
        final ongoingHasPages = rooms?.ongoingHasPages ?? false;
        final finishedHasPages = rooms?.finishedHasPages ?? false;
        final finishedFilter = rooms?.finishedFilter ?? FinishedFilter.all;

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
                _buildHeader(context, user),
                _buildTabs(context, tabIndex),
                Expanded(
                  child: isLoading && rooms == null
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primary))
                      : RefreshIndicator(
                          onRefresh: () async => context
                              .read<RoomsBloc>()
                              .add(RoomsLoadRequested()),
                          color: AppTheme.primary,
                          child: tabIndex == 0
                              ? (ongoingRooms.isEmpty
                                  ? _buildEmptyState(
                                      Icons.sports_esports_outlined,
                                      'No ongoing games',
                                      'Create a room or search by code!')
                                  : _buildRoomsList(
                                      context,
                                      ongoingRooms,
                                      tabIndex: 0,
                                      currentPage: ongoingPage,
                                      pageCount: ongoingPageCount,
                                      hasPages: ongoingHasPages,
                                    ))
                              : Column(
                                  children: [
                                    _buildFinishedFilterBar(
                                        context, finishedFilter),
                                    Expanded(
                                      child: finishedRooms.isEmpty
                                      ? _buildEmptyState(
                                      _emptyIconForFilter(finishedFilter),
                                      _emptyTitleForFilter(finishedFilter),
                                      _emptySubtitleForFilter(finishedFilter),
                                      )
                                          : _buildRoomsList(
                                              context,
                                              finishedRooms,
                                              tabIndex: 1,
                                              currentPage: finishedPage,
                                              pageCount: finishedPageCount,
                                              hasPages: finishedHasPages,
                                            ),
                                    ),
                                  ],
                                ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, User? user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryLight]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.grid_view_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TAMBOLA',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: Colors.white,
                  )),
              Text('Live Rooms',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () =>
                context.read<RoomsBloc>().add(RoomsLoadRequested()),
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
          ),
          _buildAvatarMenu(context, user),
        ],
      ),
    );
  }

  Widget _buildAvatarMenu(BuildContext context, User? user) {
    return PopupMenuButton(
      icon: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: AuthService.isGuest
              ? const Icon(Icons.person_outline,
                  size: 18, color: AppTheme.textSecondary)
              : Text(
                  (user?.email?.substring(0, 1) ?? '?').toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.bold),
                ),
        ),
      ),
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Row(children: [
            Icon(
              AuthService.isGuest
                  ? Icons.person_outline
                  : Icons.email_outlined,
              size: 18,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              AuthService.isGuest ? 'Guest User' : (user?.email ?? 'User'),
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ]),
        ),
        if (AuthService.isGuest)
          PopupMenuItem(
            onTap: () async {
              final name = await AuthService.getGuestName();
              if (!context.mounted) return;
              await Future.delayed(const Duration(milliseconds: 200));
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider(
                    create: (_) => AuthBloc(),
                    child: AuthScreen(
                        prefilledUsername: name, isGuestUpgrade: true),
                  ),
                ),
              );
            },
            child: const Row(children: [
              Icon(Icons.how_to_reg, size: 18, color: AppTheme.accent),
              SizedBox(width: 8),
              Text('Create Account', style: TextStyle(color: AppTheme.accent)),
            ]),
          )
        else
          PopupMenuItem(
            onTap: () async => await FirebaseAuth.instance.signOut(),
            child: const Row(children: [
              Icon(Icons.logout, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Sign Out', style: TextStyle(color: Colors.red)),
            ]),
          ),
      ],
    );
  }

  Widget _buildTabs(BuildContext context, int tabIndex) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          _tabButton(
              context, 'Ongoing', 0, Icons.play_circle_outline, tabIndex),
          _tabButton(context, 'Finished', 1, Icons.flag_outlined, tabIndex),
        ]),
      ),
    );
  }

  Widget _tabButton(BuildContext context, String label, int index,
      IconData icon, int current) {
    final selected = current == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => context.read<RoomsBloc>().add(RoomsTabChanged(index)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryLight])
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return ListView(children: [
      const SizedBox(height: 80),
      Column(children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(icon, size: 48, color: AppTheme.textSecondary),
        ).animate().scale(curve: Curves.elasticOut),
        const SizedBox(height: 20),
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary)),
      ]),
    ]);
  }

  IconData _emptyIconForFilter(FinishedFilter f) {
    switch (f) {
      case FinishedFilter.mine: return Icons.meeting_room_outlined;
      case FinishedFilter.winner: return Icons.emoji_events_outlined;
      case FinishedFilter.cancelled: return Icons.cancel_outlined;
      case FinishedFilter.all: return Icons.flag_outlined;
    }
  }

  String _emptyTitleForFilter(FinishedFilter f) {
    switch (f) {
      case FinishedFilter.mine: return 'No games hosted by you';
      case FinishedFilter.winner: return 'No completed games yet';
      case FinishedFilter.cancelled: return 'No cancelled games';
      case FinishedFilter.all: return 'No finished games';
    }
  }

  String _emptySubtitleForFilter(FinishedFilter f) {
    switch (f) {
      case FinishedFilter.mine: return 'Rooms you hosted will appear here.';
      case FinishedFilter.winner: return 'Games with a Housie winner will appear here.';
      case FinishedFilter.cancelled: return 'Games cancelled by the host will appear here.';
      case FinishedFilter.all: return 'Finished games will appear here.';
    }
  }

  Widget _buildFinishedFilterBar(BuildContext context, FinishedFilter current) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.filter_list_rounded,
                size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            const Text('Filter:',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            _FilterChip(
              label: 'All Games',
              icon: Icons.grid_view_rounded,
              isActive: current == FinishedFilter.all,
              onTap: () => context
                  .read<RoomsBloc>()
                  .add(const RoomsFinishedFilterChanged(FinishedFilter.all)),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'My Rooms',
              icon: Icons.person_rounded,
              isActive: current == FinishedFilter.mine,
              onTap: () => context
                  .read<RoomsBloc>()
                  .add(const RoomsFinishedFilterChanged(FinishedFilter.mine)),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Winners',
              icon: Icons.emoji_events_rounded,
              isActive: current == FinishedFilter.winner,
              onTap: () => context
                  .read<RoomsBloc>()
                  .add(const RoomsFinishedFilterChanged(FinishedFilter.winner)),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Cancelled',
              icon: Icons.cancel_outlined,
              isActive: current == FinishedFilter.cancelled,
              activeColor: Colors.red,
              onTap: () => context
                  .read<RoomsBloc>()
                  .add(const RoomsFinishedFilterChanged(FinishedFilter.cancelled)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomsList(
    BuildContext context,
    List<Room> rooms, {
    required int tabIndex,
    required int currentPage,
    required int pageCount,
    required bool hasPages,
  }) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: rooms.length,
            itemBuilder: (ctx, i) {
              final room = rooms[i];
              return _RoomCard(
                room: room,
                isMyRoom: room.hostId == currentUserId,
                onJoin: () =>
                    context.read<RoomsBloc>().add(RoomsJoinRequested(room.id)),
              )
                  .animate(key: ValueKey('${room.id}_$currentPage'))
                  .fadeIn(duration: 220.ms)
                  .slideX(begin: 0.04);
            },
          ),
        ),
        if (hasPages)
          _buildPaginationBar(
            context,
            tabIndex: tabIndex,
            currentPage: currentPage,
            pageCount: pageCount,
          ),
      ],
    );
  }

  Widget _buildPaginationBar(
    BuildContext context, {
    required int tabIndex,
    required int currentPage,
    required int pageCount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageButton(
            icon: Icons.chevron_left_rounded,
            enabled: currentPage > 0,
            onTap: () => context.read<RoomsBloc>().add(
                  RoomsPageChanged(tabIndex: tabIndex, page: currentPage - 1),
                ),
          ),
          const SizedBox(width: 8),
          ...List.generate(pageCount, (i) {
            final isActive = i == currentPage;
            return GestureDetector(
              onTap: isActive
                  ? null
                  : () => context.read<RoomsBloc>().add(
                        RoomsPageChanged(tabIndex: tabIndex, page: i),
                      ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 32 : 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryLight])
                      : null,
                  color: isActive ? null : AppTheme.bgCardLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? AppTheme.primary : AppTheme.border,
                    width: isActive ? 0 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          _PageButton(
            icon: Icons.chevron_right_rounded,
            enabled: currentPage < pageCount - 1,
            onTap: () => context.read<RoomsBloc>().add(
                  RoomsPageChanged(tabIndex: tabIndex, page: currentPage + 1),
                ),
          ),
        ],
      ),
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
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoomsBloc, RoomsState>(
      builder: (context, state) {
        final searchState =
            state is RoomsSearchLoading || state is RoomsSearchResult
                ? state
                : null;
        final isSearching = searchState is RoomsSearchLoading;
        final result = searchState is RoomsSearchResult ? searchState : null;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Find a Room',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Enter the 6-digit room code to join',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        onSubmitted: (_) => context
                            .read<RoomsBloc>()
                            .add(RoomsSearchByCode(_searchCtrl.text)),
                        decoration: InputDecoration(
                          labelText: 'Room Code',
                          hintText: '123456',
                          prefixIcon: const Icon(Icons.tag_rounded),
                          counterText: '',
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () => _searchCtrl.clear(),
                                  icon: const Icon(Icons.clear, size: 18),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isSearching
                            ? null
                            : () => context
                                .read<RoomsBloc>()
                                .add(RoomsSearchByCode(_searchCtrl.text)),
                        child: isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Search'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (result != null) ...[
                  if (result.error != null)
                    Center(
                      child: Text(result.error!,
                          style: const TextStyle(color: Colors.red)),
                    )
                  else if (result.room != null)
                    _RoomCard(
                      room: result.room!,
                      isMyRoom: result.room!.hostId ==
                          FirebaseAuth.instance.currentUser?.uid,
                      onJoin: () => context
                          .read<RoomsBloc>()
                          .add(RoomsJoinRequested(result.room!.id)),
                    ).animate().fadeIn().slideY(begin: 0.1),
                ],
              ],
            ),
          ),
        );
      },
    );
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
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit(CreateRoomInitial s) {
    if (!_formKey.currentState!.validate()) return;
    context.read<CreateRoomBloc>().add(CreateRoomSubmitted(
          name: _nameCtrl.text,
          password: s.hasPassword ? _passwordCtrl.text : null,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateRoomBloc, CreateRoomState>(
      listener: (context, state) {
        if (state is CreateRoomSuccess) {
          context.read<CreateRoomBloc>().add(CreateRoomReset());
          context.read<RoomsBloc>().add(const RoomsNavChanged(0));
          context.read<RoomsBloc>().add(RoomsLoadRequested());
          _nameCtrl.clear();
          _passwordCtrl.clear();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameScreen(roomId: state.roomId),
            ),
          );
        }
        if (state is CreateRoomFailure) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
          ));
          context.read<CreateRoomBloc>().add(CreateRoomReset());
        }
      },
      builder: (context, state) {
        final s =
            state is CreateRoomInitial ? state : const CreateRoomInitial();
        final isLoading = state is CreateRoomLoading;
        final isGuest = AuthService.isGuest;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create Room',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Set up your Tambola game',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 24),
                  if (isGuest)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.warning.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.lock_outline,
                            color: AppTheme.warning, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Create an account to host rooms.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final name = await AuthService.getGuestName();
                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider(
                                  create: (_) => AuthBloc(),
                                  child: AuthScreen(
                                      prefilledUsername: name,
                                      isGuestUpgrade: true),
                                ),
                              ),
                            );
                          },
                          child: const Text('Register'),
                        ),
                      ]),
                    )
                  else ...[
                    _buildSection('Room Details', Icons.meeting_room_outlined, [
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Room Name',
                          hintText: 'e.g. Family Tambola Night',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Room name required';
                          if (v.trim().length < 3) return 'Min 3 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        const Text('Max Number',
                            style: TextStyle(color: AppTheme.textSecondary)),
                        const Spacer(),
                        ...[50, 100, 150].map((n) => GestureDetector(
                              onTap: () => context
                                  .read<CreateRoomBloc>()
                                  .add(CreateRoomMaxNumberChanged(n)),
                              child: AnimatedContainer(
                                duration: 200.ms,
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: s.maxNumber == n
                                      ? AppTheme.primary
                                      : AppTheme.bgCardLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('$n',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: s.maxNumber == n
                                            ? Colors.white
                                            : AppTheme.textSecondary)),
                              ),
                            )),
                      ]),
                    ]).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
                    const SizedBox(height: 20),

                    _buildSection('Game Settings', Icons.settings_outlined, [
                      Row(children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: s.autoCall
                                  ? AppTheme.primary.withOpacity(0.08)
                                  : AppTheme.bgDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: s.autoCall
                                    ? AppTheme.primary.withOpacity(0.4)
                                    : AppTheme.border,
                              ),
                            ),
                            child: Column(children: [
                              Row(children: [
                                Icon(Icons.timer_outlined,
                                    size: 15,
                                    color: s.autoCall
                                        ? AppTheme.primary
                                        : AppTheme.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text('Auto-call',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: s.autoCall
                                              ? AppTheme.primary
                                              : AppTheme.textPrimary)),
                                ),
                                Transform.scale(
                                  scale: 0.8,
                                  child: Switch(
                                    value: s.autoCall,
                                    activeColor: AppTheme.primary,
                                    onChanged: (v) => context
                                        .read<CreateRoomBloc>()
                                        .add(CreateRoomAutoCallToggled(v)),
                                  ),
                                ),
                              ]),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: s.soundEnabled
                                  ? AppTheme.primary.withOpacity(0.08)
                                  : AppTheme.bgDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: s.soundEnabled
                                    ? AppTheme.primary.withOpacity(0.4)
                                    : AppTheme.border,
                              ),
                            ),
                            child: Column(children: [
                              Row(children: [
                                Icon(Icons.volume_up_rounded,
                                    size: 15,
                                    color: s.soundEnabled
                                        ? AppTheme.primary
                                        : AppTheme.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text('Sound',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: s.soundEnabled
                                              ? AppTheme.primary
                                              : AppTheme.textPrimary)),
                                ),
                                Transform.scale(
                                  scale: 0.8,
                                  child: Switch(
                                    value: s.soundEnabled,
                                    activeColor: AppTheme.primary,
                                    onChanged: (v) => context
                                        .read<CreateRoomBloc>()
                                        .add(CreateRoomSoundToggled(v)),
                                  ),
                                ),
                              ]),
                            ]),
                          ),
                        ),
                      ]),
                      if (s.autoCall) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppTheme.border),
                        const SizedBox(height: 12),
                        Row(children: [
                          const Text('Interval',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 13)),
                          const Spacer(),
                          ...[3, 5, 10, 15, 30].map((sec) => GestureDetector(
                                onTap: () => context.read<CreateRoomBloc>().add(
                                    CreateRoomAutoCallIntervalChanged(sec)),
                                child: AnimatedContainer(
                                  duration: 200.ms,
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: s.autoCallInterval == sec
                                        ? AppTheme.primary
                                        : AppTheme.bgCardLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('${sec}s',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: s.autoCallInterval == sec
                                              ? Colors.white
                                              : AppTheme.textSecondary)),
                                ),
                              )),
                        ]),
                      ],
                    ]).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                    const SizedBox(height: 20),

                    _buildSection(
                        'Suggestion Mode', Icons.lightbulb_outline, [
                      Row(children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Highlight called numbers'),
                              SizedBox(height: 2),
                              Text(
                                'When ON: called numbers glow amber on your ticket and the matched count auto-increases. When OFF: count only increases when you manually tap a number.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                    height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: s.suggestionMode,
                          activeColor: AppTheme.accent,
                          onChanged: (v) => context
                              .read<CreateRoomBloc>()
                              .add(CreateRoomSuggestionModeToggled(v)),
                        ),
                      ]),
                      if (s.suggestionMode) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppTheme.accent.withOpacity(0.3)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: AppTheme.accent),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('How it works',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.accent)),
                                    SizedBox(height: 4),
                                    Text(
                                      '• Called numbers on your ticket glow amber\n• The matched counter increases automatically\n• You still need to tap to mark them',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                          height: 1.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ]).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                    const SizedBox(height: 20),

                    _buildSection(
                        'Password Protection', Icons.security_outlined, [
                      Row(children: [
                        const Text('Require password to join'),
                        const Spacer(),
                        Switch(
                          value: s.hasPassword,
                          activeColor: AppTheme.primary,
                          onChanged: (v) => context
                              .read<CreateRoomBloc>()
                              .add(CreateRoomPasswordToggled(v)),
                        ),
                      ]),
                      if (s.hasPassword) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: s.obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Room Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => context
                                  .read<CreateRoomBloc>()
                                  .add(CreateRoomPasswordVisibilityToggled()),
                              icon: Icon(s.obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                            ),
                          ),
                          validator: (v) {
                            if (s.hasPassword && (v == null || v.isEmpty))
                              return 'Password required';
                            return null;
                          },
                        ),
                      ],
                    ]).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                    const SizedBox(height: 32),

                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () => _submit(s),
                        style: ElevatedButton.styleFrom(
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
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              Icon(icon, color: AppTheme.primary, size: 18),
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
// Compact Ongoing Card Body
// ─────────────────────────────────────────────────────────────────────────────

class _CompactOngoingCardBody extends StatelessWidget {
  final Room room;
  final bool isMyRoom;
  final bool isPlaying;
  final Color accentColor;
  final VoidCallback onJoin;

  const _CompactOngoingCardBody({
    required this.room,
    required this.isMyRoom,
    required this.isPlaying,
    required this.accentColor,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left accent bar
          Container(
            width: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [accentColor, accentColor.withOpacity(0.1)],
              ),
            ),
          ),
          // Card body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: isMyRoom
                          ? AppTheme.primary.withOpacity(0.15)
                          : accentColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: isMyRoom
                            ? AppTheme.primary.withOpacity(0.45)
                            : accentColor.withOpacity(0.30),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        room.hostUsername.isNotEmpty
                            ? room.hostUsername[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isMyRoom ? AppTheme.primary : accentColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Room info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(
                              room.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (room.hasPassword) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.lock_rounded, size: 10, color: AppTheme.warning),
                          ],
                        ]),
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.person_outline_rounded, size: 10, color: AppTheme.textSecondary),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              room.hostUsername,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 5),
                        // Tags
                        Wrap(spacing: 4, runSpacing: 4, children: [
                          _TinyTag('${room.memberCount} players'),
                          _TinyTag('1\u2013${room.maxNumber}'),
                          if (room.autoCall) const _TinyTag('\u23f1 Auto', color: AppTheme.primary),
                          if (room.suggestionMode) const _TinyTag('Hints', color: AppTheme.accent),
                          if (room.soundEnabled) const _TinyTag('Sound', color: Color(0xFF38C7FF)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Right: status + button
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Status pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accentColor.withOpacity(0.40)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (isPlaying) ...[
                            _PulsingDot(color: accentColor),
                            const SizedBox(width: 4),
                          ] else ...[
                            Icon(Icons.hourglass_top_rounded, size: 8, color: accentColor),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            isPlaying ? 'LIVE' : 'WAIT',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 7),
                      // Action button
                      _buildActionButton(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (isMyRoom) {
      return GestureDetector(
        onTap: onJoin,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppTheme.accent.withOpacity(0.40)),
          ),
          child: const Text('Open',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accent)),
        ),
      );
    }
    if (room.isCurrentUserMember) {
      return GestureDetector(
        onTap: onJoin,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight]),
            borderRadius: BorderRadius.circular(9),
            boxShadow: [BoxShadow(
              color: AppTheme.primary.withOpacity(0.35),
              blurRadius: 8, offset: const Offset(0, 3),
            )],
          ),
          child: const Text('Resume',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      );
    }
    if (room.status == 'waiting' || room.status == 'playing') {
      return GestureDetector(
        onTap: onJoin,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPlaying
                  ? [AppTheme.secondary.withOpacity(0.85), AppTheme.secondary]
                  : [AppTheme.accent.withOpacity(0.85), AppTheme.accent],
            ),
            borderRadius: BorderRadius.circular(9),
            boxShadow: [BoxShadow(
              color: (isPlaying ? AppTheme.secondary : AppTheme.accent).withOpacity(0.30),
              blurRadius: 8, offset: const Offset(0, 3),
            )],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (room.hasPassword)
              const Icon(Icons.lock_open_rounded, size: 12, color: Colors.white)
            else
              const Icon(Icons.login_rounded, size: 12, color: Colors.white),
            const SizedBox(width: 5),
            const Text('Join',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Room Card
// ─────────────────────────────────────────────────────────────────────────────

class _RoomCard extends StatelessWidget {
  final Room room;
  final bool isMyRoom;
  final VoidCallback onJoin;

  const _RoomCard({
    required this.room,
    required this.isMyRoom,
    required this.onJoin,
  });

  Color get _statusColor {
    switch (room.status) {
      case 'waiting':  return AppTheme.accent;
      case 'playing':  return AppTheme.secondary;
      case 'finished': return AppTheme.textSecondary;
      case 'cancelled': return Colors.red;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (room.isFinished || room.isCancelled) {
      final accentColor = room.isCancelled ? Colors.red : const Color(0xFFFFD700);
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(room.isCancelled ? 0.30 : 0.35)),
          boxShadow: room.isFinished && room.winnerUsername != null
              ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4))]
              : null,
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(20), child: _buildFinishedCard()),
      );
    }
    final isPlaying = room.isPlaying;
    final accentColor = isPlaying ? AppTheme.secondary : AppTheme.accent;
    final borderColor = isMyRoom
        ? AppTheme.primary.withOpacity(0.60)
        : room.isCurrentUserMember
            ? AppTheme.primaryLight.withOpacity(0.45)
            : accentColor.withOpacity(0.35);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(isPlaying ? 0.14 : 0.07),
            blurRadius: 20, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(21), child: _buildOngoingCard()),
    );
  }

  Widget _buildOngoingCard() {
    final isPlaying = room.isPlaying;
    final accentColor = isPlaying ? AppTheme.secondary : AppTheme.accent;

    return Container(
      decoration: const BoxDecoration(color: AppTheme.bgCard),
      child: _CompactOngoingCardBody(
        room: room,
        isMyRoom: isMyRoom,
        isPlaying: isPlaying,
        accentColor: accentColor,
        onJoin: onJoin,
      ),
    );
  }

  Widget _buildFinishedCard() {
    final isCancelled = room.isCancelled;
    final hasWinner = room.winnerUsername != null;
    final accentColor = isCancelled ? Colors.red : const Color(0xFFFFD700);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: isCancelled
              ? [const Color(0xFF1E1220), AppTheme.bgCard]
              : hasWinner
                  ? [const Color(0xFF1E1A10), AppTheme.bgCard]
                  : [AppTheme.bgCard, const Color(0xFF181628)],
        ),
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [accentColor, accentColor.withOpacity(0.12)],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.withOpacity(0.25)),
                    ),
                    child: Center(
                      child: Text(room.hostUsername.substring(0, 1).toUpperCase(),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accentColor.withOpacity(0.80))),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(room.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.1),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text(room.hostUsername, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        if (room.roomCode != null) ...[const SizedBox(width: 6), _codeBadge()],
                      ]),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentColor.withOpacity(0.35)),
                    ),
                    child: Text(isCancelled ? 'CANCELLED' : 'ENDED',
                        style: TextStyle(color: accentColor.withOpacity(0.90), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  ),
                ]),
                const SizedBox(height: 12),
                if (isCancelled)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.22)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), shape: BoxShape.circle),
                        child: const Center(child: Icon(Icons.cancel_rounded, color: Colors.red, size: 17)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('CANCELLED', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          SizedBox(height: 2),
                          Text('Host ended the game early', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ]),
                      ),
                    ]),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: hasWinner
                            ? [const Color(0xFFFFD700).withOpacity(0.12), const Color(0xFFFFA500).withOpacity(0.05)]
                            : [AppTheme.bgCardLight, AppTheme.bgCardLight],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: hasWinner ? const Color(0xFFFFD700).withOpacity(0.28) : AppTheme.border),
                    ),
                    child: hasWinner
                        ? Row(children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 3))],
                              ),
                              child: const Center(child: Text('🏆', style: TextStyle(fontSize: 20))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('WINNER', style: TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                const SizedBox(height: 2),
                                Text(room.winnerUsername!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis),
                              ]),
                            ),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('${room.calledNumbers.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFFFD700), height: 1)),
                              Text('of ${room.maxNumber}', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withOpacity(0.8))),
                              const Text('called', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            ]),
                          ])
                        : Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.bgDark.withOpacity(0.5), shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: const Center(child: Icon(Icons.flag_rounded, size: 17, color: AppTheme.textSecondary)),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('No winner claimed', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500))),
                            Text('${room.calledNumbers.length}/${room.maxNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                          ]),
                  ),
                const SizedBox(height: 12),
                Row(children: [
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _MiniPill(icon: Icons.people_outline, label: '${room.memberCount} players'),
                    _MiniPill(icon: Icons.casino_outlined, label: '1–${room.maxNumber}'),
                    if (!isCancelled) _MiniPill(icon: Icons.checklist_rounded, label: '${room.calledNumbers.length} called'),
                  ]),
                  const Spacer(),
                  _SpectateButton(roomId: room.id),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _hostBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text('HOST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
  );

  Widget _codeBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.primary.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
    ),
    child: Text('# ${room.roomCode}',
        style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TinyTag extends StatelessWidget {
  final String label;
  final Color? color;

  const _TinyTag(this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  final Color? highlightColor;

  const _MiniPill({required this.icon, required this.label, this.highlight = false, this.highlightColor});

  @override
  Widget build(BuildContext context) {
    final bool colored = highlight || highlightColor != null;
    final Color color = highlightColor ?? (highlight ? AppTheme.primary : AppTheme.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colored ? color.withOpacity(0.10) : AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colored ? color.withOpacity(0.35) : AppTheme.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 850))..repeat(reverse: true);
    _anim = Tween(begin: 0.25, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
}

class _SpectateButton extends StatelessWidget {
  final String roomId;
  const _SpectateButton({required this.roomId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SpectateScreen(roomId: roomId))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.visibility_rounded, size: 14, color: Colors.blueAccent),
          SizedBox(width: 5),
          Text('Spectate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        ]),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PageButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.primary.withOpacity(0.15) : AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: enabled ? AppTheme.primary.withOpacity(0.5) : AppTheme.border),
        ),
        child: Icon(icon, size: 20, color: enabled ? AppTheme.primary : AppTheme.textSecondary),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final Color? activeColor;

  const _FilterChip({required this.label, required this.icon, required this.isActive, required this.onTap, this.activeColor});

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isActive && activeColor == null
              ? const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight])
              : null,
          color: isActive && activeColor != null ? color : isActive ? null : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color : AppTheme.border),
          boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 2))] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: isActive ? Colors.white : AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.white : AppTheme.textSecondary)),
        ]),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  final String roomId;
  final String roomName;
  const _PasswordDialog({required this.roomId, required this.roomName});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _submit() {
    Navigator.pop(context);
    context.read<RoomsBloc>().add(RoomsPasswordVerified(roomId: widget.roomId, password: _ctrl.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.lock, color: AppTheme.warning, size: 20),
        SizedBox(width: 8),
        Text('Enter Password'),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Room "${widget.roomName}" is protected',
            style: const TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          obscureText: _obscure,
          autofocus: true,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
            ),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Join')),
      ],
    );
  }
}
