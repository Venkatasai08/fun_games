// lib/draftclash/screens/pass_and_play_screen.dart
//
// Pass & Play — two players, one device.
// No Firebase reads or writes. Cards + franchises come from DraftCatalogCubit
// (already loaded when the user enters DraftClash). Zero extra Firestore calls.
// Turns alternate; a "Pass the phone" interstitial hides the board between turns.
//
// Game layout uses the same shared widgets as the online DraftClash game:
//   • DraftBoardWidget (versusMode) — identical versus board
//   • GameTimerDial               — identical countdown arc
//   • _PnPPlayerBar               — mirrors online _PlayerBar
//   • _PnPBottomPanel             — mirrors online _BottomPanel
//   • _PnPTopBar                  — mirrors GameTopBar

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'game_play_screen.dart';
import '../cubit/draft_catalog_cubit.dart';
import '../models/board_slot.dart';
import '../models/draft_card.dart';
import '../models/slot_role.dart';
import '../widgets/draft_board_widget.dart';
import '../widgets/game/game_timer_dial.dart';
import '../widgets/lobby/lobby_franchise_chip.dart';

// ── Palette (matches rest of DraftClash) ─────────────────────────────────────
const _ink    = Color(0xFF050510);
const _bg     = Color(0xFF07070F);
const _surf   = Color(0xFF0D0C1E);
const _raised = Color(0xFF14122A);
const _rim    = Color(0xFF1C1A35);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF7B5CFA);
const _amber  = Color(0xFFF4A11D);
const _teal   = Color(0xFF00D4AA);
const _green  = Color(0xFF3ADE80);
const _red    = Color(0xFFE8445A);
const _txtPri = Color(0xFFEAE8FF);
const _txtSub = Color(0xFF7A78A8);
const _txtMut = Color(0xFF6A6898);

// ─────────────────────────────────────────────────────────────────────────────
// 1. SETUP SCREEN — franchise + slots
// ─────────────────────────────────────────────────────────────────────────────

class PassAndPlaySetupScreen extends StatefulWidget {
  const PassAndPlaySetupScreen({super.key});

  @override
  State<PassAndPlaySetupScreen> createState() => _PassAndPlaySetupScreenState();
}

class _PassAndPlaySetupScreenState extends State<PassAndPlaySetupScreen> {
  final Set<String> _selectedFranchises = {};

  // Populated from DraftCatalogCubit — no Firebase call.
  List<String>   _franchises     = [];
  List<SlotRole> _allSlots       = [];
  Map<String, int> _slotCounts = {}; // slot.id → repetition count (0 = excluded)

  // Becomes false only while the catalog is still loading on its very first
  // fetch (edge case — by the time the user reaches this screen the cubit has
  // almost certainly finished). Normal flow: isLoaded == true on entry.
  bool _catalogReady = false;

  StreamSubscription<DraftCatalogState>? _catalogSub;

  @override
  void initState() {
    super.initState();
    _syncFromCatalog();
  }

