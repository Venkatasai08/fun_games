// lib/tambola/screens/spectate_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/app_theme.dart';
import '../models/room.dart';
import '../services/room_service.dart';
import '../models/ticket_model.dart';
import '../widgets/number_board_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SpectateScreen — read-only live view of any Tambola game.
//
// • For ongoing games  → live Firestore subscriptions, pulsing last-called,
//                         real-time ticket/board updates.
// • For finished games → same screen, streams still attach (idempotent reads),
//                         shows winner/cancelled banner instead.
//
// No GameBloc, zero write operations — pure read path.
// ─────────────────────────────────────────────────────────────────────────────

class SpectateScreen extends StatefulWidget {
  final String roomId;
  const SpectateScreen({super.key, required this.roomId});

  @override
  State<SpectateScreen> createState() => _SpectateScreenState();
}

class _SpectateScreenState extends State<SpectateScreen>
    with TickerProviderStateMixin {
  // ── Data state ─────────────────────────────────────────────────────────────
  Room? _room;
  List<RoomMember> _members = [];
  bool _loading = true;
  String? _error;

  // ── Firestore subscriptions ────────────────────────────────────────────────
  StreamSubscription<dynamic>? _roomSub;
  StreamSubscription<dynamic>? _membersSub;

  // ── Pulse animation for last-called number ─────────────────────────────────
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Track last-called so we only re-trigger the intro animation on changes
  int? _prevLastCalled;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _setupStreams();
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _membersSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Live subscriptions ─────────────────────────────────────────────────────

  void _setupStreams() {
    // Room doc stream
    _roomSub = RoomService.subscribeToRoom(widget.roomId, (room) {
      if (!mounted) return;
      setState(() {
        _room = room;
        _loading = false;
      });
    });

    // Members stream
    _membersSub =
        RoomService.subscribeToMembers(widget.roomId, (members) {
      if (!mounted) return;
      // Sort: winner first, then by matched-count descending.
      // Re-sort every update so scores stay ordered in real-time.
      final room = _room;
      if (room != null) {
        members.sort((a, b) {
          if (a.hasClaimedHousie && !b.hasClaimedHousie) return -1;
          if (!a.hasClaimedHousie && b.hasClaimedHousie) return 1;
          final aM = TicketGenerator.countMatched(
              a.ticket, room.calledNumbers);
          final bM = TicketGenerator.countMatched(
              b.ticket, room.calledNumbers);
          return bM.compareTo(aM);
        });
      }
      setState(() => _members = members);
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0E1A), Color(0xFF1A1040), Color(0xFF0F0E1A)],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? _buildLoading()
              : _error != null
                  ? _buildError()
                  : _buildContent(),
        ),
      ),
    );
  }

  // ── Loading / Error ────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 16),
          Text('Joining spectator view…',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  // ── Main content ───────────────────────────────────────────────────────────

  Widget _buildContent() {
    final room = _room!;
    return Column(
      children: [
        _buildHeader(room),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // ── Top banner — adapts to game status ──────────────────────
              _buildStatusBanner(room)
                  .animate(key: ValueKey(room.status))
                  .fadeIn()
                  .slideY(begin: -0.1),

              const SizedBox(height: 16),

              // ── Stats row ────────────────────────────────────────────────
              _buildStatsRow(room).animate(delay: 80.ms).fadeIn(),

              const SizedBox(height: 16),

              // ── Number board ─────────────────────────────────────────────
              _buildNumberBoardSection(room)
                  .animate(delay: 140.ms)
                  .fadeIn()
                  .slideY(begin: 0.06),

              const SizedBox(height: 16),

              // ── Players header ───────────────────────────────────────────
              Row(children: [
                const Icon(Icons.people, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'PLAYERS (${_members.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (room.isPlaying) ...[
                  const SizedBox(width: 8),
                  _LiveDot(),
                ],
              ]).animate(delay: 200.ms).fadeIn(),

              const SizedBox(height: 12),

              // ── Player cards ─────────────────────────────────────────────
              ..._members.asMap().entries.map((entry) {
                final i = entry.key;
                final member = entry.value;
                return _SpectatePlayerCard(
                  key: ValueKey(member.userId),
                  member: member,
                  room: room,
                  rank: i + 1,
                ).animate(delay: Duration(milliseconds: 220 + i * 50))
                    .fadeIn()
                    .slideY(begin: 0.08);
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(Room room) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: const Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis),
                Text(
                  'by ${room.hostUsername}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          // Spectating badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_rounded,
                    size: 13, color: Colors.blueAccent),
                SizedBox(width: 5),
                Text(
                  'SPECTATING',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Status banner — four states ────────────────────────────────────────────

  Widget _buildStatusBanner(Room room) {
    if (room.isPlaying) return _buildLiveBanner(room);
    if (room.isWaiting) return _buildWaitingBanner(room);
    if (room.isCancelled) return _buildCancelledBanner();
    return _buildWinnerBanner(room); // finished
  }

  /// LIVE banner — pulsing last-called number, progress bar, live dot.
  Widget _buildLiveBanner(Room room) {
    final lastNum = room.lastCalled;
    // Detect new number to re-trigger entry animation
    final isNewNumber = lastNum != null && lastNum != _prevLastCalled;
    if (isNewNumber) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _prevLastCalled = lastNum);
      });
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1040), Color(0xFF2D1F6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
      ),
      child: Row(children: [
        // Pulsing number circle
        if (lastNum != null)
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryLight],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$lastNum',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ).animate(key: ValueKey(lastNum)).scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1, 1),
                  curve: Curves.elasticOut,
                  duration: 600.ms,
                ),
          )
        else
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: const Center(
              child: Icon(Icons.casino_outlined,
                  size: 32, color: AppTheme.textSecondary),
            ),
          ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LIVE label
              Row(children: [
                _LiveDot(),
                const SizedBox(width: 6),
                const Text(
                  'LIVE GAME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: AppTheme.secondary,
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                lastNum != null
                    ? 'Number $lastNum called'
                    : 'Game starting…',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              Text(
                '${room.calledNumbers.length} of ${room.maxNumber} called',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: room.calledNumbers.length / room.maxNumber,
                  backgroundColor: AppTheme.bgDark,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primary),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  /// WAITING banner — game hasn't started yet.
  Widget _buildWaitingBanner(Room room) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
          ),
          child: const Center(
            child: Icon(Icons.hourglass_top_rounded,
                color: AppTheme.accent, size: 26),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WAITING TO START',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_members.length} player${_members.length == 1 ? '' : 's'} in lobby',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              const Text(
                'Host will start the game soon…',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  /// FINISHED banner — shows winner or "no winner".
  Widget _buildWinnerBanner(Room room) {
    final hasWinner = room.winnerUsername != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasWinner
              ? [const Color(0xFF1A1040), const Color(0xFF2D2060)]
              : [AppTheme.bgCard, AppTheme.bgCard],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasWinner
              ? AppTheme.accent.withOpacity(0.5)
              : AppTheme.border,
        ),
      ),
      child: hasWinner
          ? Row(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                    child: Text('🏆', style: TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WINNER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.winnerUsername!,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${room.calledNumbers.length} numbers called',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ])
          : const Row(children: [
              Icon(Icons.flag_rounded,
                  color: AppTheme.textSecondary, size: 28),
              SizedBox(width: 12),
              Text('Game ended — no winner claimed',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600)),
            ]),
    );
  }

  Widget _buildCancelledBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: const Row(children: [
        Icon(Icons.cancel_outlined, color: Colors.red, size: 24),
        SizedBox(width: 12),
        Text(
          'This game was cancelled by the host',
          style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
      ]),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow(Room room) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatChip(
            icon: Icons.people_outline,
            label: '${_members.length} players',
          ),
          const SizedBox(width: 10),
          _StatChip(
            icon: Icons.casino_outlined,
            label: '${room.calledNumbers.length}/${room.maxNumber} called',
            highlight: room.isPlaying,
          ),
          const SizedBox(width: 10),
          _StatChip(
            icon: Icons.grid_3x3,
            label: '1–${room.maxNumber}',
          ),
          if (room.suggestionMode) ...[
            const SizedBox(width: 10),
            _StatChip(
              icon: Icons.lightbulb_rounded,
              label: 'Hints ON',
              iconColor: AppTheme.accent,
            ),
          ],
        ],
      ),
    );
  }

  // ── Number board ───────────────────────────────────────────────────────────

  Widget _buildNumberBoardSection(Room room) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(children: [
              const Icon(Icons.dashboard_rounded,
                  size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('NUMBER BOARD',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: AppTheme.textSecondary,
                  )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.4)),
                ),
                child: Text(
                  '${room.calledNumbers.length} called',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: NumberBoardWidget(
              maxNumber: room.maxNumber,
              calledNumbers: room.calledNumbers,
              lastCalled: room.lastCalled,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Player card — expandable, shows read-only ticket
// ─────────────────────────────────────────────────────────────────────────────

class _SpectatePlayerCard extends StatefulWidget {
  final RoomMember member;
  final Room room;
  final int rank;

  const _SpectatePlayerCard({
    super.key,
    required this.member,
    required this.room,
    required this.rank,
  });

  @override
  State<_SpectatePlayerCard> createState() => _SpectatePlayerCardState();
}

class _SpectatePlayerCardState extends State<_SpectatePlayerCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final room = widget.room;
    final isWinner = member.hasClaimedHousie;
    final isHost = member.userId == room.hostId;

    // For live games use calledNumbers directly (suggestion-mode-style count)
    final matched = TicketGenerator.countMatched(
        member.ticket, room.calledNumbers);
    final marked = TicketGenerator.countMatched(
        member.ticket, member.markedNumbers);
    final totalCells = member.ticket
        .expand((r) => r)
        .where((c) => c != null)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner
              ? AppTheme.accent.withOpacity(0.6)
              : isHost
                  ? AppTheme.primary.withOpacity(0.4)
                  : AppTheme.border,
          width: isWinner ? 1.5 : 1,
        ),
        boxShadow: isWinner
            ? [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          // ── Card header ───────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  _buildRankBadge(isWinner, isHost),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(
                              member.username,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isWinner
                                    ? AppTheme.accent
                                    : AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isHost) ...[
                            const SizedBox(width: 6),
                            _badge('HOST', AppTheme.primary),
                          ],
                          if (isWinner) ...[
                            const SizedBox(width: 6),
                            _badge('🏆 HOUSIE', AppTheme.accent),
                          ],
                        ]),
                        const SizedBox(height: 3),
                        Text(
                          room.isPlaying
                              ? '$matched/$totalCells on ticket  •  $marked/$totalCells marked'
                              : '$matched/$totalCells called on ticket  •  $marked/$totalCells marked',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Progress pill — glows when all matched
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: matched == totalCells && totalCells > 0
                          ? AppTheme.accent.withOpacity(0.15)
                          : AppTheme.bgCardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: matched == totalCells && totalCells > 0
                              ? AppTheme.accent.withOpacity(0.5)
                              : AppTheme.border),
                    ),
                    child: Text(
                      '$matched/$totalCells',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: matched == totalCells && totalCells > 0
                            ? AppTheme.accent
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: AppTheme.textSecondary, size: 20),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded ticket ───────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _LegendDot(
                          color: AppTheme.primary.withOpacity(0.8),
                          label: 'Called & marked'),
                      _LegendDot(
                          color: AppTheme.accent.withOpacity(0.7),
                          label: 'Called, not marked'),
                      _LegendDot(
                          color: AppTheme.bgCardLight,
                          label: 'Not called'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ReadOnlyTicket(
                    ticket: member.ticket,
                    calledNumbers: room.calledNumbers,
                    markedNumbers: member.markedNumbers,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRankBadge(bool isWinner, bool isHost) {
    if (isWinner) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 10),
          ],
        ),
        child: const Center(
            child: Text('🏆', style: TextStyle(fontSize: 16))),
      );
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHost
              ? [AppTheme.primary, AppTheme.primaryLight]
              : [AppTheme.bgCardLight, AppTheme.border],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '#${widget.rank}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isHost ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Read-only ticket grid
