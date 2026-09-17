// lib/draftclash/screens/admin_catalogue_screen.dart
//
// Browse, search, edit and delete DraftClash cards.
// Data comes from DraftCatalogCubit — no direct Firestore reads needed.
// Edits / deletes call cubit mutation methods which write to Firebase AND
// update the in-memory state instantly (no re-fetch required).
//
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/draft_catalog_cubit.dart';
import '../models/draft_card.dart';
import '../utils/admin_theme.dart';
import '../widgets/admin/card_edit_sheet.dart';
import '../widgets/admin/catalogue_card_grid_item.dart';
import '../widgets/admin/catalogue_delete_dialog.dart';
import '../widgets/admin/catalogue_empty_filter.dart';
import '../widgets/admin/catalogue_filter_dropdown.dart';
import '../widgets/admin/catalogue_header.dart';
import '../widgets/admin/catalogue_search_bar.dart';

class AdminCatalogueScreen extends StatefulWidget {
  const AdminCatalogueScreen({super.key});

  @override
  State<AdminCatalogueScreen> createState() => _AdminCatalogueScreenState();
}

class _AdminCatalogueScreenState extends State<AdminCatalogueScreen> {
  final _searchCtrl = TextEditingController();
  String  _searchQuery     = '';
  String? _filterFranchise;
  String? _filterTier;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filtering — pure from cubit state, no local list needed ──────────────

  List<String> _franchiseNames(List<DraftCard> all) {
    final set = all.map((c) => c.franchiseName).toSet().toList()..sort();
    return set;
  }

  List<DraftCard> _filtered(List<DraftCard> all) {
    return all.where((c) {
      final q = _searchQuery.toLowerCase();
      if (q.isNotEmpty &&
          !c.name.toLowerCase().contains(q) &&
          !c.franchiseName.toLowerCase().contains(q) &&
          !c.description.toLowerCase().contains(q)) return false;
      if (_filterFranchise != null && c.franchiseName != _filterFranchise)
        return false;
      if (_filterTier != null && tierLabel(c.level) != _filterTier)
        return false;
      return true;
    }).toList()
      ..sort((a, b) => b.level.compareTo(a.level));
  }

  bool get _hasActiveFilter =>
      _filterTier != null || _filterFranchise != null || _searchQuery.isNotEmpty;

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _searchQuery     = '';
      _filterFranchise = null;
      _filterTier      = null;
    });
  }

  // ── Mutations — write Firebase + update cubit state ───────────────────────

  Future<void> _deleteCard(DraftCard card) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => CatalogueDeleteDialog(card: card),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    try {
      // Cubit writes to Firebase then removes from in-memory list.
      await context.read<DraftCatalogCubit>().deleteCard(card);
      _snack('✓ "${card.name}" deleted');
    } catch (e) {
      _snack('Delete failed: $e', isError: true);
    }
  }

  void _editCard(DraftCard card) {
    // Re-provide the cubit into the bottom sheet context (modal sheets get a
    // fresh route context that doesn't inherit parent BlocProviders).
    final catalog = context.read<DraftCatalogCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: catalog,
        child: CardEditSheet(
          card: card,
          onSaved: (updated) async {
            try {
              // Cubit writes to Firebase then replaces card in in-memory list.
              await context.read<DraftCatalogCubit>().updateCard(updated);
              if (mounted) _snack('✓ "${updated.name}" updated');
            } catch (e) {
              if (mounted) _snack('Update failed: $e', isError: true);
            }
          },
        ),
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? kAdminRed : kAdminGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DraftCatalogCubit, DraftCatalogState>(
      builder: (context, catalog) {
        final allCards   = catalog.allCards;
        final loading    = catalog.isLoading;
        final cards      = _filtered(allCards);
        final franchises = _franchiseNames(allCards);

        return Scaffold(
          backgroundColor: kAdminBg,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0A0914), kAdminBg],
              ),
            ),
            child: SafeArea(
              child: Column(children: [
                CatalogueHeader(
                  totalShown: cards.length,
                  totalAll:   allCards.length,
                  loading:    loading,
                  onBack:     () => Navigator.pop(context),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CatalogueSearchBar(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                      child: CatalogueFilterDropdown<String>(
                        icon:      Icons.bolt_rounded,
                        hint:      'Power Tier',
                        value:     _filterTier,
                        items:     const ['LEGENDARY', 'MYTHIC', 'EPIC', 'RARE', 'COMMON'],
                        itemLabel: (v) => v,
                        itemColor: (v) {
                          switch (v) {
                            case 'LEGENDARY': return kTierLegendary;
                            case 'MYTHIC':    return kTierMythic;
                            case 'EPIC':      return kTierEpic;
                            case 'RARE':      return kTierRare;
                            default:          return kTierCommon;
                          }
                        },
                        onChanged: (v) => setState(() => _filterTier = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CatalogueFilterDropdown<String>(
                        icon:      Icons.collections_bookmark_rounded,
                        hint:      'Franchise',
                        value:     _filterFranchise,
                        items:     franchises,
                        itemLabel: (v) => v,
                        itemColor: (_) => kAdminViolet,
                        onChanged: (v) => setState(() => _filterFranchise = v),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                if (!loading && allCards.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Row(children: [
                      Text(
                        cards.isEmpty
                            ? 'No matches'
                            : '${cards.length} card${cards.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 11, color: kAdminTxtMut),
                      ),
                      if (_hasActiveFilter) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _clearFilters,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kAdminViolet.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: kAdminViolet.withOpacity(0.3)),
                            ),
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.filter_alt_off_rounded,
                                      size: 10, color: kAdminViolet),
                                  SizedBox(width: 4),
                                  Text('Clear all',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: kAdminViolet,
                                          fontWeight: FontWeight.bold)),
                                ]),
                          ),
                        ),
                      ],
                    ]),
                  ),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: kAdminViolet))
                      : cards.isEmpty
                          ? CatalogueEmptyFilter(
                              onClear:  _clearFilters,
                              isEmpty:  allCards.isEmpty)
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 4, 16, 24),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:   2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing:  12,
                                childAspectRatio: 0.82,
                              ),
                              itemCount: cards.length,
                              itemBuilder: (_, i) => CatalogueCardGridItem(
                                card:     cards[i],
                                onEdit:   () => _editCard(cards[i]),
                                onDelete: () => _deleteCard(cards[i]),
                              )
                                  .animate(
                                      delay: Duration(
                                          milliseconds: 30 * i))
                                  .fadeIn(duration: 220.ms)
                                  .scale(
                                      begin: const Offset(0.93, 0.93),
                                      curve: Curves.easeOutCubic),
                            ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