  /// Reads franchise names directly from the session catalog.
  /// Falls back to a stream subscription if the first load hasn't finished yet.
  void _syncFromCatalog() {
    final catalog = context.read<DraftCatalogCubit>();

    void _applyState(DraftCatalogState s) {
      _franchises      = s.franchiseNames;
      _catalogReady    = true;
      _allSlots        = s.effectiveSlots;
      // Default: each slot appears once.
      _slotCounts = {for (final sl in _allSlots) sl.id: 1};
    }

    if (catalog.state.isLoaded) {
      // Happy path — catalog already loaded, no async needed.
      _applyState(catalog.state);
    } else {
      // Edge case: user arrived before the catalog finished (very unlikely).
      // Subscribe and update the moment data lands.
      _catalogSub = catalog.stream.listen((s) {
        if (s.isLoaded && mounted) {
          setState(() => _applyState(s));
          _catalogSub?.cancel();
          _catalogSub = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _catalogSub?.cancel();
    super.dispose();
  }

  // ── Start ─────────────────────────────────────────────────────────────────
  //
  // Fully synchronous — cards come from the session cache, not Firebase.
  // cardsForFranchises() filters in-memory: O(n) over the cached list.

  void _start() {
    // Expand each slot by its count, giving duplicate slots unique keys.
    // e.g. support ×2 → SlotRole(key:'support_1') + SlotRole(key:'support_2')
    final selectedSlots = <SlotRole>[];
    for (final slot in _allSlots) {
      final count = _slotCounts[slot.id] ?? 0;
      if (count == 1) {
        selectedSlots.add(slot);
      } else if (count > 1) {
        for (int i = 1; i <= count; i++) {
          selectedSlots.add(slot.copyWith(
            key: '${slot.key}_$i',
            id:  '${slot.id}_$i',
          ));
        }
      }
    }

    final total = selectedSlots.length;
    // Require at least 6 total slot instances.
    if (total < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          total == 0
              ? 'Please add at least 6 board slots to play.'
              : 'Add at least 6 slots ($total selected so far).',
          style: const TextStyle(color: Color(0xFFEAE8FF)),
        ),
        backgroundColor: const Color(0xFF2A0A1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    final catalog = context.read<DraftCatalogCubit>();
    final cards = catalog.state.cardsForFranchises(
      _selectedFranchises.isEmpty ? null : _selectedFranchises.toList(),
    );

    if (cards.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Need at least 2 cards to choose player names.'),
        backgroundColor: Color(0xFF2A0A1E),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final playerNames = _randomPlayerNames(cards);
    final p1 = playerNames[0];
    final p2 = playerNames[1];

    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => GameplayScreen(
        mode:        GameplayMode.passAndPlay,
        player1Name: p1,
        player2Name: p2,
        allCards:    cards,
        slots:       selectedSlots,
      ),
    ));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -40, right: -40,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_violet.withOpacity(0.12), Colors.transparent])),
            ),
          ),
          Positioned(
            bottom: -40, left: -40,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_teal.withOpacity(0.08), Colors.transparent])),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Row(children: [
                    _IconBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    const Text(
                      'PASS & PLAY',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _txtPri,
                        letterSpacing: 2.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ]),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Hero banner
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: _surf,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _rim),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const _PlayerBadge(label: 'P1', color: _violet),
                              const SizedBox(width: 20),
                              Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF9B5CFF), Color(0xFF5E3DB3)]),
                                  boxShadow: [
                                    BoxShadow(color: _violet.withOpacity(0.5), blurRadius: 14),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'VS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              const _PlayerBadge(label: 'P2', color: _teal),
                            ],
                          ),
                        ).animate().fadeIn(duration: 400.ms),

                        const SizedBox(height: 28),

                        // Franchise filter
                        const _SectionLabel('CARD SERIES'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _surf,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _rim),
                          ),
                          // Show a tiny spinner only during the rare edge-case
                          // where the catalog hasn't finished loading yet.
                          child: !_catalogReady
                              ? const Center(
                                  child: SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2, color: _violet),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_selectedFranchises.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: Row(children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _violet.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: _violet.withOpacity(0.45)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.check_circle_rounded,
                                                    size: 12, color: _violet),
                                                const SizedBox(width: 5),
                                                Text(
                                                  '${_selectedFranchises.length} selected',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: _violet,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => setState(
                                              () => _selectedFranchises.clear()),
                                            child: const Text(
                                              'Clear all',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: _txtMut,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ]),
                                      ),
                                    Wrap(
                                      spacing: 8, runSpacing: 8,
                                      children: [
                                        LobbyFranchiseChip(
                                          label: 'All Series',
                                          isSelected: _selectedFranchises.isEmpty,
                                          onTap: () => setState(
                                            () => _selectedFranchises.clear()),
                                        ),
                                        ..._franchises.map((f) => LobbyFranchiseChip(
                                          label: f,
                                          isSelected: _selectedFranchises.contains(f),
                                          onTap: () => setState(() {
                                            if (_selectedFranchises.contains(f)) {
                                              _selectedFranchises.remove(f);
                                            } else {
                                              _selectedFranchises.add(f);
                                            }
                                          }),
                                        )),
                                      ],
                                    ),
                                  ],
                                ),
                        ).animate().fadeIn(delay: 120.ms),

                        const SizedBox(height: 28),

                        // Board slots stepper
                        Builder(builder: (ctx) {
                          final total = _slotCounts.values.fold(0, (a, b) => a + b);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Section label inline
                                  Row(children: [
                                    Container(
                                      width: 3, height: 12,
                                      decoration: BoxDecoration(
                                        color: _violet,
                                        borderRadius: BorderRadius.circular(2))),
                                    const SizedBox(width: 8),
                                    const Text('BOARD SLOTS',
                                      style: TextStyle(
                                        fontSize: 10.5, fontWeight: FontWeight.w700,
                                        color: _txtSub, letterSpacing: 1.6,
                                        decoration: TextDecoration.none)),
                                  ]),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: total >= 6
                                          ? _teal.withOpacity(0.12)
                                          : _red.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: total >= 6
                                            ? _teal.withOpacity(0.4)
                                            : _red.withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      '$total slot${total == 1 ? '' : 's'}'  
                                      '${total < 6 ? '  •  min 6' : ''}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: total >= 6 ? _teal : _red,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: _surf,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _rim),
                                ),
                                child: !_catalogReady
                                    ? const Padding(
                                        padding: EdgeInsets.all(20),
                                        child: Center(child: SizedBox(
                                          width: 20, height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2, color: _violet),
                                        )),
                                      )
                                    : Column(
                                        children: _allSlots
                                            .asMap()
                                            .entries
                                            .map((e) {
                                              final isLast =
                                                  e.key == _allSlots.length - 1;
                                              final slot  = e.value;
                                              final count =
                                                  _slotCounts[slot.id] ?? 0;
                                              return _SlotCountRow(
                                                slot: slot,
                                                count: count,
                                                isLast: isLast,
                                                onDecrement: () => setState(() {
                                                  _slotCounts[slot.id] =
                                                      (count - 1).clamp(0, 9);
                                                }),
                                                onIncrement: () => setState(() {
                                                  _slotCounts[slot.id] =
                                                      (count + 1).clamp(0, 9);
                                                }),
                                              );
                                            })
                                            .toList(),
                                      ),
                              ),
                            ],
                          );
                        }).animate().fadeIn(delay: 160.ms),

                        const SizedBox(height: 36),

                        // Start button
                        Builder(builder: (ctx) {
                          final total =
                              _slotCounts.values.fold(0, (a, b) => a + b);
                          final ready = _catalogReady && total >= 6;
                          return SizedBox(
                            width: double.infinity, height: 56,
                            child: ElevatedButton.icon(
                              onPressed: ready ? _start : null,
                              icon: const Icon(
                                Icons.sports_esports_rounded, size: 22),
                              label: Text(
                                ready
                                    ? 'Start Draft'
                                    : total < 6
                                        ? 'Need ${6 - total} more slot${(6 - total) == 1 ? '' : 's'}'
                                        : 'Loading…',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _violet,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                            ),
                          );
                        }).animate().fadeIn(delay: 220.ms),
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. LOCAL GAME SCREEN — no Firebase reads or writes
// ─────────────────────────────────────────────────────────────────────────────

class PassAndPlayGameScreen extends StatefulWidget {
  final String player1Name;
  final String player2Name;
  final List<DraftCard> allCards;

  const PassAndPlayGameScreen({
    super.key,
    required this.player1Name,
    required this.player2Name,
    required this.allCards,
  });

  @override
  State<PassAndPlayGameScreen> createState() => _PassAndPlayGameScreenState();
}

class _PassAndPlayGameScreenState extends State<PassAndPlayGameScreen> {
  static const int _turnSecs = 15;
  static const int _deckMax  = 50;

  late List<DraftCard> _deck;
  DraftCard? _currentCard;

  late Map<String, DraftCard?> _board1;
  late Map<String, DraftCard?> _board2;

  double _score1 = 0;
  double _score2 = 0;

  int _currentPlayer = 1;
  bool _hasSkipped1 = false;
  bool _hasSkipped2 = false;

  int _countdown = _turnSecs;
  Timer? _timer;

  String _phase = 'pass';

  bool get _isP1Turn       => _currentPlayer == 1;
  String get _currentName  => _isP1Turn ? widget.player1Name : widget.player2Name;
  String get _opponentName => _isP1Turn ? widget.player2Name : widget.player1Name;
  Color  get _currentColor  => _isP1Turn ? _violet : _teal;
  Color  get _opponentColor => _isP1Turn ? _teal   : _violet;
  bool   get _currentSkipped => _isP1Turn ? _hasSkipped1 : _hasSkipped2;
  Map<String, DraftCard?> get _myBoard  => _isP1Turn ? _board1 : _board2;
  Map<String, DraftCard?> get _oppBoard => _isP1Turn ? _board2 : _board1;
  double get _myScore  => _isP1Turn ? _score1 : _score2;
  double get _oppScore => _isP1Turn ? _score2 : _score1;

  @override
  void initState() {
    super.initState();
    _board1 = {for (final s in BoardSlot.ordered) s.key: null};
    _board2 = {for (final s in BoardSlot.ordered) s.key: null};
    _initDeck();
  }

  void _initDeck() {
    final shuffled = List<DraftCard>.from(widget.allCards)..shuffle(Random());
    _deck = shuffled.take(_deckMax).toList();
    _drawNext();
  }

  void _drawNext() {
    if (_deck.isEmpty) { _endGame(); return; }
    _currentCard = _deck.removeAt(0);
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _countdown = _turnSecs);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        _timer?.cancel();
        _autoAssign();
      }
    });
  }

  void _stopTimer() => _timer?.cancel();

  void _pickSlot(BoardSlot slot) {
    if (_currentCard == null) return;
    final board = _myBoard;
    if (board[slot.key] != null) return;
    _stopTimer();
    setState(() {
      board[slot.key] = _currentCard;
      if (_isP1Turn) _score1 += _currentCard!.level;
      else           _score2 += _currentCard!.level;
      _currentCard = null;
    });
    HapticFeedback.mediumImpact();
    _advanceTurn();
  }

  void _skipCard() {
    if (_currentSkipped) return;
    if (_currentCard == null) return;
    _stopTimer();
    setState(() {
      if (_isP1Turn) _hasSkipped1 = true;
      else           _hasSkipped2 = true;
      _currentCard = null;
    });
    _advanceTurn();
  }

  void _autoAssign() {
    if (_currentCard == null) return;
    final board = _myBoard;
    final emptySlot = BoardSlot.ordered.firstWhere(
      (s) => board[s.key] == null,
      orElse: () => BoardSlot.ordered.first,
    );
    if (board[emptySlot.key] != null) { _advanceTurn(); return; }
    setState(() {
      board[emptySlot.key] = _currentCard;
      if (_isP1Turn) _score1 += _currentCard!.level;
      else           _score2 += _currentCard!.level;
      _currentCard = null;
    });
    HapticFeedback.lightImpact();
    _advanceTurn();
  }

  void _advanceTurn() {
    final allFull = BoardSlot.ordered.every((s) => _board1[s.key] != null)
        && BoardSlot.ordered.every((s) => _board2[s.key] != null);
    if (allFull || (_deck.isEmpty && _currentCard == null)) {
      _endGame();
      return;
    }
    _drawNext();
    setState(() {
      _currentPlayer = _currentPlayer == 1 ? 2 : 1;
      _phase = 'pass';
    });
  }

  void _onPassConfirmed() {
    setState(() => _phase = 'play');
    _startTimer();
  }

  void _endGame() {
    _stopTimer();
    setState(() => _phase = 'result');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: switch (_phase) {
          'pass' => _PassScreen(
              playerName:  _currentName,
              playerColor: _currentColor,
              onReady:     _onPassConfirmed,
            ),
          'result' => _ResultScreen(
              p1Name:  widget.player1Name,
              p2Name:  widget.player2Name,
              score1:  _score1,
              score2:  _score2,
              board1:  _board1,
              board2:  _board2,
              onRematch: () {
                setState(() {
                  _board1 = {for (final s in BoardSlot.ordered) s.key: null};
                  _board2 = {for (final s in BoardSlot.ordered) s.key: null};
                  _score1 = 0; _score2 = 0;
                  _hasSkipped1 = false; _hasSkipped2 = false;
                  _currentPlayer = 1;
                  _initDeck();
                  _phase = 'pass';
                });
              },
            ),
          _ => _PlayScreen(
              currentCard:   _currentCard,
              currentPlayer: _currentPlayer,
              currentName:   _currentName,
              opponentName:  _opponentName,
              currentColor:  _currentColor,
              opponentColor: _opponentColor,
              myBoard:    _myBoard,
              oppBoard:   _oppBoard,
              myScore:    _myScore,
              oppScore:   _oppScore,
              countdown:  _countdown,
              skipUsed:   _currentSkipped,
              onPickSlot: _pickSlot,
              onSkip:     _skipCard,
              onBack:     () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pass-the-phone interstitial
// ─────────────────────────────────────────────────────────────────────────────

class _PassScreen extends StatelessWidget {
  final String playerName;
  final Color playerColor;
  final VoidCallback onReady;
  const _PassScreen({
    required this.playerName,
    required this.playerColor,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: playerColor.withOpacity(0.12),
            border: Border.all(color: playerColor.withOpacity(0.55), width: 2),
            boxShadow: [
              BoxShadow(color: playerColor.withOpacity(0.35), blurRadius: 30),
            ],
          ),
          child: Icon(Icons.smartphone_rounded, color: playerColor, size: 42),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

        const SizedBox(height: 24),
        const Text(
          'Pass to',
          style: TextStyle(
            fontSize: 16, color: _txtSub, decoration: TextDecoration.none),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 6),
        Text(
          playerName,
          style: TextStyle(
            fontSize: 30, fontWeight: FontWeight.w900,
            color: playerColor, decoration: TextDecoration.none),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
        const SizedBox(height: 8),
        const Text(
          'Hand the phone over, then tap Ready',
          style: TextStyle(
            fontSize: 13, color: _txtSub, decoration: TextDecoration.none),
        ).animate().fadeIn(delay: 400.ms),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
          child: SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: onReady,
              style: ElevatedButton.styleFrom(
                backgroundColor: playerColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                "I'm Ready — Show my turn",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ).animate().fadeIn(delay: 500.ms),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active play screen
// ─────────────────────────────────────────────────────────────────────────────

class _PlayScreen extends StatelessWidget {
  final DraftCard? currentCard;
  final int currentPlayer;
  final String currentName;
  final String opponentName;
  final Color currentColor;
  final Color opponentColor;
  final Map<String, DraftCard?> myBoard;
  final Map<String, DraftCard?> oppBoard;
  final double myScore;
  final double oppScore;
  final int countdown;
  final bool skipUsed;
  final void Function(BoardSlot) onPickSlot;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  const _PlayScreen({
    required this.currentCard,
    required this.currentPlayer,
    required this.currentName,
    required this.opponentName,
    required this.currentColor,
    required this.opponentColor,
    required this.myBoard,
    required this.oppBoard,
    required this.myScore,
    required this.oppScore,
    required this.countdown,
    required this.skipUsed,
    required this.onPickSlot,
    required this.onSkip,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PnPTopBar(onBack: onBack),
        _PnPPlayerBar(
          name:       opponentName,
          score:      oppScore.toInt(),
          accent:     opponentColor,
          isActive:   false,
          isOpponent: true,
        ).animate().fadeIn(duration: 300.ms),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: DraftBoardWidget(
              cardMap:     const {},
              versusMode:  true,
              leftMap:     oppBoard,
              rightMap:    myBoard,
              interactive: currentCard != null,
              isMyTurn:    true,
              onSlotTapped: onPickSlot,
            ),
          ),
        ),
        _PnPBottomPanel(
          currentCard:  currentCard,
          countdown:    countdown,
          skipUsed:     skipUsed,
          currentColor: currentColor,
          onSkip:       onSkip,
        ),
        _PnPPlayerBar(
          name:       currentName,
          score:      myScore.toInt(),
          accent:     currentColor,
          isActive:   true,
          isOpponent: false,
        ).animate().fadeIn(duration: 300.ms),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PnPTopBar
// ─────────────────────────────────────────────────────────────────────────────

class _PnPTopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _PnPTopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surf,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _bdr)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _raised,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _bdr),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: _txtMut, size: 17),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pass & Play',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                      color: _txtPri)),
              Text('Local draft — no internet needed',
                  style: TextStyle(fontSize: 10, color: _txtMut)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: _raised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _bdr),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.people_rounded, size: 11, color: _txtMut),
            SizedBox(width: 5),
            Text('1 device',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: _txtMut)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PnPPlayerBar
// ─────────────────────────────────────────────────────────────────────────────

class _PnPPlayerBar extends StatelessWidget {
  final String name;
  final int    score;
  final Color  accent;
  final bool   isActive;
  final bool   isOpponent;

  const _PnPPlayerBar({
    required this.name,
    required this.score,
    required this.accent,
    required this.isActive,
    required this.isOpponent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? accent.withOpacity(0.07) : _surf,
        border: Border(
          top:    isOpponent ? BorderSide.none
              : BorderSide(color: isActive ? accent.withOpacity(0.35) : _bdr),
          bottom: isOpponent
              ? BorderSide(color: isActive ? accent.withOpacity(0.35) : _bdr)
              : BorderSide.none,
        ),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withOpacity(0.12),
            border: Border.all(
              color: accent.withOpacity(isActive ? 0.6 : 0.25), width: 1.5),
            boxShadow: isActive
                ? [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 8)]
                : null,
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: accent.withOpacity(isActive ? 0.95 : 0.55)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: isActive ? _txtPri : _txtMut),
          ),
        ),
        if (isActive) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent.withOpacity(0.4)),
            ),
            child: Text(
              isOpponent ? 'PICKING' : 'YOUR TURN',
              style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w900,
                color: accent, letterSpacing: 1),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withOpacity(0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.star_rounded, size: 11, color: accent),
            const SizedBox(width: 4),
            Text('$score',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900, color: accent)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PnPBottomPanel
