// lib/draftclash/widgets/lobby/lobby_join_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';
import 'lobby_room_card.dart';

const _bg     = Color(0xFF07070F);
const _surf   = Color(0xFF0D0C1E);
const _raised = Color(0xFF14122A);
const _bdr    = Color(0xFF1E1B38);
const _teal   = Color(0xFF00C9A7);
const _red    = Color(0xFFE8445A);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

class LobbyJoinSheet extends StatefulWidget {
  const LobbyJoinSheet({super.key});

  @override
  State<LobbyJoinSheet> createState() => _LobbyJoinSheetState();
}

class _LobbyJoinSheetState extends State<LobbyJoinSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search(BuildContext context) {
    context.read<DraftLobbyBloc>().add(DraftLobbySearchByCode(_ctrl.text));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DraftLobbyBloc, DraftLobbyState>(
      builder: (context, state) {
        final isSearching = state is DraftLobbySearchLoading;
        final result = state is DraftLobbySearchResult ? state : null;
        final myUid = FirebaseAuth.instance.currentUser?.uid;

        return Container(
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _bdr, borderRadius: BorderRadius.circular(2)),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C9A7), Color(0xFF0087A5)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: _teal.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.dialpad_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                    Text('Join by Code',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _txtPri)),
                    Text('Enter the 6-digit room code',
                        style: TextStyle(fontSize: 12, color: _txtMut)),
                  ]),
                ]),
              ),

              const SizedBox(height: 24),

              // Code input + button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      onSubmitted: (_) => _search(context),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _txtPri, fontSize: 26,
                        fontWeight: FontWeight.w900, letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        hintText: '• • • • • •',
                        hintStyle: TextStyle(
                          color: _txtMut.withOpacity(0.25),
                          fontSize: 22, letterSpacing: 6,
                          fontWeight: FontWeight.normal,
                        ),
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        filled: true, fillColor: _raised,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _bdr),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _teal, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 64, height: 64,
                    child: ElevatedButton(
                      onPressed: isSearching ? null : () => _search(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: isSearching
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Icon(Icons.search_rounded, size: 26),
                    ),
                  ),
                ]),
              ),

              // Result area
              if (result != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: result.error != null
                      ? Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _red.withOpacity(0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded, color: _red, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(result.error!,
                                style: const TextStyle(color: _red, fontSize: 13))),
                          ]),
                        ).animate().fadeIn()
                      : result.room != null
                          ? LobbyRoomCard(
                              room: result.room!,
                              isMyRoom: myUid != null && result.room!.isHost(myUid),
                              onJoin: () {
                                Navigator.pop(context);
                                context.read<DraftLobbyBloc>()
                                    .add(DraftLobbyJoinRequested(result.room!.id));
                              },
                            ).animate().fadeIn().slideY(begin: 0.08)
                          : const SizedBox.shrink(),
                ),

              const SizedBox(height: 28),
            ],
          ),
        );
      },
    );
  }
}
