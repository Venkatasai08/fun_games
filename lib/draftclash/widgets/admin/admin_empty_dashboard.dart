// lib/draftclash/widgets/admin/admin_empty_dashboard.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class AdminEmptyDashboard extends StatelessWidget {
  final VoidCallback onAdd;
  const AdminEmptyDashboard({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kAdminBdr),
      ),
      child: Column(children: [
        const Text('🃏', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 16),
        const Text('No cards yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kAdminTxtPri)),
        const SizedBox(height: 8),
        const Text(
          'The catalogue is empty. Add cards manually or use the seed option to get started quickly.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: kAdminTxtMut, height: 1.5),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 46,
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Cards', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAdminViolet,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    );
  }
}
