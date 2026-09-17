// lib/draftclash/widgets/lobby/lobby_home_header.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';

const _surf   = Color(0xFF0D0C1E);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF6E44FF);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

class LobbyHomeHeader extends StatelessWidget {
  const LobbyHomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8C62FF), _violet]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: _violet.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 3))],
            ),
            child: const Icon(Icons.swap_vert_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DRAFT CLASH', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2.5, color: _txtPri)),
              Text('Live Rooms', style: TextStyle(fontSize: 11, color: _txtMut)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.read<DraftLobbyBloc>().add(DraftLobbyLoadRequested()),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _surf, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _bdr),
              ),
              child: const Icon(Icons.refresh_rounded, color: _txtMut, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _surf, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _bdr),
              ),
              child: Center(
                child: user?.email != null
                    ? Text(user!.email![0].toUpperCase(),
                        style: const TextStyle(
                            color: _violet, fontWeight: FontWeight.bold, fontSize: 15))
                    : const Icon(Icons.arrow_back_rounded, color: _txtMut, size: 17),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
