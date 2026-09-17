// lib/draftclash/widgets/lobby/lobby_home_tabs.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';

const _raised = Color(0xFF14122A);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF6E44FF);
const _txtMut = Color(0xFF6A6898);

class LobbyHomeTabs extends StatelessWidget {
  final int tabIndex;
  const LobbyHomeTabs({super.key, required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      child: Container(
        decoration: BoxDecoration(
          color: _raised, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _bdr),
        ),
        child: Row(children: [
          _tab(context, 'Ongoing', 0, Icons.play_circle_outline_rounded),
          _tab(context, 'Finished', 1, Icons.flag_outlined),
        ]),
      ),
    );
  }

  Widget _tab(BuildContext context, String label, int index, IconData icon) {
    final sel = tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => context.read<DraftLobbyBloc>().add(DraftLobbyTabChanged(index)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 230),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: sel ? const LinearGradient(colors: [_violet, Color(0xFF9C70FF)]) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: sel ? Colors.white : _txtMut),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: sel ? Colors.white : _txtMut,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            )),
          ]),
        ),
      ),
    );
  }
}
