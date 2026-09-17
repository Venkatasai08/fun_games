// lib/draftclash/widgets/admin/admin_section_label.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class AdminSectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const AdminSectionLabel({super.key, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 15, color: kAdminViolet),
      const SizedBox(width: 7),
      Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: kAdminTxtMut, letterSpacing: 0.8)),
    ]);
  }
}
