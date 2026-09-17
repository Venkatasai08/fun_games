// lib/draftclash/widgets/lobby/pass_and_play_sheet.dart
//
// Bottom sheet for Pass & Play setup.
// Uses FranchiseSpinWheelSheet for multi-series selection (local state).

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';
import '../../cubit/draft_catalog_cubit.dart';
import '../../models/draft_card.dart';
import '../../models/slot_role.dart';
import '../../screens/game_play_screen.dart';
import '../../services/draft_service.dart' hide SlotEffect, SlotRole;
import 'franchise_spin_wheel_sheet.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg = Color(0xFF07070F);
const _raised = Color(0xFF14122A);
const _bdr = Color(0xFF1E1B38);
const _violet = Color(0xFF6E44FF);
const _green = Color(0xFF3ADE80);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

const _kSegColors = [
  Color(0xFF00D4FF),
  Color(0xFFFFD700),
  Color(0xFFFF5A36),
  Color(0xFF00E676),
  Color(0xFFFF4081),
  Color(0xFF7C4DFF),
  Color(0xFF00BFA5),
  Color(0xFFFFAB40),
  Color(0xFF40C4FF),
  Color(0xFFE040FB),
  Color(0xFFB2FF59),
  Color(0xFFFF6E40),
];

class PassAndPlaySheet extends StatefulWidget {
  const PassAndPlaySheet({super.key});

  @override
  State<PassAndPlaySheet> createState() => _PassAndPlaySheetState();
}

class _PassAndPlaySheetState extends State<PassAndPlaySheet> {
  List<String>? _selectedFranchises; // null = all series
  bool _seriesSelected = false;
  List<String> _franchises = [];
  bool _fetchingFranchises = true;
  bool _loading = false;

  // Slot selection
  List<SlotRole> _allSlots = [];
  Map<String, int> _slotCounts = {}; // slot.id → repetition count
  int get _totalSlots => _slotCounts.values.fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load franchises
      final lobbyState = context.read<DraftLobbyBloc>().state;
      if (lobbyState is DraftLobbyLoaded && lobbyState.franchises.isNotEmpty) {
        setState(() {
          _franchises = lobbyState.franchises;
          _fetchingFranchises = false;
        });
      } else {
        DraftService.getFranchises().then((list) {
          if (mounted) {
            setState(() {
              _franchises = list;
              _fetchingFranchises = false;
            });
          }
        });
      }

