// lib/draftclash/widgets/game/game_skip_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/game/draft_game_bloc.dart';
import '../../services/draft_sound_service.dart';

const _bdr    = Color(0xFF1E1B38);
const _amber  = Color(0xFFF4A11D);
const _red    = Color(0xFFE8445A);
const _raised = Color(0xFF14122A);
const _txtMut = Color(0xFF6A6898);

class GameSkipButton extends StatelessWidget {
  final DraftGameLoaded loaded;
  /// When [compact] is true (default in new layout) renders as a small
  /// icon-only button that fits inside a 60 px column.
  final bool compact;

  const GameSkipButton({super.key, required this.loaded, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final used = loaded.mySkipUsed;

    if (compact) return _compactButton(context, used);
    return _fullButton(context, used);
  }

  Widget _compactButton(BuildContext context, bool used) {
    return GestureDetector(
      onTap: used
          ? null
          : () {
              DraftSoundService.skipUsed();
              context.read<DraftGameBloc>().add(DraftGameSkipRequested());
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: used ? _raised : _amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: used ? _bdr : _amber.withOpacity(0.45),
            width: used ? 1 : 1.5,
          ),
          boxShadow: used
              ? null
              : [BoxShadow(color: _amber.withOpacity(0.18), blurRadius: 10)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              used ? Icons.block_rounded : Icons.skip_next_rounded,
              size: 18,
              color: used ? _txtMut.withOpacity(0.35) : _amber,
            ),
            const SizedBox(height: 3),
            Text(
              used ? 'USED' : 'SKIP',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: used ? _txtMut.withOpacity(0.35) : _amber,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fullButton(BuildContext context, bool used) {
    return SizedBox(
      width: double.infinity,
      height: 38,
      child: OutlinedButton.icon(
        onPressed: used
            ? null
            : () {
                DraftSoundService.skipUsed();
                context.read<DraftGameBloc>().add(DraftGameSkipRequested());
              },
        icon: Icon(
            used ? Icons.block_rounded : Icons.skip_next_rounded, size: 14),
        label: Text(used ? 'Used' : 'Skip',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: used ? _txtMut : _amber,
          side: BorderSide(
              color: used ? _bdr : _amber.withOpacity(0.4)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9)),
          disabledForegroundColor: _txtMut.withOpacity(0.3),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