// ─────────────────────────────────────────────────────────────────────────────

class _PnPBottomPanel extends StatelessWidget {
  final DraftCard? currentCard;
  final int countdown;
  final bool skipUsed;
  final Color currentColor;
  final VoidCallback onSkip;

  const _PnPBottomPanel({
    required this.currentCard,
    required this.countdown,
    required this.skipUsed,
    required this.currentColor,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _surf,
        border: const Border(
          top: BorderSide(color: _bdr), bottom: BorderSide(color: _bdr)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 60, height: 60,
            child: GameTimerDial(seconds: countdown),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: currentCard != null
                ? _PnPCardPreview(card: currentCard!, isMyTurn: true)
                : Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: _raised, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _bdr),
                    ),
                    child: Center(
                      child: Text('No more cards',
                          style: TextStyle(
                            fontSize: 11,
                            color: _txtMut.withOpacity(0.55))),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          _PnPSkipButton(used: skipUsed, onSkip: onSkip),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PnPCardPreview
// ─────────────────────────────────────────────────────────────────────────────

Color _tierGlow(double level) {
  if (level >= 9) return const Color(0xFFFFAA00);
  if (level >= 7) return const Color(0xFFBB6CFF);
  if (level >= 4) return const Color(0xFF38C7FF);
  return const Color(0xFF3ADE80);
}

class _PnPCardPreview extends StatelessWidget {
  final DraftCard card;
  final bool isMyTurn;
  const _PnPCardPreview({required this.card, required this.isMyTurn});

  @override
  Widget build(BuildContext context) {
    final glow = _tierGlow(card.level);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 60,
      decoration: BoxDecoration(
        color: glow.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: glow.withOpacity(isMyTurn ? 0.6 : 0.25),
          width: isMyTurn ? 1.5 : 1,
        ),
        boxShadow: isMyTurn
            ? [BoxShadow(color: glow.withOpacity(0.25), blurRadius: 14)]
            : null,
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(11),
            bottomLeft: Radius.circular(11)),
          child: SizedBox(
            width: 60, height: 60,
            child: card.imageUrl.isNotEmpty
                ? Image.network(card.imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _initial(glow))
                : _initial(glow),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMyTurn ? 'ON TABLE' : 'CURRENT CARD',
                style: TextStyle(
                  fontSize: 8.5, fontWeight: FontWeight.w700,
                  color: glow.withOpacity(0.55), letterSpacing: 1.2),
              ),
              const SizedBox(height: 3),
              Text(
                card.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: _txtPri)),
              if (card.franchiseName.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  card.franchiseName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9, color: glow.withOpacity(0.5),
                    letterSpacing: 0.6, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 10),
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: glow.withOpacity(0.15),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: glow.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(color: glow.withOpacity(0.2), blurRadius: 8)],
          ),
          child: Center(
            child: Text(
              '${card.level.toInt()}',
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: glow)),
          ),
        ),
      ]),
    )
        .animate()
        .scaleXY(begin: 0.94, duration: 280.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 180.ms);
  }

  Widget _initial(Color glow) => Container(
    color: glow.withOpacity(0.08),
    child: Center(
      child: Text(
        card.name.isNotEmpty ? card.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w900,
          color: glow.withOpacity(0.25)))));
}

