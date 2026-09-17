// lib/draftclash/widgets/admin/admin_field.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class AdminField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final int maxLines;
  const AdminField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: kAdminTxtPri, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kAdminTxtMut, fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(color: kAdminTxtMut.withOpacity(0.35), fontSize: 12),
        prefixIcon: Icon(icon, color: kAdminTxtMut, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: kAdminRaised,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kAdminBdr),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kAdminAmber, width: 1.5),
        ),
      ),
    );
  }
}
