// lib/draftclash/widgets/admin/catalogue_card_grid_item.dart
import 'package:flutter/material.dart';
import '../../models/draft_card.dart';
import '../../utils/admin_theme.dart';
import 'card_edit_sheet.dart'; // CardTierBadge

class CatalogueCardGridItem extends StatelessWidget {
  final DraftCard card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const CatalogueCardGridItem({
    super.key,
    required this.card,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tc       = tierColor(card.level);
    final tl       = tierLabel(card.level);
    final levelStr = card.level == card.level.roundToDouble()
        ? card.level.toInt().toString()
        : card.level.toStringAsFixed(1);
    final hasImage = card.imageUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.withOpacity(0.28)),
        boxShadow: [BoxShadow(color: tc.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            child: hasImage
                ? Image.network(card.imageUrl, height: 125, width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        CatalogueGridImagePlaceholder(card: card, color: tc))
                : CatalogueGridImagePlaceholder(card: card, color: tc),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.72), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Positioned(bottom: 7, left: 7, child: CardTierBadge(label: tl, color: tc)),
          Positioned(
            top: 7, right: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.60),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tc.withOpacity(0.6), width: 1),
              ),
              child: Text('Lv $levelStr',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: tc)),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(card.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kAdminTxtPri)),
            const SizedBox(height: 2),
            Text(card.franchiseName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: kAdminViolet.withOpacity(0.85),
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: tc.withOpacity(0.15))),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          child: Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: kAdminViolet.withOpacity(0.07),
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(17)),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.edit_rounded, size: 14, color: kAdminViolet),
                    SizedBox(width: 5),
                    Text('Edit', style: TextStyle(fontSize: 11.5,
                        fontWeight: FontWeight.bold, color: kAdminViolet)),
                  ]),
                ),
              ),
            ),
            Container(width: 1, height: 36, color: tc.withOpacity(0.12)),
            Expanded(
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: kAdminRed.withOpacity(0.07),
                    borderRadius: const BorderRadius.only(bottomRight: Radius.circular(17)),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.delete_outline_rounded, size: 14, color: kAdminRed),
                    SizedBox(width: 5),
                    Text('Delete', style: TextStyle(fontSize: 11.5,
                        fontWeight: FontWeight.bold, color: kAdminRed)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class CatalogueGridImagePlaceholder extends StatelessWidget {
  final DraftCard card;
  final Color color;
  const CatalogueGridImagePlaceholder({
    super.key, required this.card, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 95, width: double.infinity,
      color: color.withOpacity(0.07),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12), shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Center(
            child: Text(
              card.name.isNotEmpty ? card.name[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ),
      ]),
    );
  }
}