// ─────────────────────────────────────────────────────────────────────────────
// _PnPSkipButton
// ─────────────────────────────────────────────────────────────────────────────

class _PnPSkipButton extends StatelessWidget {
  final bool used;
  final VoidCallback onSkip;
  const _PnPSkipButton({required this.used, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: used ? null : onSkip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: used ? _raised : _amber.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: used ? _bdr : _amber.withOpacity(0.45),
            width: used ? 1 : 1.5,
          ),
          boxShadow: used
              ? null
              : [BoxShadow(color: _amber.withOpacity(0.18), blurRadius: 10)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              used ? Icons.block_rounded : Icons.skip_next_rounded,
              size: 18,
              color: used ? _txtMut.withOpacity(0.35) : _amber,
            ),
            const SizedBox(height: 3),
            Text(
              used ? 'USED' : 'SKIP',
              style: TextStyle(
                fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.8,
                color: used ? _txtMut.withOpacity(0.35) : _amber),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result screen
// ─────────────────────────────────────────────────────────────────────────────

class _ResultScreen extends StatelessWidget {
  final String p1Name;
  final String p2Name;
  final double score1;
  final double score2;
  final Map<String, DraftCard?> board1;
  final Map<String, DraftCard?> board2;
  final VoidCallback onRematch;

  const _ResultScreen({
    required this.p1Name,
    required this.p2Name,
    required this.score1,
    required this.score2,
    required this.board1,
    required this.board2,
    required this.onRematch,
  });

  @override
  Widget build(BuildContext context) {
    final p1Win  = score1 > score2;
    final p2Win  = score2 > score1;
    final isDraw = score1 == score2;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: _surf, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _rim),
          ),
          child: Column(children: [
            Text(
              isDraw ? '🤝 DRAW!' : '🏆 WINNER!',
              style: const TextStyle(
                fontSize: 14, color: _txtSub,
                letterSpacing: 2, decoration: TextDecoration.none),
            ),
            const SizedBox(height: 6),
            Text(
              isDraw
                  ? 'Both scored ${score1.toStringAsFixed(1)}'
                  : (p1Win ? p1Name : p2Name),
              style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900,
                color: isDraw ? _amber : (p1Win ? _violet : _teal),
                decoration: TextDecoration.none),
            ),
          ]),
        ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.95, 0.95)),

        const SizedBox(height: 20),

        Row(children: [
          Expanded(child: _ScoreCard(
            name: p1Name, score: score1, color: _violet, isWinner: p1Win)),
          const SizedBox(width: 10),
          Expanded(child: _ScoreCard(
            name: p2Name, score: score2, color: _teal, isWinner: p2Win)),
        ]).animate().fadeIn(delay: 200.ms).slideY(begin: 0.08),

        const SizedBox(height: 20),

        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _BoardSummary(name: p1Name, color: _violet, board: board1)),
          const SizedBox(width: 10),
          Expanded(child: _BoardSummary(name: p2Name, color: _teal, board: board2)),
        ]).animate().fadeIn(delay: 300.ms),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: onRematch,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Rematch',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _violet,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ).animate().fadeIn(delay: 400.ms),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Text('Exit to Lobby',
              style: TextStyle(color: _txtSub, decoration: TextDecoration.none)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widget helpers
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final String name;
  final double score;
  final Color color;
  final bool isWinner;
  const _ScoreCard({
    required this.name, required this.score,
    required this.color, required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWinner ? color.withOpacity(0.1) : _surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner ? color.withOpacity(0.5) : _rim,
          width: isWinner ? 1.5 : 1),
      ),
      child: Column(children: [
        if (isWinner)
          const Icon(Icons.emoji_events_rounded, color: _amber, size: 18),
        Text(name,
            style: const TextStyle(fontSize: 12, color: _txtSub,
                decoration: TextDecoration.none),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(score.toStringAsFixed(1),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                color: color, decoration: TextDecoration.none)),
        const Text('pts',
            style: TextStyle(fontSize: 11, color: _txtSub,
                decoration: TextDecoration.none)),
      ]),
    );
  }
}

