// lib/draftclash/widgets/lobby/lobby_room_card.dart
import 'package:flutter/material.dart';
import '../../models/draft_room.dart';
import '../../screens/spectator_screen.dart';
import 'lobby_action_button.dart';
import 'lobby_pill.dart';
import 'lobby_status_badge.dart';

const _surf   = Color(0xFF0D0C1E);
const _raised = Color(0xFF14122A);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF6E44FF);
const _amber  = Color(0xFFF4A11D);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

class LobbyRoomCard extends StatelessWidget {
  final DraftRoom room;
  final bool isMyRoom;
  final VoidCallback onJoin;
  const LobbyRoomCard({
    super.key,
    required this.room,
    required this.isMyRoom,
    required this.onJoin,
  });

  Color get _accentColor {
    if (room.isFinished) return const Color(0xFFFFD700);
    if (room.isDrafting) return _amber;
    return const Color(0xFF3ADE80);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final isFinished = room.isFinished;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMyRoom
              ? _violet.withOpacity(0.55)
              : accent.withOpacity(0.3),
          width: isMyRoom ? 1.5 : 1,
        ),
        boxShadow: room.isDrafting
            ? [BoxShadow(color: _amber.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isFinished
                  ? [const Color(0xFF1A1500), _surf]
                  : room.isDrafting
                      ? [const Color(0xFF1A1000), _surf]
                      : [const Color(0xFF081A0A), _surf],
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [accent, accent.withOpacity(0.1)],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isMyRoom
                                    ? [_violet, const Color(0xFF9C70FF)]
                                    : [_raised, _bdr],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isMyRoom
                                  ? [BoxShadow(color: _violet.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                (room.hostUsername ?? '?').isNotEmpty ? (room.hostUsername ?? '?')[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold,
                                  color: isMyRoom ? Colors.white : _txtMut,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Flexible(
                                    child: Text(
                                      room.roomName ?? 'Draft Room',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _txtPri),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (room.hasPassword) ...[
                                    const SizedBox(width: 5),
                                    const Icon(Icons.lock_rounded, size: 12, color: _amber),
                                  ],
                                ]),
                                const SizedBox(height: 3),
                                Row(children: [
                                  Text(room.hostUsername ?? '—',
                                      style: const TextStyle(color: _txtMut, fontSize: 11)),
                                  if (isMyRoom) ...[
                                    const SizedBox(width: 6),
                                    LobbyPill('HOST', _violet),
                                  ],
                                  const SizedBox(width: 6),
                                  LobbyPill('# ${room.code}', _txtMut),
                                ]),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          LobbyStatusBadge(room: room),
                        ]),
                        const SizedBox(height: 12),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          LobbyInfoPill(icon: Icons.people_outline, label: room.isFull ? '2 / 2' : '1 / 2'),
                          if (room.isPassAndPlay)
                            const LobbyInfoPill(icon: Icons.smartphone_rounded,
                                label: 'Pass & Play', accent: Color(0xFF7B5CFA))
                          else if (room.franchise != null)
                            LobbyInfoPill(icon: Icons.collections_bookmark_rounded, label: room.franchise!, accent: _violet)
                          else
                            const LobbyInfoPill(icon: Icons.auto_awesome_rounded, label: 'All Series'),
                          if (isFinished && room.winnerId != null)
                            LobbyInfoPill(
                              icon: Icons.emoji_events_rounded,
                              label: room.winnerUsername ?? 'Winner',
                              accent: const Color(0xFFFFD700),
                            ),
                        ]),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!isFinished) LobbyActionButton(
                              room: room,
                              isMyRoom: isMyRoom,
                              onJoin: onJoin,
                              onSpectate: room.isDrafting
                                  ? () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => SpectatorScreen(
                                            roomId: room.id),
                                      ))
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
