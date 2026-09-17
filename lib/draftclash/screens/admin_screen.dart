// lib/draftclash/screens/admin_screen.dart
//
// ⚠️  ADMIN ONLY — gated by `is_admin` field in Firestore profiles/{uid}.
//
// Uses DraftCatalogCubit (provided by GamesLobbyScreen) for cards + franchises.
// No local _loadCards() call needed — cubit is already loaded by the time admin opens.
// Mutations (add/edit/delete) update the cubit state, which DraftClash also reads.
//
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/auth_service.dart';
import '../cubit/draft_catalog_cubit.dart';
import '../utils/admin_theme.dart';
import '../widgets/admin/admin_action_card.dart';
import '../widgets/admin/admin_empty_dashboard.dart';
import '../widgets/admin/admin_header.dart';
import '../widgets/admin/admin_section_label.dart';
import '../widgets/admin/admin_stats_shimmer.dart';
import '../widgets/admin/admin_stats_row.dart';
import '../widgets/admin/admin_tier_breakdown.dart';
import 'admin_catalogue_screen.dart';
import 'admin_add_card_screen.dart';
import 'admin_migration_screen.dart';
import 'admin_slots_screen.dart';


class DraftAdminScreen extends StatefulWidget {
  /// Optional externally-created cubit to share with DraftClash.
  /// If omitted the screen creates and owns its own cubit.
  final DraftCatalogCubit? catalog;

  const DraftAdminScreen({super.key, this.catalog});

  static Future<bool> isAdmin() => AuthService.isAdmin();

  @override
  State<DraftAdminScreen> createState() => _DraftAdminScreenState();
}

class _DraftAdminScreenState extends State<DraftAdminScreen> {
  bool _isAdmin       = false;
  bool _checkingAdmin = true;

  // Owned cubit — only used when no external catalog is injected.
  DraftCatalogCubit? _ownedCubit;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  @override
  void dispose() {
    // Only close the cubit if WE created it; external cubits are managed by
    // their owner (GamesLobbyScreen).
    _ownedCubit?.close();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final result = await AuthService.isAdmin();
    if (!mounted) return;
    setState(() { _isAdmin = result; _checkingAdmin = false; });

    // Trigger load on whichever cubit is available (idempotent).
    // widget.catalog is the externally-shared cubit (from GamesLobbyScreen).
    // _ownedCubit is created here if no external cubit was injected.
    if (result) {
      final cubitToLoad = widget.catalog ?? (_ownedCubit ??= DraftCatalogCubit());
      cubitToLoad.load();
    }
  }

  // ── Tier computation — pure from cubit state ──────────────────────────────

  int _legendary(List cards) => cards.where((c) => c.level >= 9.6).length;
  int _mythic   (List cards) => cards.where((c) => c.level >= 8.5 && c.level < 9.6).length;
  int _epic     (List cards) => cards.where((c) => c.level >= 6.5 && c.level < 8.5).length;
  int _rare     (List cards) => cards.where((c) => c.level >= 3.5 && c.level < 6.5).length;
  int _common   (List cards) => cards.where((c) => c.level < 3.5).length;

  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) {
      return const Scaffold(
        backgroundColor: kAdminBg,
        body: Center(child: CircularProgressIndicator(color: kAdminViolet)),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: kAdminBg,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: kAdminRed.withOpacity(0.1), shape: BoxShape.circle,
                border: Border.all(color: kAdminRed.withOpacity(0.4)),
              ),
              child: const Icon(Icons.lock_rounded, size: 36, color: kAdminRed),
            ),
            const SizedBox(height: 20),
            const Text('Admin Access Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: kAdminTxtPri)),
            const SizedBox(height: 8),
            const Text('Your account does not have admin privileges.',
                style: TextStyle(fontSize: 13, color: kAdminTxtMut)),
          ]),
        ),
      );
    }

    // ── Main admin dashboard — driven entirely by cubit state ─────────────
    //
    // KEY: capture `cubit` here and close over it in every navigation
    // callback. Never call context.read<DraftCatalogCubit>() in callbacks
    // because that `context` is ABOVE the BlocProvider.value we create
    // below — it will always throw ProviderNotFoundException.
    final cubit = widget.catalog ?? (_ownedCubit ??= DraftCatalogCubit());

    return BlocProvider.value(
      value: cubit,
      child: _AdminDashboard(
        onBack:        () => Navigator.pop(context),
        openCatalogue: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: cubit,
              child: const AdminCatalogueScreen(),
            ),
          ),
        ),
        openAddCard: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: cubit,
              child: const AdminAddCardScreen(),
            ),
          ),
        ),
        openSlots: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: cubit,
              child: const AdminSlotsScreen(),
            ),
          ),
        ),
        openMigration: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminMigrationScreen()),
        ),
        legendary: _legendary,
        mythic:    _mythic,
        epic:      _epic,
        rare:      _rare,
        common:    _common,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AdminDashboard — the real UI, receives callbacks instead of reading context
