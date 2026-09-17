// lib/draftclash/screens/gameplay_screen.dart
//
// Unified DraftClash Gameplay Screen — FULLY RESPONSIVE
// ────────────────────────────────────────────────────────────────────────────
// Draw flow:
//   Tap DRAW → card appears in the bottom panel (image + name, draggable)
//   Tap any empty slot on YOUR side → card placed there
//   Drag card to any empty slot     → card placed there (DragTarget)
//   Board slots highlight with + icon while card awaits placement

import 'dart:async';
import 'dart:math' as math;
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/draft_card.dart';
import '../models/slot_role.dart';
import '../services/draft_service.dart';


// ── Palette ───────────────────────────────────────────────────────────────────
const _ink = Color(0xFF050510);
const _bg = Color(0xFF07070F);
const _surf = Color(0xFF0D0C1E);
const _raised = Color(0xFF14122A);
const _rim = Color(0xFF1C1A35);
const _bdr = Color(0xFF1E1B38);
const _violet = Color(0xFF7B5CFA);
const _teal = Color(0xFF00D4AA);
const _amber = Color(0xFFF4A11D);
const _txtPri = Color(0xFFEAE8FF);
const _txtSub = Color(0xFF7A78A8);
const _txtMut = Color(0xFF6A6898);

// ─────────────────────────────────────────────────────────────────────────────
// _R — Responsive helper  (baseline: 390 px wide)
// ─────────────────────────────────────────────────────────────────────────────
class _R {
  final double s;
  const _R(this.s);
  factory _R.of(BuildContext ctx) =>
      _R((MediaQuery.sizeOf(ctx).width / 390.0).clamp(0.80, 1.30));

  double get backBtn => _r(30);
  double get timerSize => _r(38);
  double get deckCardW => _r(60);
  double get deckCardH => _r(76);
  double get deckW => _r(66);
  double get deckH => _r(76);

  double get fsTimer => (_r(12)).clamp(9, 16);
  double get fsScore => (_r(14)).clamp(10, 18);
  double get fsScoreLbl => (_r(9)).clamp(7, 12);
  double get fsSlotIcon => (_r(13)).clamp(10, 17);
  double get fsSlotLbl => (_r(8)).clamp(6, 11);
  double get fsDeckLbl => (_r(8)).clamp(6, 10);
  double get fsDeckCount => (_r(10)).clamp(8, 13);
  double get fsFranchise => (_r(7)).clamp(5.5, 9);
  double get fsMode => (_r(7.5)).clamp(6, 10);

  double get hPadTop => _r(10).clamp(7, 16);
  double get vPadTop => _r(5).clamp(3, 8);
  double get boardHPad => _r(12).clamp(8, 20);
  double get boardVPad => _r(10).clamp(6, 14);
  double get rowVPad => _r(4).clamp(2, 7);
  double get deckHPad => _r(16).clamp(12, 24);
  double get deckVPad => _r(10).clamp(6, 14);

  double sp(double v) => v * s;
  double _r(double v) => v * s;
}

// ── Game Mode ─────────────────────────────────────────────────────────────────
enum GameplayMode { quickMatch, passAndPlay, playWithFriend }

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────
class GameplayScreen extends StatefulWidget {
  final GameplayMode mode;
  final String player1Name;
  final String player2Name;
  final Color player1Color;
  final Color player2Color;
  final List<DraftCard> allCards;
  final String? franchise;

  /// Dynamic board slot roles — fetched from Firestore via cubit before
  /// navigating here. Falls back to [SlotRole.defaults] if not provided.
  final List<SlotRole> slots;

  // ── Optional Firebase sync (Pass & Play spectator support) ────────────────
  // When these are provided the game is mirrored to Firestore after every
  // move so spectators watching from the Live Arena see the live state.
  // Local gameplay logic is completely unchanged — these are write-only.
  final String? firebaseRoomId; // Firestore room doc ID
  final String? p1MemberId; // Firestore member doc ID for P1
  final String? p2MemberId; // Firestore member doc ID for P2
  final String? p1FirebaseUid; // uid written to current_turn for P1
  final String? p2FirebaseUid; // uid written to current_turn for P2

  const GameplayScreen({
    super.key,
    required this.mode,
    required this.player1Name,
    required this.player2Name,
    required this.allCards,
    List<SlotRole>? slots,
    this.franchise,
    this.player1Color = _violet,
    this.player2Color = _teal,
    this.firebaseRoomId,
    this.p1MemberId,
    this.p2MemberId,
    this.p1FirebaseUid,
    this.p2FirebaseUid,
  }) : slots = slots ?? const [];

  /// Effective slots: live slots or defaults if none provided.
  List<SlotRole> get effectiveSlots =>
      slots.isNotEmpty ? slots : SlotRole.defaults;

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────
class _GameplayScreenState extends State<GameplayScreen>
    with TickerProviderStateMixin {
  late List<DraftCard> _deck;

  /// Boards are keyed by SlotRole.key (String), not the old BoardSlot enum.
  late Map<String, DraftCard?> _board1;
  late Map<String, DraftCard?> _board2;

  double _score1 = 0;
  double _score2 = 0;
  int _currentPlayer = 1;
  DraftCard? _revealedCard;
  bool _showReveal = false;
  bool _gameOver = false;
  // Each player gets exactly ONE skip per game
  bool _p1SkipUsed = false;
  bool _p2SkipUsed = false;
  bool get _curSkipUsed => _isP1Turn ? _p1SkipUsed : _p2SkipUsed;

  static const int _turnSecs = 45;
  int _countdown = _turnSecs;
  Timer? _turnTimer;

  late AnimationController _deckMoveCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _revealCtrl; // fades in/out the drawn-card panel
  late AnimationController _slotFillCtrl;

  late Animation<double> _deckMoveAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _revealFadeAnim;

  bool get _isP1Turn => _currentPlayer == 1;
  String get _curName => _isP1Turn ? widget.player1Name : widget.player2Name;
  String get _oppName => _isP1Turn ? widget.player2Name : widget.player1Name;
  Color get _curColor => _isP1Turn ? widget.player1Color : widget.player2Color;
  Color get _oppColor => _isP1Turn ? widget.player2Color : widget.player1Color;

  Map<String, DraftCard?> get _myBoard => _isP1Turn ? _board1 : _board2;
  Map<String, DraftCard?> get _oppBoard => _isP1Turn ? _board2 : _board1;

  /// Shorthand for the effective slot list.
  List<SlotRole> get _slots => widget.effectiveSlots;

  @override
  void initState() {
    super.initState();
    // Initialize boards from dynamic slot list
    _board1 = {for (final s in _slots) s.key: null};
    _board2 = {for (final s in _slots) s.key: null};
    _initDeck();

    _deckMoveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _deckMoveAnim =
        CurvedAnimation(parent: _deckMoveCtrl, curve: Curves.easeInOutCubic);

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.25, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // Panel fade: 380 ms in, reverse on placement
    _revealCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _revealFadeAnim =
        CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOut);

    _slotFillCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _deckMoveCtrl.value = 1.0;
    _startTurnTimer();
  }

