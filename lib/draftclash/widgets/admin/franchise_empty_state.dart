// lib/draftclash/widgets/admin/franchise_empty_state.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class FranchiseEmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const FranchiseEmptyState({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: kAdminAmber.withOpacity(0.1), shape: BoxShape.circle,
              border: Border.all(color: kAdminAmber.withOpacity(0.3)),
            ),
            child: const Icon(Icons.collections_bookmark_rounded,
                color: kAdminAmber, size: 32),
          ),
          const SizedBox(height: 20),
          const Text('No franchises yet', style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: kAdminTxtPri)),
          const SizedBox(height: 8),
          const Text(
            'Add your first franchise to start building the card catalogue.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: kAdminTxtMut, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Franchise',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAdminAmber, foregroundColor: const Color(0xFF1A0E00),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              elevation: 0,
            ),
          ),
        ]),
      ),
    );
  }
}

class NoFranchiseBanner extends StatelessWidget {
  const NoFranchiseBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAdminAmber.withOpacity(0.07), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminAmber.withOpacity(0.35)),
      ),
      child: const Row(children: [
        Icon(Icons.info_outline_rounded, color: kAdminAmber, size: 16),
        SizedBox(width: 10),
        Expanded(child: Text(
          'No franchises yet. Go to the Franchise tab and add one first.',
          style: TextStyle(color: kAdminAmber, fontSize: 12),
        )),
      ]),
    );
  }
}
