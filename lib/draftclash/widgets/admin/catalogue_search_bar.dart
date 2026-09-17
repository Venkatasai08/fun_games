// lib/draftclash/widgets/admin/catalogue_search_bar.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class CatalogueSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const CatalogueSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: kAdminTxtPri, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search name, franchise, description…',
        hintStyle: TextStyle(color: kAdminTxtMut.withOpacity(0.5), fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: kAdminTxtMut, size: 20),
        suffixIcon: controller.text.isNotEmpty
            ? GestureDetector(
                onTap: () { controller.clear(); onChanged(''); },
                child: const Icon(Icons.close_rounded, color: kAdminTxtMut, size: 18),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true, fillColor: kAdminSurf,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kAdminBdr),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kAdminViolet, width: 1.5),
        ),
      ),
    );
  }
}