  @override
  void dispose() {
    _deckMoveCtrl.dispose();
    _glowCtrl.dispose();
    _revealCtrl.dispose();
    _slotFillCtrl.dispose();
    _turnTimer?.cancel();
    super.dispose();
  }

  void _initDeck() {
    final shuffled = List<DraftCard>.from(widget.allCards)..shuffle(Random());
    _deck = shuffled.take(50).toList();
  }

  // ── Firebase sync (fire-and-forget, never blocks the UI) ──────────────────

  bool get _hasFirebaseSync =>
      widget.firebaseRoomId != null &&
      widget.p1MemberId != null &&
      widget.p2MemberId != null &&
      widget.p1FirebaseUid != null &&
      widget.p2FirebaseUid != null;

  /// Called after every board change. Writes live state to Firestore so
  /// spectators in the Live Arena see the current board. Does not await.
  void _syncBoardToFirestore() {
    if (!_hasFirebaseSync) return;
    // _advanceTurn() has already flipped _currentPlayer so _isP1Turn now
    // reflects who JUST received the turn.
    final nextTurnUid = _isP1Turn
        ? widget.p1FirebaseUid!
        : widget.p2FirebaseUid!;
    DraftService.pnpSyncBoard(
      roomId:        widget.firebaseRoomId!,
      p1MemberId:    widget.p1MemberId!,
      p2MemberId:    widget.p2MemberId!,
      p1Board:       _board1,
      p2Board:       _board2,
      currentTurnId: nextTurnUid,
      currentCardId: _revealedCard?.id,
    );
  }

  /// Called when the game ends. Writes final state to Firestore.
  void _syncFinishToFirestore() {
    if (!_hasFirebaseSync) return;
    final p1Won  = _score1 > _score2;
    final isDraw = _score1 == _score2;
    DraftService.pnpFinishGame(
      roomId:          widget.firebaseRoomId!,
      p1MemberId:      widget.p1MemberId!,
      p2MemberId:      widget.p2MemberId!,
      p1Board:         _board1,
      p2Board:         _board2,
      winnerId:        isDraw ? null : (p1Won ? widget.p1FirebaseUid : widget.p2FirebaseUid),
      winnerUsername:  isDraw ? null : (p1Won ? widget.player1Name  : widget.player2Name),
    );
  }

  void _syncForfeitToFirestore() {
    if (!_hasFirebaseSync) return;
    final winnerIsP1 = !_isP1Turn;
    DraftService.pnpFinishGame(
      roomId:          widget.firebaseRoomId!,
      p1MemberId:      widget.p1MemberId!,
      p2MemberId:      widget.p2MemberId!,
      p1Board:         _board1,
      p2Board:         _board2,
      winnerId:        winnerIsP1 ? widget.p1FirebaseUid : widget.p2FirebaseUid,
      winnerUsername:  winnerIsP1 ? widget.player1Name : widget.player2Name,
    );
  }

  /// Applies slot scoring to running scores.
  /// Decrement slots subtract from own score and add to opponent's.
  void _applySlotScore(String slotKey, double level) {
    final role = _slots.firstWhere(
      (s) => s.key == slotKey,
      orElse: () => SlotRole(
          id: '', name: '', key: slotKey,
          effect: SlotEffect.increment, order: 0),
    );
    if (role.isDecrement) {
      if (_isP1Turn) {
        _score1 -= level;
        _score2 += level;
      } else {
        _score2 -= level;
        _score1 += level;
      }
    } else {
      if (_isP1Turn)
        _score1 += level;
      else
        _score2 += level;
    }
  }

