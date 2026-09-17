// lib/draftclash/widgets/admin/franchise_initial_avatar.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

/// Small avatar showing the first letter of a franchise name.
class FranchiseInitialAvatar extends StatelessWidget {
  final String name;
  const FranchiseInitialAvatar({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: kAdminViolet),
      ),
    );
  }
}
