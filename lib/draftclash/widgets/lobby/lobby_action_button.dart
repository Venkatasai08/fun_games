// lib/draftclash/widgets/lobby/lobby_action_button.dart
import 'package:flutter/material.dart';
import '../../models/draft_room.dart';

const _violet = Color(0xFF6E44FF);
const _green  = Color(0xFF3ADE80);
const _amber  = Color(0xFFF4A11D);

class LobbyActionButton extends StatelessWidget {
  final DraftRoom room;
  final bool isMyRoom;
  final VoidCallback onJoin;
  /// Called when the user taps Spectate. If null, no spectate button shown.
  final VoidCallback? onSpectate;

  const LobbyActionButton({
    super.key,
    required this.room,
    required this.isMyRoom,
    required this.onJoin,
    this.onSpectate,
  });

  @override
  Widget build(BuildContext context) {
    // My own waiting room — reopen
    if (isMyRoom && room.isWaiting) {
      return SizedBox(
        height: 34,
        child: OutlinedButton.icon(
          onPressed: onJoin,
          icon: const Icon(Icons.open_in_new_rounded, size: 13),
          label: const Text('Open'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _violet,
            side: BorderSide(color: _violet.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    // Open slot — join button
    if (room.isWaiting && !isMyRoom) {
      return SizedBox(
        height: 34,
        child: ElevatedButton.icon(
          onPressed: onJoin,
          icon: const Icon(Icons.login_rounded, size: 13),
          label: Text(room.hasPassword ? '🔐 Join' : 'Join'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: const Color(0xFF011A06),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            elevation: 0,
          ),
        ),
      );
    }

    // Ongoing game — spectate button
    if (room.isDrafting && onSpectate != null) {
      return SizedBox(
        height: 34,
        child: OutlinedButton.icon(
          onPressed: onSpectate,
          icon: const Icon(Icons.visibility_rounded, size: 13),
          label: const Text('Watch'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _amber,
            side: BorderSide(color: _amber.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
