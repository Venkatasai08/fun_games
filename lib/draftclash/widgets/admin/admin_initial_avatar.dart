// lib/draftclash/widgets/admin/admin_initial_avatar.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class AdminInitialAvatar extends StatelessWidget {
  final String name;
  final double fontSize;
  const AdminInitialAvatar({super.key, required this.name, this.fontSize = 20});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: kAdminViolet),
      ),
    );
  }
}
