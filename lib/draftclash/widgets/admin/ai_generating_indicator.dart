// lib/draftclash/widgets/admin/ai_generating_indicator.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/admin_theme.dart';

class AiGeneratingIndicator extends StatelessWidget {
  final String franchise;
  const AiGeneratingIndicator({super.key, required this.franchise});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0066CC).withOpacity(0.3)),
      ),
      child: Column(children: [
        const SizedBox(width: 48, height: 48,
            child: CircularProgressIndicator(color: Color(0xFF4DA6FF), strokeWidth: 3))
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 1500.ms, color: const Color(0xFF4DA6FF)),
        const SizedBox(height: 16),
        Text(
          franchise.isNotEmpty
              ? 'Generating $franchise characters…'
              : 'Generating characters…',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: kAdminTxtMut),
        ),
        const SizedBox(height: 6),
        const Text('Fetching preview images — may take a few seconds',
            style: TextStyle(fontSize: 11, color: kAdminTxtMut)),
      ]),
    );
  }
}