  void _startTurnTimer() {
    _turnTimer?.cancel();
    setState(() => _countdown = _turnSecs);
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        _turnTimer?.cancel();
        _autoAssign();
      }
    });
  }

  void _stopTurnTimer() => _turnTimer?.cancel();

  void _drawCard() {
    if (_showReveal || _deck.isEmpty) return;
    final card = _deck.removeAt(0);
    setState(() {
      _revealedCard = card;
      _showReveal = true;
    });
    _revealCtrl.forward(from: 0); // fade in the drawn-card panel
    HapticFeedback.mediumImpact();
    _stopTurnTimer();
    _syncDrawnCardToFirestore(card); // spectators see the card immediately
  }

  /// Pushes just the newly drawn card to Firestore so spectators see it
  /// the moment the active player draws it — not only after placement.
  void _syncDrawnCardToFirestore(DraftCard drawn) {
    if (!_hasFirebaseSync) return;
    final activeTurnUid =
        _isP1Turn ? widget.p1FirebaseUid! : widget.p2FirebaseUid!;
    DraftService.pnpSyncBoard(
      roomId:        widget.firebaseRoomId!,
      p1MemberId:    widget.p1MemberId!,
      p2MemberId:    widget.p2MemberId!,
      p1Board:       _board1,
      p2Board:       _board2,
      currentTurnId: activeTurnUid,
      currentCardId: drawn.id, // spectators see this card immediately
    );
  }

  // ── Skip: discard current card, draw a fresh one ──────────────────────
  void _skipCard() {
    if (!_showReveal || _revealedCard == null || _deck.isEmpty) return;
    if (_curSkipUsed) return; // guard: already used this turn
    HapticFeedback.lightImpact();
    // Mark skip as used for the current player — permanent for this game
    setState(() {
      if (_isP1Turn)
        _p1SkipUsed = true;
      else
        _p2SkipUsed = true;
    });
    // Put the skipped card at the BACK of the deck so it can reappear later
    _deck.add(_revealedCard!);
    final next = _deck.removeAt(0);
    _revealCtrl.forward(from: 0);
    setState(() {
      _revealedCard = next;
    });
    _syncDrawnCardToFirestore(next); // spectators see the replacement card
  }

  void _pickSlot(String slotKey) {
    if (_revealedCard == null || _myBoard[slotKey] != null) return;
    final card = _revealedCard!;
    HapticFeedback.selectionClick();
    // Fade out panel, then place and advance
    _revealCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _myBoard[slotKey] = card;
        _applySlotScore(slotKey, card.level);
        _revealedCard = null;
        _showReveal = false;
      });
      _advanceTurn();
      _syncBoardToFirestore();
    });
  }

  void _autoAssign() {
    final emptySlot = _slots.firstWhere(
      (s) => _myBoard[s.key] == null,
      orElse: () => _slots.first,
    );
    if (_myBoard[emptySlot.key] != null) {
      _advanceTurn();
      return;
    }
    if (_revealedCard == null && _deck.isNotEmpty)
      _revealedCard = _deck.removeAt(0);
    if (_revealedCard == null) {
      _advanceTurn();
      return;
    }
    final card = _revealedCard!;
    setState(() {
      _myBoard[emptySlot.key] = card;
      _applySlotScore(emptySlot.key, card.level);
      _revealedCard = null;
      _showReveal = false;
    });
    HapticFeedback.lightImpact();
    _advanceTurn();
    _syncBoardToFirestore();
  }

  void _advanceTurn() {
    final p1Full = _slots.every((s) => _board1[s.key] != null);
    final p2Full = _slots.every((s) => _board2[s.key] != null);
    if ((p1Full && p2Full) || (_deck.isEmpty && _revealedCard == null)) {
      _endGame();
      return;
    }
    setState(() => _currentPlayer = _isP1Turn ? 2 : 1);
    _deckMoveCtrl.forward(from: 0);
    _startTurnTimer();
  }

  void _endGame() {
    _stopTurnTimer();
    _syncFinishToFirestore(); // write final state to Firestore for spectators
    setState(() => _gameOver = true);
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      _showResultDialog();
    });
  }

  void _showResultDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.78),
      builder: (_) => _GameResultDialog(
        p1Name:  widget.player1Name,
        p2Name:  widget.player2Name,
        score1:  _score1,
        score2:  _score2,
        p1Color: widget.player1Color,
        p2Color: widget.player2Color,
        board1:  Map.from(_board1),
        board2:  Map.from(_board2),
        slots:   _slots,
        onExit: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
        onPlayAgain: () {
          Navigator.of(context).pop();
          setState(() {
            for (final s in _slots) {
              _board1[s.key] = null;
              _board2[s.key] = null;
            }
            _score1 = 0;
            _score2 = 0;
            _currentPlayer = 1;
            _revealedCard = null;
            _showReveal = false;
            _gameOver = false;
            _countdown = _turnSecs;
            _p1SkipUsed = false;
            _p2SkipUsed = false;
          });
          _initDeck();
          _deckMoveCtrl.value = 1.0;
          _startTurnTimer();
        },
      ),
    );
  }

  Future<bool> _confirmForfeit() async {
    if (_gameOver) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.78),
      builder: (_) => AlertDialog(
        backgroundColor: _surf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _bdr),
        ),
        title: const Text(
          'Forfeit Match?',
          style: TextStyle(color: _txtPri, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'This unfinished match will end now. $_curName forfeits and $_oppName wins.',
          style: const TextStyle(color: _txtSub, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: _txtMut)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.flag_rounded, size: 18),
            label: const Text('Forfeit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8445A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _handleExitAttempt() async {
    if (_gameOver) {
      Navigator.of(context).pop();
      return;
    }
    final confirmed = await _confirmForfeit();
    if (!confirmed || !mounted) return;
    _stopTurnTimer();
    _syncForfeitToFirestore();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_gameOver) return true;
        final confirmed = await _confirmForfeit();
        if (!confirmed) return false;
        _stopTurnTimer();
        _syncForfeitToFirestore();
        return true;
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(children: [
          _AmbientBackground(
            leftColor: widget.player1Color,
            rightColor: widget.player2Color,
            leftOpacity: _isP1Turn ? 0.09 : 0.03,
            rightOpacity: _isP1Turn ? 0.03 : 0.09,
          ),
          SafeArea(
              child: Column(children: [
            _buildTopBar(context),
            // Board always uses Expanded so the bottom panel never overflows.
            Expanded(child: _buildBoard()),
            const SizedBox(
              height: 80,
            ),
            _buildBottomArea(),
          ])),
        ]),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    final r = _R.of(context);
    final urgent = _countdown <= 8;
    final timerColor = urgent ? _amber : _curColor;
    final timerFrac = _countdown / _turnSecs;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.hPadTop, vertical: r.vPadTop),
      decoration: BoxDecoration(
        color: _surf,
        border: const Border(bottom: BorderSide(color: _bdr)),
        boxShadow: [
          BoxShadow(
              color: _curColor.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // ── Back button ────────────────────────────────────────────────────
        GestureDetector(
          onTap: _handleExitAttempt,
          child: Container(
            width: r.backBtn,
            height: r.backBtn,
            decoration: BoxDecoration(
                color: _raised,
                borderRadius: BorderRadius.circular(r.sp(8)),
                border: Border.all(color: _bdr)),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                color: _txtMut, size: r.sp(13)),
          ),
        ),
        SizedBox(width: r.sp(10)),
        // ── Franchise / mode title (centred, fills available space) ────────
        Expanded(
          child: Text(
            widget.franchise ?? _modeLabel,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontSize: r.sp(15).clamp(12.0, 20.0),
              fontWeight: FontWeight.w800,
              color: _curColor,
              letterSpacing: 0.4,
            ),
          ),
        ),
        SizedBox(width: r.sp(10)),
        // ── Turn timer (right side) ────────────────────────────────────────
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) => SizedBox(
            width: r.timerSize,
            height: r.timerSize,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                  size: Size(r.timerSize, r.timerSize),
                  painter: _TimerArcPainter(
                      fraction: timerFrac,
                      color: timerColor,
                      glow: _glowAnim.value)),
              Text('$_countdown',
                  style: TextStyle(
                      fontSize: r.fsTimer,
                      fontWeight: FontWeight.w900,
                      color: urgent ? _amber : _curColor.withOpacity(0.9))),
            ]),
          ),
        ),
      ]),
    );
  }

  String get _modeLabel => switch (widget.mode) {
        GameplayMode.quickMatch => 'Quick Match',
        GameplayMode.passAndPlay => 'Pass & Play',
        GameplayMode.playWithFriend => 'Friend Match',
      };

  // ── Board ─────────────────────────────────────────────────────────────────
  Widget _buildBoard() {
    return LayoutBuilder(builder: (context, constraints) {
      final r = _R.of(context);
      final slotCount = _slots.length;

      final availW = constraints.maxWidth - r.boardHPad * 2;
      final slotSizeFromW = (availW / 3.325).clamp(52.0, 100.0);

      double slotSize = slotSizeFromW;
      if (slotCount <= 6 &&
          constraints.maxHeight.isFinite &&
          constraints.maxHeight > 0) {
        final availH = constraints.maxHeight - r.boardVPad * 2;
        final slotSizeFromH = ((availH - slotCount * r.rowVPad * 2) / slotCount)
            .clamp(40.0, 120.0);
        slotSize = slotSizeFromW.clamp(0.0, slotSizeFromH);
      }

      final physics = slotCount <= 6
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics();

      return ListView(
        physics: physics,
        padding: EdgeInsets.symmetric(
            horizontal: r.boardHPad, vertical: r.boardVPad),
        children: _slots
            .map((slot) => Padding(
                  padding: EdgeInsets.symmetric(vertical: r.rowVPad),
                  child: SizedBox(
                      height: slotSize,
                      child: _SlotRow(
                        slot: slot,
                        leftCard:  _board1[slot.key],
                        rightCard: _board2[slot.key],
                        leftColor: widget.player1Color,
                        rightColor: widget.player2Color,
                        activeLeft: _isP1Turn, slotSize: slotSize,
                        inPickMode: _showReveal,
                        pickColor: _curColor,
                        onPickSlot: _showReveal ? _pickSlot : null,
                      )),
                ))
            .toList(),
      );
    });
  }

  // ── Bottom area — arch-shaped panel in the current player's colour ─────────
  // Both states (deck + drawn card) live inside the same SizedBox so the
  // board above never resizes.
  Widget _buildBottomArea() {
    return Builder(builder: (context) {
      final r = _R.of(context);
      // Card size derived directly from screen height — stays constant regardless
      // of bottomH so the slot layout above never shifts.
      final cardH =
          (MediaQuery.sizeOf(context).height * 0.14).clamp(90.0, 130.0);
      final cardW = cardH * (90.0 / 116.0);
      // bottomH is content-exact: topPad + card + gap + hintRow + bottomPad
      // This removes all dead space at the bottom of the arch.
      const double topPad = 0.0;
      const double gap = 6.0;
      const double hintRowH = 34.0;
      const double botPad = 0.0;
      final bottomH = cardH;

      // ── content that sits inside the arch ────────────────────────────────
      Widget content;

      if (_showReveal && _revealedCard != null) {
        // Card drawn — show card + hint + skip
        final glow = _tierGlow(_revealedCard!.level);
        final canSkip = !_curSkipUsed && _deck.isNotEmpty;
        content = FadeTransition(
          opacity: _revealFadeAnim,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // const SizedBox(height: topPad),
              // Draggable card
              Positioned(
                bottom: 40,
                child: Center(
                  child: Draggable<DraftCard>(
                    data: _revealedCard!,
                    feedback: Material(
                      color: Colors.transparent,
                      child: _DrawnCardVisual(
                          card: _revealedCard!,
                          glow: glow,
                          width: cardW * 1.08,
                          height: cardH * 1.08,
                          opacity: 0.90),
                    ),
                    childWhenDragging: const SizedBox(),
                    // childWhenDragging: Opacity(
                    //   opacity: 0.25,
                    //   child: _DrawnCardVisual(
                    //       card: _revealedCard!, glow: glow, width: cardW+15, height: cardH+20),
                    // ),
                    child: _DrawnCardVisual(
                        card: _revealedCard!,
                        glow: glow,
                        width: cardW + 15,
                        height: cardH + 20),
                  ),
                ),
              ),
              Positioned(
                  bottom: 10,
                  right: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: r.sp(11),
                        color: glow.withValues(alpha: 0.7),
                      ),
                      SizedBox(
                        width: r.sp(4),
                      ),
                      Text(
                        "TAP A SLOT  OR  DRAG TO PLACE",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: r.sp(8).clamp(6.5, 10),
                            fontWeight: FontWeight.w700,
                            color: glow.withValues(alpha: 0.7),
                            letterSpacing: 1),
                      ),
                    ],
                  )),
              Positioned(
                bottom: 30,
                right: 10,
                child: GestureDetector(
                  onTap: canSkip ? _skipCard : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                        horizontal: r.sp(10), vertical: r.sp(3)),
                    decoration: BoxDecoration(
                      color: canSkip
                          ? _amber.withOpacity(0.15)
                          : _raised.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(r.sp(8)),
                      border: Border.all(
                          color: canSkip ? _amber.withOpacity(0.55) : _bdr,
                          width: 1.2),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.skip_next_rounded,
                          size: r.sp(13).clamp(10, 16),
                          color: canSkip ? _amber : _txtMut.withOpacity(0.4)),
                      SizedBox(width: r.sp(4)),
                      Text('SKIP',
                          style: TextStyle(
                              fontSize: r.sp(9).clamp(7, 11),
                              fontWeight: FontWeight.w800,
                              color:
                                  canSkip ? _amber : _txtMut.withOpacity(0.4),
                              letterSpacing: 0.8)),
                    ]),
                  ),
                ),
              ),
              // Hint + skip row
            ],
          ),
        );
      } else if (_gameOver) {
        // Game is over — show a "Game Completed" button to re-open results
        content = Center(
          child: GestureDetector(
            onTap: _showResultDialog,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.sp(28), vertical: r.sp(14)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.player1Color.withOpacity(0.85),
                    widget.player2Color.withOpacity(0.85),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(r.sp(14)),
                boxShadow: [
                  BoxShadow(
                    color: widget.player1Color.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_rounded,
                      color: Colors.white, size: r.sp(18).clamp(14, 22)),
                  SizedBox(width: r.sp(8)),
                  Text(
                    'GAME COMPLETED',
                    style: TextStyle(
                      fontSize: r.sp(13).clamp(11, 16),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        // No card drawn — show centered deck stack
        content = Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 0),
            child: GestureDetector(
              onTap: _drawCard,
              child: _DeckStack(
                  color: _curColor, isActive: true, count: _deck.length, r: r),
            ),
          ),
        );
      }

      return SizedBox(
        height: bottomH,
        child: Stack(children: [
          // Arch-shaped background in the current player's colour
          Positioned.fill(
            child: CustomPaint(
              painter: _ArchPainter(color: _curColor),
            ),
          ),
          // Content on top of the arch
          content,
        ]),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Score Chip
// ─────────────────────────────────────────────────────────────────────────────
class _ScoreChip extends StatelessWidget {
  final String name;
  final double score;
  final Color color;
  final bool isActive, alignLeft;
  final _R r;

  const _ScoreChip(
      {required this.name,
      required this.score,
      required this.color,
      required this.isActive,
      required this.alignLeft,
      required this.r});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(horizontal: r.sp(8), vertical: r.sp(5)),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.12) : _raised.withOpacity(0.5),
        borderRadius: BorderRadius.circular(r.sp(12)),
        border: Border.all(
            color: isActive ? color.withOpacity(0.50) : _bdr,
            width: isActive ? 1.5 : 1),
        boxShadow: isActive
            ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 12)]
            : null,
      ),
      child: Column(
        crossAxisAlignment:
            alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name,
              style: TextStyle(
                  fontSize: r.fsScoreLbl,
                  fontWeight: FontWeight.w600,
                  color: isActive ? color.withOpacity(0.8) : _txtMut,
                  letterSpacing: 0.2),
              overflow: TextOverflow.ellipsis),
          SizedBox(height: r.sp(2)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.star_rounded,
                size: r.fsScoreLbl + 1,
                color: isActive ? color : _txtMut.withOpacity(0.5)),
            SizedBox(width: r.sp(3)),
            Text(score.toString(),
                style: TextStyle(
                    fontSize: r.fsScore,
                    fontWeight: FontWeight.w900,
                    color: isActive ? color : _txtMut.withOpacity(0.6),
                    height: 1)),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timer arc painter
