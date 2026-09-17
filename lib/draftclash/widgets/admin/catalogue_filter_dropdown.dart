// lib/draftclash/widgets/admin/catalogue_filter_dropdown.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class CatalogueFilterDropdown<T> extends StatelessWidget {
  final IconData icon;
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final Color Function(T) itemColor;
  final ValueChanged<T?> onChanged;

  const CatalogueFilterDropdown({
    super.key,
    required this.icon,
    required this.hint,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.itemColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final active = value != null;
    final activeColor = active ? itemColor(value as T) : kAdminViolet;

    return GestureDetector(
      onTap: () => _openPicker(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(0.1) : kAdminSurf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? activeColor.withOpacity(0.6) : kAdminBdr,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: active ? activeColor : kAdminTxtMut),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              active ? itemLabel(value as T) : hint,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? activeColor : kAdminTxtMut,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (active)
            GestureDetector(
              onTap: () => onChanged(null),
              child: Icon(Icons.close_rounded, size: 14, color: activeColor),
            )
          else
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: kAdminTxtMut),
        ]),
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => CatalogueDropdownPicker<T>(
        title: hint, icon: icon,
        items: items, selected: value,
        itemLabel: itemLabel, itemColor: itemColor,
        onSelect: (v) { onChanged(v); Navigator.pop(context); },
      ),
    );
  }
}

class CatalogueDropdownPicker<T> extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<T> items;
  final T? selected;
  final String Function(T) itemLabel;
  final Color Function(T) itemColor;
  final ValueChanged<T?> onSelect;

  const CatalogueDropdownPicker({
    super.key,
    required this.title, required this.icon, required this.items,
    required this.selected, required this.itemLabel,
    required this.itemColor, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: kAdminBdr, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: kAdminViolet.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAdminViolet.withOpacity(0.3)),
            ),
            child: Icon(icon, size: 16, color: kAdminViolet),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
              color: kAdminTxtPri)),
          const Spacer(),
          if (selected != null)
            GestureDetector(
              onTap: () => onSelect(null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kAdminRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kAdminRed.withOpacity(0.3)),
                ),
                child: const Text('Clear',
                    style: TextStyle(fontSize: 11, color: kAdminRed, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        ...items.map((item) {
          final isSelected = selected == item;
          final color = itemColor(item);
          return GestureDetector(
            onTap: () => onSelect(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.12) : kAdminRaised,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: isSelected ? color.withOpacity(0.5) : kAdminBdr,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(itemLabel(item), style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? color : kAdminTxtPri,
                  )),
                ),
                if (isSelected) Icon(Icons.check_circle_rounded, size: 18, color: color),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}
