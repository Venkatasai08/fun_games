// lib/draftclash/widgets/lobby/lobby_room_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';
import '../../models/draft_room.dart';
import 'lobby_room_card.dart';

class LobbyRoomList extends StatelessWidget {
  final List<DraftRoom> rooms;
  final bool isFinished;
  const LobbyRoomList({super.key, required this.rooms, this.isFinished = false});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: rooms.length,
      itemBuilder: (_, i) => LobbyRoomCard(
        room: rooms[i],
        isMyRoom: myUid != null && rooms[i].isHost(myUid),
        onJoin: () => context
            .read<DraftLobbyBloc>()
            .add(DraftLobbyJoinRequested(rooms[i].id)),
      ).animate(delay: Duration(milliseconds: 40 * i)).fadeIn(duration: 200.ms).slideX(begin: 0.04),
    );
  }
}