// ─────────────────────────────────────────────────────────────────────────────
class _TimerArcPainter extends CustomPainter {
  final double fraction, glow;
  final Color color;
  const _TimerArcPainter(
      {required this.fraction, required this.color, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = (size.width / 2) - 4;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2,
        false,
        Paint()
          ..color = color.withOpacity(0.12)
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    if (fraction > 0) {
      canvas.drawArc(
          rect,
          -math.pi / 2,
          math.pi * 2 * fraction,
          false,
          Paint()
            ..color = color.withOpacity(0.55 + 0.45 * glow)
            ..strokeWidth = 3.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_TimerArcPainter o) =>
      o.fraction != fraction || o.glow != glow || o.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Slot Row
// ─────────────────────────────────────────────────────────────────────────────
class _SlotRow extends StatelessWidget {
  final SlotRole slot;
  final DraftCard? leftCard, rightCard;
  final Color leftColor, rightColor;
  final bool activeLeft;
  final double slotSize;
  final bool inPickMode; // card drawn, awaiting slot selection
  final Color? pickColor;
  final void Function(String)? onPickSlot; // receives slot.key

  const _SlotRow(
      {required this.slot,
      required this.leftCard,
      required this.rightCard,
      required this.leftColor,
      required this.rightColor,
      required this.activeLeft,
      this.slotSize = 80,
      this.inPickMode = false,
      this.pickColor,
      this.onPickSlot});

  @override
  Widget build(BuildContext context) {
    final r = _R.of(context);
    final labelW = (slotSize * 1.025).clamp(68.0, 110.0);

    Widget buildSlot(
        {required bool isLeft,
        required DraftCard? card,
        required Color color}) {
      final isMySide = isLeft == activeLeft;
      final isEmpty = card == null;
      final isTarget = inPickMode && isMySide && isEmpty;
      final pc = pickColor ?? color;

      final cell = _SlotCell(
        card: card,
        color: color,
        isLeft: isLeft,
        isEmpty: isEmpty,
        isActive: isLeft == activeLeft,
        r: r,
        isPickTarget: isTarget,
        onTap: isTarget ? () => onPickSlot?.call(slot.key) : null,
      );

      if (!isTarget)
        return SizedBox(width: slotSize, height: slotSize, child: cell);

      // Wrap with DragTarget so dragged card can be dropped here
      return DragTarget<DraftCard>(
        onAcceptWithDetails: (_) => onPickSlot?.call(slot.key),
        builder: (ctx, candidates, _) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: slotSize,
          height: slotSize,
          decoration: candidates.isNotEmpty
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(r.sp(10).clamp(7, 14)),
                  boxShadow: [
                      BoxShadow(
                          color: pc.withOpacity(0.70),
                          blurRadius: 22,
                          spreadRadius: 4)
                    ])
              : null,
          child: cell,
        ),
      );
    }

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      buildSlot(isLeft: true, card: leftCard, color: leftColor),
      _RoleLabel(slot: slot, width: labelW, r: r),
      buildSlot(isLeft: false, card: rightCard, color: rightColor),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role Label
// ─────────────────────────────────────────────────────────────────────────────
class _RoleLabel extends StatelessWidget {
  final SlotRole slot;
  final double width;
  final _R r;
  const _RoleLabel({required this.slot, this.width = 82, required this.r});

  IconData get _icon => _slotIcon(slot);

  @override
  Widget build(BuildContext context) {
    final isDecrement = slot.isDecrement;
    return Container(
      width: width,
      margin: EdgeInsets.symmetric(horizontal: r.sp(6).clamp(4, 10)),
      padding: EdgeInsets.symmetric(vertical: r.sp(8).clamp(5, 12)),
      decoration: BoxDecoration(
          color: _raised,
          borderRadius: BorderRadius.circular(r.sp(12).clamp(8, 16)),
          border: Border.all(
              color: isDecrement
                  ? const Color(0xFFE8445A).withOpacity(0.35)
                  : _bdr)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_icon, size: r.fsSlotIcon,
            color: isDecrement
                ? const Color(0xFFE8445A).withOpacity(0.7)
                : _txtSub),
        SizedBox(height: r.sp(3).clamp(2, 5)),
        Text(slot.name.toUpperCase().replaceAll(' ', '\n'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: r.fsSlotLbl,
                fontWeight: FontWeight.w800,
                color: isDecrement
                    ? const Color(0xFFE8445A).withOpacity(0.85)
                    : _txtPri,
                letterSpacing: 0.4,
                height: 1.25)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slot Cell
// ─────────────────────────────────────────────────────────────────────────────
class _SlotCell extends StatelessWidget {
  final DraftCard? card;
  final Color color;
  final bool isLeft, isEmpty, isActive;
  final _R r;
  final bool isPickTarget; // highlight as placement target
  final VoidCallback? onTap; // tap-to-place callback

  const _SlotCell(
      {required this.card,
      required this.color,
      required this.isLeft,
      required this.isEmpty,
      this.isActive = false,
      required this.r,
      this.isPickTarget = false,
      this.onTap});

  void _showDetails(BuildContext ctx) {
    if (card == null) return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
        context: ctx,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) =>
            _CardDetailSheet(card: card!, glow: _tierGlow(card!.level)));
  }

  @override
  Widget build(BuildContext ctx) => isEmpty ? _buildEmpty() : _buildFilled(ctx);

  Widget _buildEmpty() {
    final cell = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isPickTarget
            ? color.withOpacity(0.14)
            : isActive
                ? color.withOpacity(0.05)
                : _raised.withOpacity(0.4),
        borderRadius: BorderRadius.circular(r.sp(10).clamp(7, 14)),
        border: Border.all(
            color: isPickTarget
                ? color.withOpacity(0.75)
                : isActive
                    ? color.withOpacity(0.30)
                    : _bdr.withOpacity(0.40),
            width: isPickTarget
                ? 2.0
                : isActive
                    ? 1.5
                    : 1.0),
        boxShadow: isPickTarget
            ? [BoxShadow(color: color.withOpacity(0.30), blurRadius: 12)]
            : null,
      ),
      child: Center(
          child: Icon(
              isPickTarget
                  ? Icons.add_circle_outline_rounded
                  : isActive
                      ? Icons.add_rounded
                      : Icons.remove_rounded,
              size: r.sp(isPickTarget ? 14 : 10).clamp(8, 18),
              color: isPickTarget
                  ? color.withOpacity(0.85)
                  : isActive
                      ? color.withOpacity(0.40)
                      : _bdr.withOpacity(0.40))),
    );
    if (onTap != null) return GestureDetector(onTap: onTap, child: cell);
    return cell;
  }

  Widget _buildFilled(BuildContext ctx) {
    final c = card!;
    final glow = _tierGlow(c.level);
    return GestureDetector(
      onLongPress: () => _showDetails(ctx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.sp(10).clamp(7, 14)),
            border: Border.all(color: glow.withOpacity(0.55), width: 1.5),
            boxShadow: [
              BoxShadow(color: glow.withOpacity(0.18), blurRadius: 8)
            ]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r.sp(9).clamp(6, 13)),
          child: Stack(fit: StackFit.expand, children: [
            c.imageUrl.isNotEmpty
                ? Image.network(c.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _letterBg(c, glow))
                : _letterBg(c, glow),
            Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: r.sp(3).clamp(2, 5),
                child: Container(color: glow.withOpacity(0.85))),
          ]),
        ),
      ),
    );
  }