// ─────────────────────────────────────────────────────────────────────────────

class _ReadOnlyTicket extends StatelessWidget {
  final List<List<int?>> ticket;
  final List<int> calledNumbers;
  final List<int> markedNumbers;

  const _ReadOnlyTicket({
    required this.ticket,
    required this.calledNumbers,
    required this.markedNumbers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ticket.map((row) {
        return Row(
          children: row.map((cell) {
            if (cell == null) return Expanded(child: _emptyCell());
            final isCalled = calledNumbers.contains(cell);
            final isMarked = markedNumbers.contains(cell);
            return Expanded(child: _numberCell(cell, isCalled, isMarked));
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _emptyCell() => Container(
        height: 38,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppTheme.bgDark.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
        ),
      );

  Widget _numberCell(int number, bool isCalled, bool isMarked) {
    final Color bg;
    final Color textColor;
    final Color? borderColor;

    if (isCalled && isMarked) {
      bg = AppTheme.primary.withOpacity(0.8);
      textColor = Colors.white;
      borderColor = AppTheme.primary;
    } else if (isCalled && !isMarked) {
      bg = AppTheme.accent.withOpacity(0.2);
      textColor = AppTheme.accent;
      borderColor = AppTheme.accent.withOpacity(0.6);
    } else {
      bg = AppTheme.bgCardLight;
      textColor = AppTheme.textSecondary;
      borderColor = null;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 38,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: borderColor != null
            ? Border.all(color: borderColor, width: 1)
            : null,
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isCalled ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Animated green pulsing dot for live status.
class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppTheme.secondary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  final Color? iconColor;

  const _StatChip({
    required this.icon,
    required this.label,
    this.highlight = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ??
        (highlight ? AppTheme.secondary : AppTheme.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: highlight
                ? AppTheme.secondary.withOpacity(0.4)
                : AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}
