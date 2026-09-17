// lib/draftclash/widgets/admin/admin_action_card.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final List<Color> gradient;
  final Color iconBg;
  final VoidCallback onTap;
  final bool fullWidth;

  const AdminActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradient,
    required this.iconBg,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [gradient[0], kAdminSurf]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: gradient[1].withOpacity(0.35)),
          boxShadow: [
            BoxShadow(color: gradient[1].withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: iconBg.withOpacity(0.2),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: iconBg.withOpacity(0.4)),
            ),
            child: Icon(icon, color: iconBg, size: 22),
          ),
          const SizedBox(height: 14),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kAdminTxtPri)),
          const SizedBox(height: 3),
          Text(sublabel, style: const TextStyle(fontSize: 11, color: kAdminTxtMut)),
          const SizedBox(height: 12),
          Row(children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconBg.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.arrow_forward_rounded, size: 14, color: iconBg),
            ),
          ]),
        ]),
      ),
    );
  }
}
