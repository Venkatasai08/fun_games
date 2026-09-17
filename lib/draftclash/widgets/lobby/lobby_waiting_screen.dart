// lib/draftclash/widgets/lobby/lobby_waiting_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';
import 'lobby_pulse_rings.dart';

const _bg     = Color(0xFF07070F);
const _surf   = Color(0xFF0D0C1E);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF6E44FF);
const _amber  = Color(0xFFF4A11D);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

class LobbyWaitingScreen extends StatelessWidget {
  final DraftLobbyWaiting state;
  const LobbyWaitingScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(children: [
                GestureDetector(
                  onTap: () =>
                      context.read<DraftLobbyBloc>().add(DraftLobbyCancel()),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _surf, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _bdr),
                    ),
                    child: const Icon(Icons.close_rounded, color: _txtMut, size: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.roomName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: _txtPri)),
                      const Text('Waiting for opponent…',
                          style: TextStyle(fontSize: 11, color: _txtMut)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 48),
              const LobbyPulseRings(),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: state.code));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Code copied!'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF1E1200), Color(0xFF0C0A00)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _amber.withOpacity(0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: _amber.withOpacity(0.25), blurRadius: 32, spreadRadius: 2),
                    ],
                  ),
                  child: Column(children: [
                    Text('ROOM CODE', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: _amber.withOpacity(0.55), letterSpacing: 2,
                    )),
                    const SizedBox(height: 12),
                    Text(
                      state.code.split('').join('  '),
                      style: const TextStyle(
                        fontSize: 44, fontWeight: FontWeight.w900,
                        color: _amber, letterSpacing: 3, height: 1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.copy_rounded, size: 12, color: _txtMut),
                      SizedBox(width: 5),
                      Text('Tap to copy', style: TextStyle(fontSize: 11, color: _txtMut)),
                    ]),
                  ]),
                ),
              ).animate().scale(duration: 480.ms, curve: Curves.elasticOut),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _surf, borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _bdr),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(_violet.withOpacity(0.8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Waiting for opponent to join…',
                      style: TextStyle(fontSize: 13, color: _txtMut)),
                ]),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () =>
                    context.read<DraftLobbyBloc>().add(DraftLobbyCancel()),
                icon: const Icon(Icons.close_rounded, size: 15, color: _txtMut),
                label: const Text('Cancel room',
                    style: TextStyle(color: _txtMut, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


