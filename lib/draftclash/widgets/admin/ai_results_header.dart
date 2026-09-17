// lib/draftclash/widgets/admin/ai_results_header.dart
import 'package:flutter/material.dart';
import '../../services/deepseek_service.dart';
import '../../utils/admin_theme.dart';

class AiResultsHeader extends StatelessWidget {
  final List<GeneratedCharacter> characters;
  final String franchise;
  final bool saving;
  final VoidCallback onSelectAll, onDeselectAll, onSave;

  const AiResultsHeader({
    super.key,
    required this.characters,
    required this.franchise,
    required this.saving,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final selected = characters.where((c) => c.selected).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('🎴', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${characters.length} Characters Generated',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                    color: kAdminTxtPri)),
            Text('$selected selected · images upload on Save',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: kAdminTxtMut)),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        GestureDetector(
          onTap: selected == characters.length ? onDeselectAll : onSelectAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: kAdminSurf,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kAdminBdr)),
            child: Text(
              selected == characters.length ? 'Deselect All' : 'Select All',
              style: const TextStyle(fontSize: 11, color: kAdminTxtMut,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.cloud_upload_rounded, size: 14),
          label: Text(saving ? 'Processing…' : 'Save $selected',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: kAdminGreen,
            foregroundColor: const Color(0xFF001A0A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            elevation: 0,
          ),
        ),
      ]),
    ]);
  }
}