  Widget _letterBg(DraftCard c, Color glow) => Container(
        color: glow.withOpacity(0.12),
        child: Center(
            child: Text(c.name.isNotEmpty ? c.name[0] : '?',
                style: TextStyle(
                    fontSize: r.sp(22).clamp(15, 30),
                    fontWeight: FontWeight.w900,
                    color: glow.withOpacity(0.55)))),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Card Detail Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CardDetailSheet extends StatelessWidget {
  final DraftCard card;
  final Color glow;
  const _CardDetailSheet({required this.card, required this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: _surf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: glow.withOpacity(0.40), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: glow.withOpacity(0.25), blurRadius: 28, spreadRadius: 2),
          const BoxShadow(color: Colors.black87, blurRadius: 20)
        ],
      ),
      child: SafeArea(
        child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  height: 210,
                  width: double.infinity,
                  child: Stack(fit: StackFit.expand, children: [
                    card.imageUrl.isNotEmpty
                        ? Image.network(card.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallback())
                        : _fallback(),
                    Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 100,
                        child: Container(
                            decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [_surf, Colors.transparent])))),
                    Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                            child: Container(
                                width: 38,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(2))))),
                    Positioned(
                        top: 18,
                        left: 14,
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.60),
                                borderRadius: BorderRadius.circular(7),
                                border:
                                    Border.all(color: glow.withOpacity(0.45))),
                            child: Text(card.franchiseName.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: glow.withOpacity(0.9),
                                    letterSpacing: 0.8)))),
                    Positioned(
                        top: 18,
                        right: 14,
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: glow.withOpacity(0.20),
                                borderRadius: BorderRadius.circular(7),
                                border:
                                    Border.all(color: glow.withOpacity(0.55))),
                            child: Text(card.tierLabel,
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: glow,
                                    letterSpacing: 1)))),
                  ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card.name,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: _txtPri),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        if (card.description.isNotEmpty)
                          Text(card.description,
                              style: const TextStyle(
                                  fontSize: 12, color: _txtSub, height: 1.5)),
                        const SizedBox(height: 14),
                        Row(children: [
                          Text('POWER',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: glow.withOpacity(0.55),
                                  letterSpacing: 1.5)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                      value: card.level / 10,
                                      minHeight: 6,
                                      backgroundColor: Colors.white10,
                                      valueColor:
                                          AlwaysStoppedAnimation(glow)))),
                          const SizedBox(width: 10),
                          Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                  color: glow.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(9),
                                  border:
                                      Border.all(color: glow.withOpacity(0.50)),
                                  boxShadow: [
                                    BoxShadow(
                                        color: glow.withOpacity(0.30),
                                        blurRadius: 10)
                                  ]),
                              child: Center(
                                  child: Text(card.level.toString(),
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: glow)))),
                        ]),
                      ])),
            ])),
      ),
    );
  }

  Widget _fallback() => Container(
      color: glow.withOpacity(0.08),
      child: Center(
          child: Text(card.name.isNotEmpty ? card.name[0] : '?',
              style: TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.w900,
                  color: glow.withOpacity(0.14)))));
}