      // Load slots from cubit (already in memory — no Firebase call)
      final slots = context.read<DraftCatalogCubit>().state.effectiveSlots;
      setState(() {
        _allSlots = slots;
        // Pre-select all by default so game can start with one tap
        _slotCounts = {for (final s in slots) s.id: 1};
      });
    });
  }

  void _openSpinWheel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FranchiseSpinWheelSheet(
        franchises: _franchises,
        currentFranchises: _selectedFranchises,
        onConfirmed: (list) => setState(() {
          _selectedFranchises = list;
          _seriesSelected = true;
        }),
      ),
    );
  }

  void _decrementSlot(SlotRole slot) {
    final count = _slotCounts[slot.id] ?? 0;
    if (count <= 0) return;
    setState(() {
      _slotCounts[slot.id] = (count - 1).clamp(0, 9);
    });
  }

  void _incrementSlot(SlotRole slot) {
    final count = _slotCounts[slot.id] ?? 0;
    if (count >= 9) return;
    setState(() {
      _slotCounts[slot.id] = (count + 1).clamp(0, 9);
    });
  }

  Future<void> _start() async {
    // ── Expand slots by count BEFORE any async gap ─────────────────────────
    // (Reading from Provider after await throws ProviderNotFoundException)
    final selectedSlots = <SlotRole>[];
    for (final slot in _allSlots) {
      final count = _slotCounts[slot.id] ?? 0;
      if (count == 1) {
        selectedSlots.add(slot);
      } else if (count > 1) {
        for (int i = 1; i <= count; i++) {
          selectedSlots.add(slot.copyWith(
            key: '${slot.key}_$i',
            id: '${slot.id}_$i',
          ));
        }
      }
    }

    if (selectedSlots.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          selectedSlots.isEmpty
              ? 'Please add at least 6 board slots to play.'
              : 'Add at least 6 slots (${selectedSlots.length} total so far).',
          style: const TextStyle(color: Color(0xFFEAE8FF)),
        ),
        backgroundColor: const Color(0xFF2A0A1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    setState(() => _loading = true);

    // Fetch cards
    final cards = await DraftService.getAllCards(
      franchises:
          (_selectedFranchises?.isEmpty ?? true) ? null : _selectedFranchises,
    );

    if (!mounted) return;

    if (cards.length < 12) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Not enough cards (need at least 12). Add more cards first.'),
        backgroundColor: Color(0xFF2A0A1E),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final playerNames = _randomPlayerNames(cards);
    final p1Name = playerNames[0];
    final p2Name = playerNames[1];

    // Create a live Firestore room so spectators can watch from the Live Arena.
    // If this fails we still launch the game locally — Firebase sync is
    // best-effort; it must never block the players.
    final result = await DraftService.createPassAndPlayRoom(
      player1Name: p1Name,
      player2Name: p2Name,
      allCards: cards,
      franchises:
          (_selectedFranchises?.isEmpty ?? true) ? null : _selectedFranchises,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    final nav = Navigator.of(context);
    nav.pop(); // close sheet

    // Navigate to GameplayScreen — selectedSlots captured before async gaps.
    nav.push(MaterialPageRoute(
      builder: (_) => GameplayScreen(
        mode: GameplayMode.passAndPlay,
        player1Name: p1Name,
        player2Name: p2Name,
        allCards: cards,
        slots: selectedSlots,
        franchise: _selectedFranchises?.length == 1
            ? _selectedFranchises!.first
            : null,
        // Firebase sync params (null = no sync, game still works offline)
        firebaseRoomId: result?.room.id,
        p1MemberId: result?.p1Member.id,
        p2MemberId: result?.p2Member.id,
        p1FirebaseUid: result?.p1Member.userId,
        p2FirebaseUid: result?.p2Member.userId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.90,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [
            // ── Handle ─────────────────────────────────────────────────
            const SizedBox(height: 12),
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: _bdr, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),

            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3ADE80), Color(0xFF1A7A40)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                          color: _green.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.smartphone_rounded,
                      color: Colors.white, size: 21),
                ),
                const SizedBox(width: 14),
                const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pass & Play',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _txtPri)),
                      Text('Two players · one device · local turns',
                          style: TextStyle(fontSize: 11, color: _txtMut)),
                    ]),
              ]),
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 6),

            // ── Player badges ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _raised,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _bdr),
                ),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const _PlayerPill(label: 'P1', color: _violet),
                  const SizedBox(width: 16),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                          colors: [Color(0xFF9B5CFF), Color(0xFF5E3DB3)]),
                      boxShadow: [
                        BoxShadow(
                            color: _violet.withOpacity(0.4), blurRadius: 12)
                      ],
                    ),
                    child: const Center(
                        child: Text('VS',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                decoration: TextDecoration.none))),
                  ),
                  const SizedBox(width: 16),
                  const _PlayerPill(label: 'P2', color: _green),
                ]),
              ),
            ).animate().fadeIn(delay: 60.ms),

            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                children: [
                  const _SectionLabel(text: 'CARD SERIES'),
                  const SizedBox(height: 10),

                  _fetchingFranchises
                      ? Container(
                          height: 62,
                          decoration: BoxDecoration(
                            color: _raised,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _bdr),
                          ),
                          child: const Center(
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _violet)),
                          ),
                        )
                      : _SeriesPickerButton(
                          selectedCount: _selectedFranchises?.length ?? 0,
                          isSelected: _seriesSelected,
                          hasCards: _franchises.isNotEmpty,
                          onTap: _franchises.isNotEmpty
                              ? () => _openSpinWheel(context)
                              : null,
                        ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: _seriesSelected
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _SelectedFranchisesBanner(
                              franchises:
                                  _selectedFranchises ?? const ['All Series'],
                              allFranchises: _franchises,
                              onClear: () => setState(() {
                                _selectedFranchises = null;
                                _seriesSelected = false;
                              }),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // ── Board Slots ─────────────────────────────────────────────
                  const SizedBox(height: 20),
                  Row(children: [
                    const _SectionLabel(text: 'BOARD SLOTS'),
                    const Spacer(),
                    if (_allSlots.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _totalSlots >= 6
                              ? _green.withOpacity(0.15)
                              : _violet.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _totalSlots >= 6
                                  ? _green.withOpacity(0.5)
                                  : _violet.withOpacity(0.5)),
                        ),
                        child: Text(
                          '$_totalSlots total  •  min 6',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _totalSlots >= 6 ? _green : _violet,
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    _totalSlots >= 6
                        ? 'Long press a chip to add, tap a chip to reduce'
                        : 'Choose at least 6 boards. Long press to add, tap to reduce',
                    style: const TextStyle(fontSize: 10.5, color: _txtMut),
                  ),
                  const SizedBox(height: 10),

                  _allSlots.isEmpty
                      ? Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: _raised,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _bdr),
                          ),
                          child: const Center(
                            child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _violet)),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final slot in _allSlots)
                              _BoardSlotChip(
                                slot: slot,
                                count: _slotCounts[slot.id] ?? 0,
                                onTap: () => _decrementSlot(slot),
                                onLongPress: () => _incrementSlot(slot),
                              ),
                          ],
                        ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _start,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.sports_esports_rounded, size: 20),
                      label: Text(_loading ? 'Loading cards…' : 'Start Draft',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _totalSlots >= 6 ? _green : _green.withOpacity(0.4),
                        foregroundColor: const Color(0xFF001A0A),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ).animate().fadeIn(delay: 140.ms),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ─── Series Picker Button ─────────────────────────────────────────────────────

