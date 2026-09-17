// lib/draftclash/widgets/admin/admin_stats_shimmer.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/admin_theme.dart';

class AdminStatsShimmer extends StatelessWidget {
  const AdminStatsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: List.generate(3, (i) => Expanded(
      child: Container(
        height: 96,
        margin: EdgeInsets.only(left: i == 0 ? 0 : 12),
        decoration: BoxDecoration(
          color: kAdminSurf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kAdminBdr),
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 1200.ms, color: kAdminRaised),
    )));
  }
}