// ─────────────────────────────────────────────────────────────────────────────
// Deck Stack
// ─────────────────────────────────────────────────────────────────────────────
class _DeckStack extends StatelessWidget {
  final Color color;
  final bool isActive;
  final int count;
  final _R r;
  const _DeckStack(
      {required this.color,
      required this.isActive,
      required this.count,
      required this.r});

  @override
  Widget build(BuildContext context) {
    final cw = r.deckCardW, ch = r.deckCardH;
    // Extra width to accommodate the fanned background cards without clipping
    final totalW = cw + r.sp(10);
    final totalH = ch + r.sp(6);
    return SizedBox(
        width: totalW,
        height: totalH,
        child: Stack(alignment: Alignment.center, children: [
          // Background cards — fanned symmetrically so stack is centered
          for (int i = 3; i >= 1; i--)
            Transform.translate(
                offset: Offset((i - 2) * r.sp(5), i * r.sp(1.5)),
                child: Container(
                    width: cw,
                    height: ch,
                    decoration: BoxDecoration(
                        color: isActive
                            ? color.withOpacity(0.06 + i * 0.04)
                            : _raised,
                        borderRadius: BorderRadius.circular(r.sp(10)),
                        border: Border.all(
                            color: isActive
                                ? color.withOpacity(0.12 + i * 0.05)
                                : _bdr.withOpacity(0.4))))),
          // Top (front) card — perfectly centered
          Container(
              width: cw,
              height: ch,
              decoration: BoxDecoration(
                  gradient: isActive
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [color, color.withOpacity(0.65)])
                      : const LinearGradient(colors: [_raised, _surf]),
                  borderRadius: BorderRadius.circular(r.sp(10)),
                  border: Border.all(
                      color: isActive ? color : _bdr,
                      width: isActive ? 1.5 : 1)),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.style_rounded,
                        size: r.sp(22).clamp(16, 28),
                        color:
                            isActive ? Colors.white : _txtMut.withOpacity(0.4)),
                    SizedBox(height: r.sp(4)),
                    Text(isActive ? 'DRAW' : '...',
                        style: TextStyle(
                            fontSize: r.fsDeckLbl,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: isActive
                                ? Colors.white
                                : _txtMut.withOpacity(0.4))),
                    SizedBox(height: r.sp(2)),
                    if (count > 0)
                      Text('$count',
                          style: TextStyle(
                              fontSize: r.fsDeckCount,
                              fontWeight: FontWeight.w900,
                              color: isActive
                                  ? Colors.white.withOpacity(0.7)
                                  : _txtMut.withOpacity(0.3))),
                  ])),
        ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drawn Card Panel
// Replaces the deck view after drawing. Card is centered, draggable.
// ─────────────────────────────────────────────────────────────────────────────
class _DrawnCardPanel extends StatelessWidget {
  final DraftCard card;
  final Color playerColor;
  final void Function(String) onPickSlot; // receives slot.key
  final VoidCallback? onSkip; // null = no cards left to skip to
  final _R r;