class _SeriesPickerButton extends StatelessWidget {
  final int selectedCount;
  final bool isSelected;
  final bool hasCards;
  final VoidCallback? onTap;

  const _SeriesPickerButton({
    required this.selectedCount,
    required this.isSelected,
    required this.hasCards,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSel = isSelected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          gradient: hasSel
              ? null
              : LinearGradient(
                  colors: [_green.withOpacity(0.10), _green.withOpacity(0.04)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
          color: hasSel ? _raised : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasSel ? _bdr : _green.withOpacity(0.40),
            width: hasSel ? 1 : 1.5,
          ),
          boxShadow: hasSel
              ? null
              : [
                  BoxShadow(
                      color: _green.withOpacity(0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4))
                ],
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasSel
                    ? [_raised, _raised]
                    : [_green.withOpacity(0.22), _green.withOpacity(0.07)],
              ),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: hasSel ? _bdr : _green.withOpacity(0.4)),
            ),
            child: Icon(Icons.tune_rounded,
                size: 19, color: hasSel ? _txtMut : _green),
          ),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  hasSel ? 'Series Selected' : 'Pick Card Series',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: hasSel ? _green : _txtPri),
                ),
                const SizedBox(height: 2),
                Text(
                  hasSel
                      ? selectedCount > 0
                          ? '$selectedCount series selected'
                          : 'All Series'
                      : 'Choose one or more franchises for this draft',
                  style: const TextStyle(fontSize: 10.5, color: _txtMut),
                ),
              ])),
          Icon(Icons.chevron_right_rounded,
              color: hasSel ? _green : _txtMut, size: 18),
        ]),
      ),
    );
  }
}

// ─── Selected Franchises Banner ───────────────────────────────────────────────

class _SelectedFranchisesBanner extends StatelessWidget {
  final List<String> franchises;
  final List<String> allFranchises;
  final VoidCallback onClear;

  const _SelectedFranchisesBanner({
    required this.franchises,
    required this.allFranchises,
    required this.onClear,
  });

