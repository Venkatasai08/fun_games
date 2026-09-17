// lib/draftclash/widgets/admin/ai_character_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/deepseek_service.dart';
import '../../utils/admin_theme.dart';

class AiCharacterCard extends StatelessWidget {
  final GeneratedCharacter character;
  final int index;
  final VoidCallback onToggle;
  final ValueChanged<double> onLevelChanged;

  const AiCharacterCard({
    super.key,
    required this.character,
    required this.index,
    required this.onToggle,
    required this.onLevelChanged,
  });

  Color  get _tc => tierColor(character.level);
  String get _tl => tierLabel(character.level);

  static String _ld(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  String get _previewUrl =>
      character.imageUrl.isNotEmpty ? character.imageUrl : character.rawImageUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: character.selected ? kAdminSurf : kAdminBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: character.selected ? _tc.withOpacity(0.45) : kAdminBdr,
            width: character.selected ? 1.5 : 1,
          ),
          boxShadow: character.selected
              ? [BoxShadow(color: _tc.withOpacity(0.08),
                  blurRadius: 12, offset: const Offset(0, 3))]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: character.selected ? _tc : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: character.selected ? _tc : kAdminBdr, width: 1.5),
              ),
              child: character.selected
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_previewUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(_previewUrl,
                          width: 48, height: 48, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _noImg()),
                    )
                  else
                    _noImg(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(character.name,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                              color: character.selected ? kAdminTxtPri : kAdminTxtMut)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _tc.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _tc.withOpacity(0.35)),
                        ),
                        child: Text(_tl,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                                color: _tc, letterSpacing: 0.8)),
                      ),
                    ]),
                  ),
                ]),
                if (character.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(character.description,
                      style: const TextStyle(fontSize: 12, color: kAdminTxtMut, height: 1.45)),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _tc.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: _tc.withOpacity(0.4)),
                    ),
                    child: Text('Lv ${_ld(character.level)}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _tc)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor:   _tc,
                        inactiveTrackColor: kAdminRaised,
                        thumbColor:         _tc,
                        overlayColor:       _tc.withOpacity(0.15),
                        trackHeight:        4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        value: character.level,
                        min: 1.0, max: 10.0, divisions: 90,
                        onChanged: onLevelChanged,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Clipboard.setData(ClipboardData(text: character.name));
                    },
                    child: const Icon(Icons.copy_rounded, size: 14, color: kAdminTxtMut),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _noImg() => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(color: kAdminRaised, borderRadius: BorderRadius.circular(8)),
    child: const Icon(Icons.person_outline, color: kAdminTxtMut, size: 22),
  );
}
