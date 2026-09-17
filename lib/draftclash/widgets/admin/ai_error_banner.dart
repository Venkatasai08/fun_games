// lib/draftclash/widgets/admin/ai_error_banner.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class AiErrorBanner extends StatelessWidget {
  final String message;
  const AiErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAdminRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminRed.withOpacity(0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline_rounded, color: kAdminRed, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: const TextStyle(color: kAdminRed, fontSize: 12.5, height: 1.45))),
      ]),
    );
  }
}