// ─────────────────────────────────────────────────────────────────────────────

class _AdminDashboard extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback openCatalogue;
  final VoidCallback openAddCard;
  final VoidCallback openSlots;
  final VoidCallback openMigration;
  final int Function(List) legendary;
  final int Function(List) mythic;
  final int Function(List) epic;
  final int Function(List) rare;
  final int Function(List) common;

  const _AdminDashboard({
    required this.onBack,
    required this.openCatalogue,
    required this.openAddCard,
    required this.openSlots,
    required this.openMigration,
    required this.legendary,
    required this.mythic,
    required this.epic,
    required this.rare,
    required this.common,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DraftCatalogCubit, DraftCatalogState>(
      builder: (context, catalog) {
        final cards      = catalog.allCards;
        final franchises = catalog.allFranchises;
        final loading    = catalog.isLoading;

        return Scaffold(
          backgroundColor: kAdminBg,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0A0914), Color(0xFF0D0C1E), Color(0xFF07070F)],
              ),
            ),
            child: SafeArea(
              child: RefreshIndicator(
                // Pull-to-refresh triggers a full re-fetch from Firebase.
                onRefresh: () => context.read<DraftCatalogCubit>().refresh(),
                color: kAdminViolet,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: AdminHeader(onBack: onBack),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: loading
                            ? const AdminStatsShimmer()
                            : AdminStatsRow(
                                total:      cards.length,
                                franchises: franchises.length,
                              ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: AdminSectionLabel(
                            label: 'Quick Actions',
                            icon:  Icons.flash_on_rounded),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Row(children: [
                          Expanded(
                            child: AdminActionCard(
                              icon:     Icons.style_rounded,
                              label:    'Browse Cards',
                              sublabel: '${cards.length} cards',
                              gradient: const [Color(0xFF1A0A3A), kAdminViolet],
                              iconBg:   kAdminViolet,
                              onTap:    openCatalogue,
                            ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.06),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AdminActionCard(
                              icon:     Icons.collections_bookmark_rounded,
                              label:    'Add Franchise',
                              sublabel: 'Manage series',
                              gradient: const [Color(0xFF1A0E00), kAdminAmber],
                              iconBg:   kAdminAmber,
                              onTap:    openAddCard,
                            ).animate().fadeIn(delay: 150.ms).slideX(begin: 0.06),
                          ),
                        ]),
                      ),
                    ),

                        SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: AdminActionCard(
                          icon:     Icons.tune_rounded,
                          label:    'Board Slots',
                          sublabel: 'Manage roles',
                          gradient: const [Color(0xFF001A14), kAdminGreen],
                          iconBg:   kAdminGreen,
                          onTap:    openSlots,
                        ).animate().fadeIn(delay: 175.ms).slideY(begin: 0.06),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: AdminActionCard(
                          icon:     Icons.build_rounded,
                          label:    'Data Migration',
                          sublabel: 'franchiseId → franchiseIds',
                          gradient: const [Color(0xFF1A0000), kAdminRed],
                          iconBg:   kAdminRed,
                          onTap:    openMigration,
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.06),
                      ),
                    ),

                    if (!loading && cards.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                          child: AdminSectionLabel(
                              label: 'Tier Breakdown',
                              icon:  Icons.bar_chart_rounded),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          child: AdminTierBreakdown(
                            mythic:    mythic(cards),
                            legendary: legendary(cards),
                            epic:      epic(cards),
                            rare:      rare(cards),
                            common:    common(cards),
                            total:     cards.length,
                          ).animate().fadeIn(delay: 200.ms),
                        ),
                      ),
                    ],

                    if (!loading && cards.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: AdminEmptyDashboard(onAdd: openAddCard),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
