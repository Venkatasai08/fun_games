// lib/draftclash/widgets/admin/ai_not_configured_banner.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class AiNotConfiguredBanner extends StatelessWidget {
  const AiNotConfiguredBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kAdminRed.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAdminRed.withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.key_off_rounded, color: kAdminRed, size: 18),
          SizedBox(width: 9),
          Text('Groq API key not configured',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kAdminRed)),
        ]),
        const SizedBox(height: 10),
        const Text('Add the key at build/run time using --dart-define:',
            style: TextStyle(fontSize: 12, color: kAdminTxtMut)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kAdminBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAdminBdr)),
          child: const Text('--dart-define=GROQ_API_KEY=gsk_...',
              style: TextStyle(fontSize: 11.5, color: kAdminTxtPri, fontFamily: 'monospace')),
        ),
        const SizedBox(height: 10),
        const Text('Free key at console.groq.com/keys',
            style: TextStyle(fontSize: 11, color: kAdminTxtMut)),
      ]),
    );
  }
}
