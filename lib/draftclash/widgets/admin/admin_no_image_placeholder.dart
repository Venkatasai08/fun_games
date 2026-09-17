// lib/draftclash/widgets/admin/admin_no_image_placeholder.dart
import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

class AdminNoImagePlaceholder extends StatelessWidget {
  const AdminNoImagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: kAdminAmber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.add_photo_alternate_rounded, color: kAdminAmber, size: 18),
      ),
      const SizedBox(height: 6),
      const Text('Tap to change image', style: TextStyle(color: kAdminTxtMut, fontSize: 12)),
    ]);
  }
}
