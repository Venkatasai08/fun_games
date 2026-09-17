// lib/screens/games_lobby_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../tambola/blocs/rooms/rooms_bloc.dart';
import '../tambola/blocs/create_room/create_room_bloc.dart';
import '../tambola/screens/rooms_screen.dart';
import '../draftclash/cubit/draft_catalog_cubit.dart';
import '../draftclash/screens/draft_lobby_screen.dart';
import '../draftclash/screens/admin_screen.dart';
// ── Card Room Game ────────────────────────────────────────────────────────────
import '../cardroomgame/blocs/rooms/card_rooms_bloc.dart';
import '../cardroomgame/blocs/create_room/create_card_room_bloc.dart';
import '../cardroomgame/screens/card_rooms_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GamesLobbyScreen
// ─────────────────────────────────────────────────────────────────────────────

class GamesLobbyScreen extends StatefulWidget {
  const GamesLobbyScreen({super.key});

  @override
  State<GamesLobbyScreen> createState() => _GamesLobbyScreenState();
}

class _GamesLobbyScreenState extends State<GamesLobbyScreen> {
  bool _isAdmin = false;

  late final DraftCatalogCubit _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = DraftCatalogCubit();
    AuthService.isAdmin().then((v) {
      if (mounted) setState(() => _isAdmin = v);
    });
  }

  @override
  void dispose() {
    _catalog.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user    = fb_auth.FirebaseAuth.instance.currentUser;
    final isGuest = AuthService.isGuest;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
            colors: [Color(0xFF0F0E1A), Color(0xFF1A1040), Color(0xFF0F0E1A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, user, isGuest, _isAdmin),
              Expanded(child: _buildGameGrid(context)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, fb_auth.User? user,
      bool isGuest, bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryLight]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.35),
                  blurRadius: 14, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.sports_esports_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FUN GAMES',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    letterSpacing: 3, color: Colors.white)),
              Text('Choose a game to play',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const Spacer(),
          _buildAvatarMenu(context, user, isGuest, isAdmin),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildAvatarMenu(BuildContext context, fb_auth.User? user,
      bool isGuest, bool isAdmin) {
    return PopupMenuButton<String>(
      icon: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: isGuest
              ? const Icon(Icons.person_outline,
                  size: 20, color: AppTheme.textSecondary)
              : Text(
                  (user?.email?.substring(0, 1) ?? '?').toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
        ),
      ),
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        if (value == 'signout') {
          if (isGuest) {
            await AuthService.signOut();
          } else {
            await fb_auth.FirebaseAuth.instance.signOut();
          }
        }
        if (value == 'admin') {
          _openAdmin(context);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Row(children: [
            Icon(isGuest ? Icons.person_outline : Icons.email_outlined,
                size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              isGuest ? 'Guest User' : (user?.email ?? 'User'),
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
          ]),
        ),
        const PopupMenuItem<String>(
          value: 'signout',
          child: Row(children: [
            Icon(Icons.logout, size: 18, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
          ]),
        ),
        if (isAdmin)
          const PopupMenuItem<String>(
            value: 'admin',
            child: Row(children: [
              Icon(Icons.admin_panel_settings_rounded,
                  size: 18, color: AppTheme.primary),
              SizedBox(width: 10),
              Text('DraftClash Admin',
                  style: TextStyle(color: AppTheme.primary)),
            ]),
          ),
      ],
    );
  }

  // ── Game Grid ─────────────────────────────────────────────────────────────

  Widget _buildGameGrid(BuildContext context) {
    final games = _gamesList(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      children: [
        const Text(
          'Available Games',
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary, letterSpacing: 1.2),
        ).animate().fadeIn(delay: 150.ms),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 16,
            crossAxisSpacing: 16, childAspectRatio: 0.82,
          ),
          itemCount: games.length,
          itemBuilder: (ctx, i) => games[i]
              .animate(delay: Duration(milliseconds: 200 + i * 80))
              .fadeIn().slideY(begin: 0.12),
        ),
        const SizedBox(height: 32),
        _buildComingSoonBanner()
            .animate(delay: 500.ms).fadeIn().slideY(begin: 0.1),
      ],
    );
  }

  List<Widget> _gamesList(BuildContext context) {
    return [
      _GameCard(
        title: 'Tambola',
        subtitle: 'Housie / Bingo',
        description: 'Call numbers, mark your ticket, shout Tambola!',
        icon: Icons.grid_on_rounded,
        gradient: const [Color(0xFF6C63FF), Color(0xFF9B59B6)],
        playerRange: '2–20 players',
        isAvailable: true,
        badge: null,
        onTap: () => _openTambola(context),
      ),
      _GameCard(
        title: 'DraftClash',
        subtitle: '1v1 Character Draft',
        description:
            'Draft anime & movie characters into your 6-slot team. Highest total level wins!',
        icon: Icons.swap_vert_rounded,
        gradient: const [Color(0xFFFF8C00), Color(0xFFFFD700)],
        playerRange: '1v1 only',
        isAvailable: true,
        badge: 'BETA',
        onTap: () => _openDraftClash(context),
      ),
      // ── NEW: Card Room ──────────────────────────────────────────────────
      _GameCard(
        title: 'Card Room',
        subtitle: 'Virtual Card Table',
        description:
            'Play any card game with your group. No physical cards needed — deal, pass & play in real-time!',
        icon: Icons.style_rounded,
        gradient: const [Color(0xFFE94560), Color(0xFFFF8C69)],
        playerRange: '2–6 players',
        isAvailable: true,
        badge: 'NEW',
        onTap: () => _openCardRoom(context),
      ),
    ];
  }

  void _openTambola(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => RoomsBloc()),
          BlocProvider(create: (_) => CreateRoomBloc()),
        ],
        child: const RoomsScreen(),
      ),
    ));
  }

  void _openDraftClash(BuildContext context) {
    _catalog.load();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: _catalog,
        child: const DraftLobbyScreen(),
      ),
    ));
  }

  void _openAdmin(BuildContext context) {
    _catalog.load();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DraftAdminScreen(catalog: _catalog),
    ));
  }

  // ── Card Room entry ───────────────────────────────────────────────────────

  void _openCardRoom(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider(
              create: (_) =>
                  CardRoomsBloc()..add(CardRoomsLoadRequested())),
          BlocProvider(create: (_) => CreateCardRoomBloc()),
        ],
        child: const CardRoomsScreen(),
      ),
    ));
  }

  Widget _buildComingSoonBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.rocket_launch_rounded,
                color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('More games coming!',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                SizedBox(height: 3),
                Text(
                  'We\'re building new multiplayer games. Check back soon.',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Game Card Widget
// ─────────────────────────────────────────────────────────────────────────────

class _GameCard extends StatelessWidget {
  final String title, subtitle, description;
  final IconData icon;
  final List<Color> gradient;
  final String playerRange;
  final bool isAvailable;
  final String? badge;
  final VoidCallback? onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.playerRange,
    required this.isAvailable,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isAvailable ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isAvailable
                ? gradient.first.withOpacity(0.4)
                : AppTheme.border),
          boxShadow: isAvailable
              ? [BoxShadow(
                  color: gradient.first.withOpacity(0.18),
                  blurRadius: 18, offset: const Offset(0, 6))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon banner
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isAvailable
                      ? gradient
                      : [const Color(0xFF1E1E2E), const Color(0xFF2D2D3E)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22)),
              ),
              child: Stack(
                children: [
                  Positioned(right: -14, top: -14,
                    child: Container(width: 70, height: 70,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06)))),
                  Positioned(right: 10, bottom: -20,
                    child: Container(width: 50, height: 50,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.04)))),
                  Center(child: Icon(icon, size: 44,
                    color: isAvailable
                        ? Colors.white
                        : AppTheme.textSecondary.withOpacity(0.4))),
                  if (isAvailable && badge != null)
                    Positioned(top: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(badge!,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                      )),
                ],
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold,
                        color: isAvailable
                            ? Colors.white
                            : AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isAvailable
                            ? gradient.first.withOpacity(0.9)
                            : AppTheme.textSecondary.withOpacity(0.5),
                        fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Row(children: [
                      Icon(Icons.people_outline, size: 12,
                          color: AppTheme.textSecondary.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(playerRange,
                          style: TextStyle(fontSize: 10,
                              color: AppTheme.textSecondary.withOpacity(0.7))),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
