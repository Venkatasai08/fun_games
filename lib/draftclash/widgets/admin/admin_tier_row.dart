// lib/draftclash/widgets/admin/admin_tier_row.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class AdminTierRow extends StatelessWidget {
  final String label, icon;
  final int count, total;
  final Color color;
  const AdminTierRow({
    super.key,
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(children: [
      Text(icon, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      SizedBox(
        width: 72,
        child: Text(label,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: kAdminTxtMut, letterSpacing: 0.8)),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: kAdminRaised,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 7,
          ),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 24,
        child: Text('$count',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ),
    ]);
  }
}