  const _DrawnCardPanel({
    required this.card,
    required this.playerColor,
    required this.onPickSlot,
    required this.r,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final glow = _tierGlow(card.level);
    // Use LayoutBuilder so the card height is computed from whatever space
    // the parent SizedBox gives us — this is what prevents the overflow.
    return LayoutBuilder(builder: (context, constraints) {
      // hintH must include the skip button row height (~32px with padding)
      const hintH = 34.0; // hint+skip row actual height
      const gapH = 4.0; // gap between hint row and card
      const padV = 4.0; // top + bottom padding inside panel
      final available =
          constraints.maxHeight.isFinite ? constraints.maxHeight : 110.0;
      // Subtract every pixel of overhead so card never overflows its container
      final cardH = (available - padV * 2 - hintH - gapH).clamp(24.0, 120.0);
      final cardW = cardH * (90.0 / 116.0); // keep original aspect ratio

      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: r.deckHPad, vertical: padV),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [playerColor.withOpacity(0.10), _surf]),
          border: Border(
              top: BorderSide(color: playerColor.withOpacity(0.22), width: 1)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Hint row + skip button
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            // hint label
            const Spacer(),
            SizedBox(width: r.sp(8)),
            // SKIP button — greyed out when no cards remain
            GestureDetector(
              onTap: onSkip,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                    horizontal: r.sp(10), vertical: r.sp(3)),
                decoration: BoxDecoration(
                  color: onSkip != null
                      ? _amber.withOpacity(0.15)
                      : _raised.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(r.sp(8)),
                  border: Border.all(
                    color: onSkip != null ? _amber.withOpacity(0.55) : _bdr,
                    width: 1.2,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.skip_next_rounded,
                      size: r.sp(13).clamp(10, 16),
                      color:
                          onSkip != null ? _amber : _txtMut.withOpacity(0.4)),
                  SizedBox(width: r.sp(4)),
                  Text('SKIP',
                      style: TextStyle(
                        fontSize: r.sp(9).clamp(7, 11),
                        fontWeight: FontWeight.w800,
                        color:
                            onSkip != null ? _amber : _txtMut.withOpacity(0.4),
                        letterSpacing: 0.8,
                      )),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: gapH),

          // Draggable card — centered, height derived from available space
          Center(
            child: Draggable<DraftCard>(
              data: card,
              feedback: Material(
                color: Colors.transparent,
                child: _DrawnCardVisual(
                    card: card,
                    glow: glow,
                    width: cardW * 1.08,
                    height: cardH * 1.08,
                    opacity: 0.90),
              ),
              childWhenDragging: Opacity(
                opacity: 0.25,
                child: _DrawnCardVisual(
                    card: card, glow: glow, width: cardW, height: cardH),
              ),
              child: _DrawnCardVisual(
                  card: card, glow: glow, width: cardW, height: cardH),
            ),
          ),
        ]),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drawn Card Visual
// Full-image card with name overlaid at the bottom and tier badge top-right.
// ─────────────────────────────────────────────────────────────────────────────
class _DrawnCardVisual extends StatelessWidget {
  final DraftCard card;
  final Color glow;
  final double width, height;
  final double opacity;

  const _DrawnCardVisual({
    required this.card,
    required this.glow,
    required this.width,
    required this.height,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: glow, width: 1.8),
          boxShadow: [
            BoxShadow(
                color: glow.withOpacity(0.55), blurRadius: 26, spreadRadius: 2),
            const BoxShadow(color: Colors.black54, blurRadius: 10),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.5),
          child: Stack(fit: StackFit.expand, children: [
            // Full image fills the card
            card.imageUrl.isNotEmpty
                ? Image.network(card.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback())
                : _fallback(),

            // Gradient so the name is readable
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: height * 0.50,
              child: Container(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black, Colors.transparent]))),
            ),

            // Card name at the bottom of the image
            Positioned(
              bottom: 9,
              left: 8,
              right: 8,
              child: Text(card.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.25,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 6)])),
            ),

            // Tier badge — top-right
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: glow.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: glow.withOpacity(0.60))),
                child: Text(card.tierLabel,
                    style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        color: glow,
                        letterSpacing: 0.8)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
      color: glow.withOpacity(0.15),
      child: Center(
          child: Text(card.name.isNotEmpty ? card.name[0] : '?',
              style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: glow.withOpacity(0.65)))));
}

// ─────────────────────────────────────────────────────────────────────────────
// Game Result Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _GameResultDialog extends StatelessWidget {
  final String p1Name, p2Name;
  final double score1, score2;
  final Color p1Color, p2Color;
  final Map<String, DraftCard?> board1, board2;
  final List<SlotRole> slots;
  final VoidCallback onExit, onPlayAgain;

  const _GameResultDialog(
      {required this.p1Name,
      required this.p2Name,
      required this.score1,
      required this.score2,
      required this.p1Color,
      required this.p2Color,
      required this.board1,
      required this.board2,
      required this.slots,
      required this.onExit,
      required this.onPlayAgain});

  @override
  Widget build(BuildContext context) {
    final p1Wins = score1 > score2;
    final isDraw = score1 == score2;
    final winColor = isDraw ? _amber : (p1Wins ? p1Color : p2Color);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Container(
        decoration: BoxDecoration(
            color: _surf,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: winColor.withOpacity(0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: winColor.withOpacity(0.20),
                  blurRadius: 32,
                  spreadRadius: 2),
              const BoxShadow(
                  color: Colors.black, blurRadius: 24, offset: Offset(0, 8))
            ]),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: _raised,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _bdr)),
                      child: Column(children: [
                        Row(children: [
                          _ScorePill(
                              name: p1Name,
                              score: score1,
                              color: p1Color,
                              isWinner: !isDraw && p1Wins,
                              alignLeft: true),
                          Expanded(
                              child: Center(
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: _surf,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(color: _bdr)),
                                      child: const Text('VS',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: _txtMut,
                                              letterSpacing: 1.5))))),
                          _ScorePill(
                              name: p2Name,
                              score: score2,
                              color: p2Color,
                              isWinner: !isDraw && !p1Wins,
                              alignLeft: false),
                        ]),
                        const SizedBox(height: 10),
                        Builder(builder: (_) {
                          final total = score1 + score2;
                          final f = total > 0
                              ? (score1 / total).clamp(0.05, 0.95)
                              : 0.5;
                          return ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: Row(children: [
                                Flexible(
                                    flex: (f * 100).round(),
                                    child: Container(
                                        height: 7,
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: [
                                              p1Color,
                                              p1Color.withOpacity(0.6)
                                            ]),
                                            borderRadius:
                                                const BorderRadius.only(
                                                    topLeft: Radius.circular(5),
                                                    bottomLeft:
                                                        Radius.circular(5))))),
                                Flexible(
                                    flex: ((1 - f) * 100).round(),
                                    child: Container(
                                        height: 7,
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: [
                                              p2Color.withOpacity(0.6),
                                              p2Color
                                            ]),
                                            borderRadius:
                                                const BorderRadius.only(
                                                    topRight:
                                                        Radius.circular(5),
                                                    bottomRight:
                                                        Radius.circular(5))))),
                              ]));
                        }),
                      ]))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                      decoration: BoxDecoration(
                          color: _raised,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _bdr)),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: const BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(color: _bdr))),
                                child: Row(children: [
                                  Expanded(
                                      child: Row(children: [
                                    Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: p1Color.withOpacity(0.8))),
                                    const SizedBox(width: 6),
                                    Flexible(
                                        child: Text(p1Name,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: p1Color),
                                            overflow: TextOverflow.ellipsis)),
                                  ])),
                                  const SizedBox(width: 50),
                                  Expanded(
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                        Flexible(
                                            child: Text(p2Name,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: p2Color),
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.end)),
                                        const SizedBox(width: 6),
                                        Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color:
                                                    p2Color.withOpacity(0.8))),
                                      ])),
                                ])),
                            ...slots.asMap().entries.map((e) {
                              final isLast = e.key == slots.length - 1;
                              final slot = e.value;
                              return Container(
                                  decoration: BoxDecoration(
                                      border: isLast
                                          ? null
                                          : const Border(
                                              bottom: BorderSide(
                                                  color: _bdr, width: 0.5))),
                                  child: IntrinsicHeight(
                                      child: Row(children: [
                                    Expanded(
                                        child: _DialogCardCell(
                                            card: board1[slot.key],
                                            color: p1Color,
                                            isLeft: true)),
                                    Container(
                                        width: 50,
                                        decoration: const BoxDecoration(
                                            border: Border.symmetric(
                                                vertical: BorderSide(
                                                    color: _bdr, width: 0.5))),
                                        child: Center(
                                            child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                              Icon(_slotIcon(slot),
                                                  size: 10,
                                                  color: slot.isDecrement
                                                      ? const Color(0xFFE8445A).withOpacity(0.6)
                                                      : _txtMut.withOpacity(0.55)),
                                              const SizedBox(height: 2),
                                              Text(
                                                  slot.name
                                                      .toUpperCase()
                                                      .replaceAll(' ', '\n'),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      fontSize: 6.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: _txtMut,
                                                      height: 1.2)),
                                            ]))),
                                    Expanded(
                                        child: _DialogCardCell(
                                            card: board2[slot.key],
                                            color: p2Color,
                                            isLeft: false)),
                                  ])));
                            }),
                          ])))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Row(children: [
                    GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                                color: _raised,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _bdr)),
                            child: const Icon(Icons.close_rounded,
                                size: 18, color: _txtMut))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: GestureDetector(
                            onTap: onPlayAgain,
                            child: Container(
                                height: 46,
                                decoration: BoxDecoration(
                                    color: winColor,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                          color: winColor.withOpacity(0.35),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4))
                                    ]),
                                child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.refresh_rounded,
                                          size: 17, color: Colors.white),
                                      SizedBox(width: 7),
                                      Text('Play Again',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white)),
                                    ])))),
                    const SizedBox(width: 10),
                    GestureDetector(
                        onTap: onExit,
                        child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                                color: _raised,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _bdr)),
                            child: const Icon(Icons.home_rounded,
                                size: 18, color: _txtMut))),
                  ])),
            ])),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String name;
  final double score;
  final Color color;
  final bool isWinner, alignLeft;
  const _ScorePill(
      {required this.name,
      required this.score,
      required this.color,
      required this.isWinner,
      required this.alignLeft});
  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment:
              alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (isWinner) ...[
              const Icon(Icons.emoji_events_rounded, color: _amber, size: 13),
              const SizedBox(height: 2)
            ],
            Text(name,
                style: const TextStyle(fontSize: 10, color: _txtSub),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(score.toStringAsFixed(1),
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1)),
            Text('pts',
                style: TextStyle(fontSize: 9, color: color.withOpacity(0.5))),
          ]);
}

