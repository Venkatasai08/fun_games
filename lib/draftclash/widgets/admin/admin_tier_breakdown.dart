// lib/draftclash/widgets/admin/admin_tier_breakdown.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';
import 'admin_tier_row.dart';

class AdminTierBreakdown extends StatelessWidget {
  final int mythic, legendary, epic, rare, common, total;
  const AdminTierBreakdown({
    super.key,
    required this.mythic,
    required this.legendary,
    required this.epic,
    required this.rare,
    required this.common,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kAdminBdr),
      ),
      child: Column(children: [
        AdminTierRow(label: 'LEGENDARY', count: legendary, total: total, color: kTierLegendary, icon: '🔴'),
        const SizedBox(height: 10),
        AdminTierRow(label: 'MYTHIC',    count: mythic,    total: total, color: kTierMythic,    icon: '👑'),
        const SizedBox(height: 10),
        AdminTierRow(label: 'EPIC',      count: epic,      total: total, color: kTierEpic,      icon: '💜'),
        const SizedBox(height: 10),
        AdminTierRow(label: 'RARE',      count: rare,      total: total, color: kTierRare,      icon: '💙'),
        const SizedBox(height: 10),
        AdminTierRow(label: 'COMMON',    count: common,    total: total, color: kTierCommon,    icon: '🟢'),
      ]),
    );
  }
}
