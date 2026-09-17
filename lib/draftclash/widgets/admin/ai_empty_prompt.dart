// lib/draftclash/widgets/admin/ai_empty_prompt.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class AiEmptyPrompt extends StatelessWidget {
  const AiEmptyPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kAdminBdr),
      ),
      child: const Column(children: [
        Text('🤖', style: TextStyle(fontSize: 48)),
        SizedBox(height: 16),
        Text('Ready to generate',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kAdminTxtPri)),
        SizedBox(height: 8),
        Text(
          'Select a franchise, choose how many characters, and tap Generate.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: kAdminTxtMut, height: 1.5),
        ),
      ]),
    );
  }
}