  Color _colorFor(String f) {
    final idx = allFranchises.indexOf(f);
    if (idx >= 0) return _kSegColors[idx % _kSegColors.length];
    return _kSegColors[
        f.codeUnits.fold(0, (a, b) => a ^ b).abs() % _kSegColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final accent = franchises.length == 1
        ? _colorFor(franchises.first)
        : const Color(0xFF7B5CFA);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.10), blurRadius: 12)],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.18),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: accent.withOpacity(0.5)),
          ),
          child: Center(
            child: Text('${franchises.length}',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: accent)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('DRAFT POOL',
                style: TextStyle(
                    fontSize: 9.5,
                    color: _txtMut,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Wrap(
              spacing: 6,
              runSpacing: 3,
              children: [
                ...franchises.take(4).map((f) {
                  final c = _colorFor(f);
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration:
                            BoxDecoration(color: c, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(f,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: c),
                        overflow: TextOverflow.ellipsis),
                  ]);
                }),
                if (franchises.length > 4)
                  Text('+${franchises.length - 4} more',
                      style: const TextStyle(fontSize: 11, color: _txtMut)),
              ],
            ),
          ]),
        ),
        GestureDetector(
          onTap: onClear,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                color: _raised,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _bdr)),
            child: const Icon(Icons.close_rounded, size: 13, color: _txtMut),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.05, end: 0);
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

List<String> _randomPlayerNames(List<DraftCard> cards) {
  final shuffled = [...cards]..shuffle(Random());
  final names = <String>[];

  for (final card in shuffled) {
    final name = card.name.trim();
    if (name.isEmpty || names.contains(name)) continue;
    names.add(name);
    if (names.length == 2) break;
  }

  if (names.isEmpty) return const ['Player 1', 'Player 2'];
  if (names.length == 1) return [names.first, 'Player 2'];
  return names;
}

class _PlayerPill extends StatelessWidget {
  final String label;
  final Color color;
  const _PlayerPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
              decoration: TextDecoration.none)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
              color: _green, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text,
          style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: _txtMut,
              letterSpacing: 1.6,
              decoration: TextDecoration.none)),
    ]);
  }
}

// ─── Slot count stepper row ───────────────────────────────────────────────────

class _BoardSlotChip extends StatelessWidget {
  final SlotRole slot;
  final int count;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BoardSlotChip({
    required this.slot,
    required this.count,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    final accent = slot.isDecrement ? const Color(0xFFE8445A) : _violet;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: count > 0 ? onTap : null,
      onLongPress: count < 9 ? onLongPress : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.fromLTRB(8, 6, 7, 6),
        decoration: BoxDecoration(
          color: active ? accent.withOpacity(0.10) : _raised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? accent.withOpacity(0.48) : _bdr,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [BoxShadow(color: accent.withOpacity(0.10), blurRadius: 12)]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color:
                  active ? accent.withOpacity(0.16) : const Color(0xFF0D0C1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active ? accent.withOpacity(0.55) : _bdr,
              ),
            ),
            child: Icon(_slotIcon(slot),
                size: 15, color: active ? accent : _txtMut),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: Text(
              slot.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: active ? _txtPri : _txtMut,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 9),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Container(
              key: ValueKey(count),
              width: 30,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    active ? accent.withOpacity(0.15) : const Color(0xFF0D0C1E),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: active ? accent.withOpacity(0.55) : _bdr),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: active ? accent : _txtMut,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  static IconData _slotIcon(SlotRole slot) {
    final key = slot.key.split('_').first;
    switch (key) {
      case 'captain':
        return Icons.star_rounded;
      case 'vice':
        return Icons.star_half_rounded;
      case 'tank':
        return Icons.shield_rounded;
      case 'duelist':
        return Icons.flash_on_rounded;
      case 'support':
        return Icons.favorite_rounded;
      case 'traitor':
        return Icons.dangerous_rounded;
      default:
        return slot.isDecrement
            ? Icons.trending_down_rounded
            : Icons.grid_view_rounded;
    }
  }
}
