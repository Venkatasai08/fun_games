// lib/draftclash/widgets/admin/catalogue_empty_filter.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class CatalogueEmptyFilter extends StatelessWidget {
  final VoidCallback onClear;
  final bool isEmpty;
  const CatalogueEmptyFilter({
    super.key,
    required this.onClear,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(isEmpty ? '🃏' : '🔍', style: const TextStyle(fontSize: 52)),
        const SizedBox(height: 16),
        Text(isEmpty ? 'No cards yet' : 'No cards match',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kAdminTxtPri)),
        const SizedBox(height: 8),
        Text(
          isEmpty
              ? 'Use AI Generate or Add Card to fill the catalogue.'
              : 'Try adjusting your search or filters.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: kAdminTxtMut, fontSize: 13),
        ),
        if (!isEmpty) ...[
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.filter_alt_off_rounded, size: 16, color: kAdminViolet),
            label: const Text('Clear Filters', style: TextStyle(color: kAdminViolet)),
          ),
        ],
      ]),
    );
  }
}
