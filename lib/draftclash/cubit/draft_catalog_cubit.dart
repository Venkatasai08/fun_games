// lib/draftclash/cubit/draft_catalog_cubit.dart
//
// DraftCatalogCubit — single source of truth for the card + franchise catalogue.
//
// PATTERN (analogous to Riverpod StateNotifierProvider):
//
//   // Provide once at GamesLobbyScreen level (above both DraftClash AND Admin):
//   _catalog = DraftCatalogCubit();
//   ...
//   BlocProvider.value(value: _catalog, child: DraftLobbyScreen())
//   BlocProvider.value(value: _catalog, child: DraftAdminScreen())
//
//   // Read anywhere:
//   context.read<DraftCatalogCubit>().state.allCards
//   context.read<DraftCatalogCubit>().state.franchiseNames
//   context.read<DraftCatalogCubit>().state.cardsForFranchises(['Naruto'])
//
//   // Mutate (writes Firebase + updates state in one call):
//   await context.read<DraftCatalogCubit>().addCard(card);
//   await context.read<DraftCatalogCubit>().deleteCard(card);
//   await context.read<DraftCatalogCubit>().addFranchise(name: 'Naruto', ...);
//
// Firebase is hit once per session on load(). Mutations keep state in sync
// so no re-fetches are needed after add/edit/delete operations.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/draft_card.dart';
import '../models/draft_franchise.dart';
import '../models/franchise_category.dart';
import '../models/slot_role.dart';
import '../services/draft_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class DraftCatalogState extends Equatable {
  final bool                 isLoading;
  final List<DraftCard>      allCards;
  final List<DraftFranchise> allFranchises;
  final List<SlotRole>       allSlots;
  final String?              error;

  const DraftCatalogState({
    this.isLoading     = false,
    this.allCards      = const [],
    this.allFranchises = const [],
    this.allSlots      = const [],
    this.error,
  });

  // ── Convenience getters ───────────────────────────────────────────────────

  /// True once both lists are populated and no load is in progress.
  bool get isLoaded => !isLoading && allCards.isNotEmpty;

  /// Effective slots: live Firestore slots, or defaults if none loaded yet.
  List<SlotRole> get effectiveSlots =>
      allSlots.isNotEmpty ? allSlots : SlotRole.defaults;

  /// Flat list of franchise display names (for filter chips, dropdowns, etc.).
  List<String> get franchiseNames =>
      allFranchises.map((f) => f.name).toList();

  /// Subset of [allCards] matching the given franchise names — in-memory filter.
  /// Null or empty list → all cards.
  List<DraftCard> cardsForFranchises(List<String>? names) {
    if (names == null || names.isEmpty) return allCards;
    return allCards.where((c) => names.contains(c.franchiseName)).toList();
  }

  DraftCatalogState copyWith({
    bool?                  isLoading,
    List<DraftCard>?       allCards,
    List<DraftFranchise>?  allFranchises,
    List<SlotRole>?        allSlots,
    String?                error,
    bool                   clearError = false,
  }) {
    return DraftCatalogState(
      isLoading:     isLoading     ?? this.isLoading,
      allCards:      allCards      ?? this.allCards,
      allFranchises: allFranchises ?? this.allFranchises,
      allSlots:      allSlots      ?? this.allSlots,
      error:         clearError    ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [isLoading, allCards, allFranchises, allSlots, error];
}

// ─────────────────────────────────────────────────────────────────────────────
// Cubit
// ─────────────────────────────────────────────────────────────────────────────

class DraftCatalogCubit extends Cubit<DraftCatalogState> {
  DraftCatalogCubit() : super(const DraftCatalogState());

  // ── Load (idempotent) ────────────────────────────────────────────────────

  /// Fetches cards + franchises + slots from Firebase exactly once per session.
  /// Safe to call multiple times — skips if already loaded or in progress.
  Future<void> load() async {
    if (state.isLoaded || state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final results = await Future.wait([
        DraftService.getAllCards(),
        DraftService.getAllFranchises(),
        DraftService.getAllSlots(),
      ]);
      emit(DraftCatalogState(
        allCards:      results[0] as List<DraftCard>,
        allFranchises: results[1] as List<DraftFranchise>,
        allSlots:      results[2] as List<SlotRole>,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  // ── Refresh (force re-fetch) ──────────────────────────────────────────────

  /// Clears cache and re-fetches from Firebase.
  /// Used by admin pull-to-refresh.
  Future<void> refresh() async {
    emit(const DraftCatalogState(isLoading: true));
    try {
      final results = await Future.wait([
        DraftService.getAllCards(),
        DraftService.getAllFranchises(),
        DraftService.getAllSlots(),
      ]);
      emit(DraftCatalogState(
        allCards:      results[0] as List<DraftCard>,
        allFranchises: results[1] as List<DraftFranchise>,
        allSlots:      results[2] as List<SlotRole>,
      ));
    } catch (e) {
      emit(DraftCatalogState(error: e.toString()));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Card mutations — each writes to Firebase then updates state in memory.
  // ══════════════════════════════════════════════════════════════════════════

  /// Adds a card to Firebase and inserts it into the cached list.
  /// Returns the saved card (with its generated Firestore ID).
  Future<DraftCard> addCard(DraftCard card) async {
    final saved = await DraftService.addCard(card);
    emit(state.copyWith(allCards: [...state.allCards, saved]));
    return saved;
  }

  /// Batch-adds cards to Firebase, then refreshes allCards from Firebase
  /// (batch adds are infrequent enough that a single re-fetch is acceptable).
  /// Returns the number of cards saved.
  Future<int> addCards(List<DraftCard> cards) async {
    final count = await DraftService.addCards(cards);
    // Refresh to pick up all generated IDs from the batch write.
    final updated = await DraftService.getAllCards();
    emit(state.copyWith(allCards: updated));
    return count;
  }

  /// Updates a card in Firebase and replaces it in the cached list.
  Future<void> updateCard(DraftCard card) async {
    await DraftService.updateCard(card);
    final updated = [
      for (final c in state.allCards) c.id == card.id ? card : c,
    ];
    emit(state.copyWith(allCards: updated));
  }

  /// Deletes a card from Firebase and removes it from the cached list.
  Future<void> deleteCard(DraftCard card) async {
    await DraftService.deleteCard(card);
    final updated = state.allCards.where((c) => c.id != card.id).toList();
    emit(state.copyWith(allCards: updated));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Franchise mutations — each writes to Firebase then updates state in memory.
  // ══════════════════════════════════════════════════════════════════════════

  /// Adds a franchise to Firebase and inserts it into the cached list.
  /// Returns the new franchise's Firestore ID.
  Future<String> addFranchise({
    required String name,
    required String imageUrl,
    FranchiseCategory category = FranchiseCategory.other,
  }) async {
    final id = await DraftService.addFranchise(
      name: name, imageUrl: imageUrl, category: category);
    final newFranchise = DraftFranchise(
      id:        id,
      name:      name.trim(),
      imageUrl:  imageUrl,
      cardCount: 0,
      category:  category,
    );
    emit(state.copyWith(allFranchises: [...state.allFranchises, newFranchise]));
    return id;
  }

  /// Updates a franchise in Firebase and replaces it in the cached list.
  Future<void> updateFranchise({
    required String            id,
    required String            name,
    required String            imageUrl,
    required FranchiseCategory category,
  }) async {
    await DraftService.updateFranchise(
        id: id, name: name, imageUrl: imageUrl, category: category);
    final updated = [
      for (final f in state.allFranchises)
        f.id == id
            ? DraftFranchise(
                id:        id,
                name:      name.trim(),
                imageUrl:  imageUrl,
                cardCount: f.cardCount,
                category:  category,
              )
            : f,
    ];
    emit(state.copyWith(allFranchises: updated));
  }

  /// Deletes a franchise from Firebase and removes it from the cached list.
  Future<void> deleteFranchise(String id) async {
    await DraftService.deleteFranchise(id);
    final updated = state.allFranchises.where((f) => f.id != id).toList();
    emit(state.copyWith(allFranchises: updated));
  }

  /// Deletes ALL cards belonging to [franchise] (matched by franchiseName)
  /// from Firebase and removes them from the cached card list.
  /// Also resets the franchise's in-memory cardCount to 0.
  /// Returns the number of cards deleted.
  Future<int> deleteCardsForFranchise(DraftFranchise franchise) async {
    final count = await DraftService.deleteCardsForFranchise(
      franchiseName: franchise.name,
    );
    // Remove deleted cards from in-memory list.
    final updatedCards = state.allCards
        .where((c) => c.franchiseName != franchise.name)
        .toList();
    // Reset this franchise's cardCount to 0 in memory.
    final updatedFranchises = [
      for (final f in state.allFranchises)
        f.id == franchise.id
            ? DraftFranchise(
                id:        f.id,
                name:      f.name,
                imageUrl:  f.imageUrl,
                cardCount: 0,
                category:  f.category,
              )
            : f,
    ];
    emit(state.copyWith(
      allCards:      updatedCards,
      allFranchises: updatedFranchises,
    ));
    return count;
  }

  // ── Internal helper: update card-count on a franchise in state ────────────

  void _bumpFranchiseCardCount(String franchiseId, int delta) {
    final updated = [
      for (final f in state.allFranchises)
        f.id == franchiseId
            ? DraftFranchise(
                id:        f.id,
                name:      f.name,
                imageUrl:  f.imageUrl,
                cardCount: (f.cardCount + delta).clamp(0, 999999),
                category:  f.category,
              )
            : f,
    ];
    emit(state.copyWith(allFranchises: updated));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Slot role mutations — write to Firebase then update state in memory.
  // ══════════════════════════════════════════════════════════════════════════

  /// Adds a slot to Firestore (if no duplicate name) and inserts into state.
  /// Returns the saved slot (with its generated Firestore ID), or null if a
  /// slot with the same name already exists.
  Future<SlotRole?> addSlot(SlotRole slot) async {
    // Duplicate check (case-insensitive)
    final exists = state.effectiveSlots.any(
      (s) => s.name.toLowerCase().trim() == slot.name.toLowerCase().trim(),
    );
    if (exists) return null;
    final id = await DraftService.addSlot(slot);
    final saved = slot.copyWith(id: id);
    final updated = [...state.allSlots, saved]
      ..sort((a, b) => a.order.compareTo(b.order));
    emit(state.copyWith(allSlots: updated));
    return saved;
  }

  /// Updates a slot in Firestore and replaces it in state.
  Future<void> updateSlot(SlotRole slot) async {
    await DraftService.updateSlot(slot);
    final updated = [
      for (final s in state.allSlots) s.id == slot.id ? slot : s,
    ]..sort((a, b) => a.order.compareTo(b.order));
    emit(state.copyWith(allSlots: updated));
  }

  /// Deletes a slot from Firestore and removes it from state.
  Future<void> deleteSlot(String slotId) async {
    await DraftService.deleteSlot(slotId);
    final updated = state.allSlots.where((s) => s.id != slotId).toList();
    emit(state.copyWith(allSlots: updated));
  }
}

