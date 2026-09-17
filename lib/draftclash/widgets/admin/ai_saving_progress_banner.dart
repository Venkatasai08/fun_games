// lib/draftclash/widgets/admin/ai_saving_progress_banner.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class AiSavingProgressBanner extends StatelessWidget {
  final String phase;
  final int done, total;
  final String? label; // optional override for the banner text
  const AiSavingProgressBanner(
      {super.key, required this.phase, required this.done, required this.total, this.label});

  @override
  Widget build(BuildContext context) {
    final isUploading = phase == 'uploading';
    final color  = isUploading ? const Color(0xFF4DA6FF) : kAdminGreen;
    final bannerLabel = label ?? (isUploading
        ? 'Uploading images to Cloudinary…'
        : 'Saving cards to Firebase…');
    final pct = total == 0 ? 0.0 : done / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(bannerLabel,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ),
          Text('$done / $total',
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: kAdminRaised,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }
}