class _DialogCardCell extends StatelessWidget {
  final DraftCard? card;
  final Color color;
  final bool isLeft;
  const _DialogCardCell(
      {required this.card, required this.color, required this.isLeft});
  @override
  Widget build(BuildContext context) {
    if (card == null) {
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Align(
              alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
              child: Text('—',
                  style: TextStyle(
                      fontSize: 12, color: _txtMut.withOpacity(0.4)))));
    }
    final glow = _tierGlow(card!.level);
    final thumb = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: glow.withOpacity(0.12),
            border: Border.all(color: glow.withOpacity(0.3))),
        child: card!.imageUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.network(card!.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                        child: Text(card!.name.isNotEmpty ? card!.name[0] : '?',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: glow.withOpacity(0.7))))))
            : Center(
                child: Text(card!.name.isNotEmpty ? card!.name[0] : '?',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: glow.withOpacity(0.7)))));
    final info = Expanded(
        child: Column(
            crossAxisAlignment:
                isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Text(card!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 9.5, fontWeight: FontWeight.w600, color: _txtPri)),
          Text('Lv ${card!.level}',
              style: TextStyle(
                  fontSize: 8.5, fontWeight: FontWeight.w700, color: glow)),
        ]));
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
            children: isLeft
                ? [thumb, const SizedBox(width: 6), info]
                : [info, const SizedBox(width: 6), thumb]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ambient background
// ─────────────────────────────────────────────────────────────────────────────
class _AmbientBackground extends StatelessWidget {
  final Color leftColor, rightColor;
  final double leftOpacity, rightOpacity;
  const _AmbientBackground(
      {required this.leftColor,
      required this.rightColor,
      this.leftOpacity = 0.07,
      this.rightOpacity = 0.05});
  @override
  Widget build(BuildContext context) => Positioned.fill(
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
              gradient: RadialGradient(
                  center: const Alignment(-0.85, -0.2),
                  radius: 1.1,
                  colors: [
                leftColor.withOpacity(leftOpacity),
                Colors.transparent
              ])),
          child: Container(
              decoration: BoxDecoration(
                  gradient: RadialGradient(
                      center: const Alignment(0.85, 0.2),
                      radius: 1.0,
                      colors: [
                rightColor.withOpacity(rightOpacity),
                Colors.transparent
              ])))));
}

// ─────────────────────────────────────────────────────────────────────────────
// Arch Painter — draws the curved tray shape at the bottom in the player colour
// ─────────────────────────────────────────────────────────────────────────────
class _ArchPainter extends CustomPainter {
  final Color color;
  const _ArchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Arch top edge: rises to a peak at the horizontal centre,
    // then drops back to the sides.  Everything below is filled.
    final double peakY = size.height * 0.16; // highest point (centre)
    final double edgeY = size.height * 0.46; // height at left / right edges

    // ── Filled area ───────────────────────────────────────────────────────────
    final fill = Path()
      ..moveTo(0, edgeY)
      ..quadraticBezierTo(size.width * 0.5, peakY, size.width, edgeY)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = color.withOpacity(0.18),
    );

    // ── Arch border line ──────────────────────────────────────────────────────
    final border = Path()
      ..moveTo(0, edgeY)
      ..quadraticBezierTo(size.width * 0.5, peakY, size.width, edgeY);
    canvas.drawPath(
      border,
      Paint()
        ..color = color.withOpacity(0.60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArchPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
Color _tierGlow(double level) {
  if (level >= 9.6) return const Color(0xFFFF3B5C);
  if (level >= 8.5) return const Color(0xFFFFAA00);
  if (level >= 6.5) return const Color(0xFFBB6CFF);
  if (level >= 3.5) return const Color(0xFF38C7FF);
  return const Color(0xFF3ADE80);
}

IconData _slotIcon(SlotRole slot) {
  final key = SlotRole.iconKeyFor(slot.name);
  return switch (key) {
    'captain'      => Icons.star_rounded,
    'vice_captain' => Icons.military_tech_rounded,
    'tank'         => Icons.shield_rounded,
    'duelist'      => Icons.flash_on_rounded,
    'support'      => Icons.favorite_rounded,
    'traitor'      => Icons.visibility_off_rounded,
    _              => Icons.radio_button_checked_rounded,
  };
}
