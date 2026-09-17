// lib/draftclash/widgets/admin/admin_stats_row.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/admin_theme.dart';
import 'admin_stat_card.dart';

class AdminStatsRow extends StatelessWidget {
  final int total;
  final int franchises;
  const AdminStatsRow({super.key, required this.total, required this.franchises});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: AdminStatCard(
          value: '$total', label: 'Total Cards',
          icon: Icons.style_rounded, color: kAdminViolet,
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: AdminStatCard(
          value: '$franchises', label: 'Franchises',
          icon: Icons.collections_bookmark_rounded, color: kAdminAmber,
        ).animate().fadeIn(duration: 300.ms, delay: 80.ms).slideY(begin: 0.1),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: AdminStatCard(
          value: total >= 12 ? '✓' : '✗',
          label: total >= 12 ? 'Game Ready' : 'Need 12+',
          icon: total >= 12 ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
          color: total >= 12 ? kAdminGreen : kAdminRed,
        ).animate().fadeIn(duration: 300.ms, delay: 160.ms).slideY(begin: 0.1),
      ),
    ]);
  }
}
