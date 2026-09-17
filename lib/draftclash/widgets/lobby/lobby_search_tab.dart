// lib/draftclash/widgets/lobby/lobby_search_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';
import 'lobby_room_card.dart';

const _bg = Color(0xFF07070F);
const _surf = Color(0xFF0D0C1E);
const _bdr = Color(0xFF1E1B38);
const _violet = Color(0xFF6E44FF);
const _red = Color(0xFFE8445A);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

class LobbySearchTab extends StatefulWidget {
  const LobbySearchTab({super.key});

  @override
  State<LobbySearchTab> createState() => _LobbySearchTabState();
}

class _LobbySearchTabState extends State<LobbySearchTab> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DraftLobbyBloc, DraftLobbyState>(
      builder: (context, state) {
        final isSearching = state is DraftLobbySearchLoading;
        final result = state is DraftLobbySearchResult ? state : null;
        final myUid = FirebaseAuth.instance.currentUser?.uid;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Find a Room',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _txtPri)),
                const SizedBox(height: 6),
                const Text('Enter the 6-digit room code',
                    style: TextStyle(color: _txtMut, fontSize: 13)),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      onSubmitted: (_) => _search(context),
                      style: const TextStyle(
                        color: _txtPri,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                      decoration: InputDecoration(
                        hintText: '······',
                        hintStyle: TextStyle(
                          color: _txtMut.withOpacity(0.25),
                          fontSize: 20,
                          letterSpacing: 4,
                        ),
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        filled: true,
                        fillColor: _surf,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _bdr),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _violet, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSearching ? null : () => _search(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _violet,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: isSearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Search',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                if (result != null) ...[
                  if (result.error != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _red.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded,
                            color: _red, size: 18),
                        const SizedBox(width: 10),
                        Text(result.error!,
                            style: const TextStyle(color: _red, fontSize: 13)),
                      ]),
                    ).animate().fadeIn()
                  else if (result.room != null)
                    LobbyRoomCard(
                      room: result.room!,
                      isMyRoom: result.room!.id == myUid,
                      onJoin: () => context
                          .read<DraftLobbyBloc>()
                          .add(DraftLobbyJoinRequested(result.room!.id)),
                    ).animate().fadeIn().slideY(begin: 0.08),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _search(BuildContext context) {
    context.read<DraftLobbyBloc>().add(DraftLobbySearchByCode(_ctrl.text));
  }
}
