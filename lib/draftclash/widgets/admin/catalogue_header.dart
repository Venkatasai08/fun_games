// lib/draftclash/widgets/admin/catalogue_header.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class CatalogueHeader extends StatelessWidget {
  final int totalShown, totalAll;
  final bool loading;
  final VoidCallback onBack;
  const CatalogueHeader({
    super.key,
    required this.totalShown,
    required this.totalAll,
    required this.loading,
    required this.onBack,
  });

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
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: kAdminViolet.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kAdminViolet.withOpacity(0.4)),
          ),
          child: const Icon(Icons.style_rounded, color: kAdminViolet, size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Card Catalogue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kAdminTxtPri)),
          loading
              ? const Text('Loading…', style: TextStyle(fontSize: 11, color: kAdminTxtMut))
              : Text(
                  totalShown == totalAll
                      ? '$totalAll cards'
                      : '$totalShown of $totalAll shown',
                  style: const TextStyle(fontSize: 11, color: kAdminTxtMut),
                ),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: kAdminGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kAdminGreen.withOpacity(0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 5, height: 5,
                decoration: const BoxDecoration(color: kAdminGreen, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            const Text('LIVE',
                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold,
                    color: kAdminGreen, letterSpacing: 1.2)),
          ]),
        ),
      ]),
    );
  }
}