class _BoardSummary extends StatelessWidget {
  final String name;
  final Color color;
  final Map<String, DraftCard?> board;
  const _BoardSummary({
    required this.name, required this.color, required this.board});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surf, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _rim),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: color, letterSpacing: 0.5,
                decoration: TextDecoration.none)),
        const SizedBox(height: 8),
        ...BoardSlot.ordered.map((slot) {
          final card = board[slot.key];
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              Text(slot.label,
                  style: const TextStyle(fontSize: 10, color: _txtSub,
                      decoration: TextDecoration.none)),
              const Spacer(),
              if (card != null) ...[
                Text(card.name,
                    style: const TextStyle(fontSize: 10, color: _txtPri,
                        decoration: TextDecoration.none),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(width: 4),
                Text(card.levelDisplay,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                        color: color, decoration: TextDecoration.none)),
              ] else
                const Text('—',
                    style: TextStyle(fontSize: 10, color: _txtSub,
                        decoration: TextDecoration.none)),
            ]),
          );
        }),
      ]),
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PlayerBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.25), blurRadius: 16)],
      ),
      child: Center(
        child: Text(label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
              color: color, decoration: TextDecoration.none)),
      ),
    );
  }
}

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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 3, height: 12,
        decoration: BoxDecoration(
          color: _violet, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text,
          style: const TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w700,
            color: _txtSub, letterSpacing: 1.6,
            decoration: TextDecoration.none)),
    ]);
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
          color: _surf, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _rim),
        ),
        child: Icon(icon, size: 17, color: _txtSub),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Slot count stepper row — used in the setup screen
