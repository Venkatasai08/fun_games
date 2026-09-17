// lib/draftclash/widgets/admin/admin_header.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class AdminHeader extends StatelessWidget {
  final VoidCallback onBack;
  const AdminHeader({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: kAdminSurf,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: kAdminBdr),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: kAdminTxtMut, size: 18),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF3A1A8A), kAdminViolet]),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(color: kAdminViolet.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Admin Panel',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: kAdminTxtPri, letterSpacing: 0.5)),
          Text('DraftClash Card Management',
              style: TextStyle(fontSize: 11, color: kAdminTxtMut)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: kAdminGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kAdminGreen.withOpacity(0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
                decoration: const BoxDecoration(color: kAdminGreen, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            const Text('LIVE',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kAdminGreen, letterSpacing: 1.2)),
          ]),
        ),
      ]),
    );
  }
}
