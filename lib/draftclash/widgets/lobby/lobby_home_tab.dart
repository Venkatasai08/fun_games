// lib/draftclash/widgets/lobby/lobby_home_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';
import 'lobby_empty_state.dart';
import 'lobby_home_header.dart';
import 'lobby_home_tabs.dart';
import 'lobby_room_list.dart';

const _violet = Color(0xFF6E44FF);

class LobbyHomeTab extends StatelessWidget {
  const LobbyHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DraftLobbyBloc, DraftLobbyState>(
      builder: (context, state) {
        final loaded = state is DraftLobbyLoaded ? state : null;
        final tabIndex = loaded?.tabIndex ?? 0;
        final isLoading = state is DraftLobbyLoading || state is DraftLobbyJoinLoading;
        final ongoing  = loaded?.ongoingRooms ?? [];
        final finished = loaded?.finishedRooms ?? [];

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0A0914), Color(0xFF100E20), Color(0xFF0A0914)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const LobbyHomeHeader(),
                LobbyHomeTabs(tabIndex: tabIndex),
                Expanded(
                  child: isLoading && loaded == null
                      ? const Center(child: CircularProgressIndicator(color: _violet))
                      : RefreshIndicator(
                          onRefresh: () async => context
                              .read<DraftLobbyBloc>()
                              .add(DraftLobbyLoadRequested()),
                          color: _violet,
                          child: tabIndex == 0
                              ? (ongoing.isEmpty
                                  ? LobbyEmptyState(
                                      icon: Icons.sports_esports_outlined,
                                      title: 'No active games',
                                      subtitle: 'Create a room or search by code!')
                                  : LobbyRoomList(rooms: ongoing))
                              : (finished.isEmpty
                                  ? LobbyEmptyState(
                                      icon: Icons.flag_outlined,
                                      title: 'No finished games yet',
                                      subtitle: 'Completed drafts will appear here.')
                                  : LobbyRoomList(rooms: finished, isFinished: true)),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