// ─────────────────────────────────────────────────────────────────────────────

class _SlotCountRow extends StatelessWidget {
  final SlotRole    slot;
  final int         count;
  final bool        isLast;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _SlotCountRow({
    required this.slot,
    required this.count,
    required this.isLast,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _bdr, width: 0.8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          // Slot name + role icon
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: active
                        ? _violet.withOpacity(0.15)
                        : _surf,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active
                          ? _violet.withOpacity(0.45)
                          : _rim),
                  ),
                  child: Icon(
                    _iconFor(slot.key),
                    size: 16,
                    color: active ? _violet : _txtMut,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: active ? _txtPri : _txtMut,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (slot.isDecrement)
                      const Text(
                        'traitor effect',
                        style: TextStyle(
                          fontSize: 10, color: _red,
                          decoration: TextDecoration.none),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Stepper: [−]  count  [+]
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepBtn(
                icon: Icons.remove_rounded,
                enabled: count > 0,
                onTap: onDecrement,
              ),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Container(
                  key: ValueKey(count),
                  width: 36, height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? _violet.withOpacity(0.18)
                        : _raised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active
                          ? _violet.withOpacity(0.5)
                          : _rim),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: active ? _violet : _txtMut,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _StepBtn(
                icon: Icons.add_rounded,
                enabled: count < 9,
                onTap: onIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String key) {
    final k = key.split('_').first;
    switch (k) {
      case 'captain':      return Icons.star_rounded;
      case 'vice':         return Icons.star_half_rounded;
      case 'tank':         return Icons.shield_rounded;
      case 'duelist':      return Icons.flash_on_rounded;
      case 'support':      return Icons.favorite_rounded;
      case 'traitor':      return Icons.dangerous_rounded;
      default:             return Icons.person_rounded;
    }
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: enabled ? _violet.withOpacity(0.18) : _raised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? _violet.withOpacity(0.5) : _rim),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? _violet : _txtMut,
        ),
      ),
    );
  }
}
