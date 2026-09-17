// lib/draftclash/widgets/admin/catalogue_delete_dialog.dart
import 'package:flutter/material.dart';
import '../../models/draft_card.dart';
import '../../utils/admin_theme.dart';
import 'card_edit_sheet.dart'; // CardTierBadge

class CatalogueDeleteDialog extends StatelessWidget {
  final DraftCard card;
  const CatalogueDeleteDialog({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final tc = tierColor(card.level);
    return Dialog(
      backgroundColor: kAdminSurf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: kAdminRed.withOpacity(0.1), shape: BoxShape.circle,
              border: Border.all(color: kAdminRed.withOpacity(0.4)),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: kAdminRed, size: 28),
          ),
          const SizedBox(height: 16),
          const Text('Delete Card?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kAdminTxtPri)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kAdminRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tc.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: tc.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                child: card.imageUrl.isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(8),
                        child: Image.network(card.imageUrl, width: 36, height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _CardInitial(card: card, color: tc)))
                    : _CardInitial(card: card, color: tc),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(card.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kAdminTxtPri),
                      overflow: TextOverflow.ellipsis),
                  Text(card.franchiseName,
                      style: TextStyle(fontSize: 10.5, color: kAdminViolet.withOpacity(0.8))),
                ]),
              ),
              CardTierBadge(label: tierLabel(card.level), color: tc),
            ]),
          ),
          const SizedBox(height: 12),
          const Text(
            'This cannot be undone. The card will be removed from all future draft rooms.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: kAdminTxtMut, height: 1.5),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAdminTxtMut,
                  side: const BorderSide(color: kAdminBdr),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAdminRed, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _CardInitial extends StatelessWidget {
  final DraftCard card;
  final Color color;
  const _CardInitial({required this.card, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        card.name.isNotEmpty ? card.name[0].toUpperCase() : '?',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
