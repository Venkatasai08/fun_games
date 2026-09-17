// lib/draftclash/widgets/admin/franchise_tile.dart
//
// FranchiseTile — Clean minimal "row card" layout.
// Header: [Avatar] [Name + badges] [AI Generate btn]
// Footer strip: [Edit] [Copy Prompt] [Delete]
//
// All Firebase interactions go through DraftCatalogCubit:
//   • Delete     → cubit.deleteFranchise()
//   • Edit/Save  → cubit.updateFranchise()
//   • Copy Names → cubit.state.cardsForFranchises() — synchronous
//   • AI Gen     → route receives cubit via BlocProvider.value
//
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../cubit/draft_catalog_cubit.dart';
import '../../models/draft_franchise.dart';
import '../../models/franchise_category.dart';
import '../../services/cloudinary_service.dart';
import '../../utils/admin_theme.dart';
import '../../utils/prompt_utils.dart';
import '../../screens/admin_ai_generate_screen.dart';
import 'admin_form_widgets.dart';
import 'copy_prompt_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Category colour — used ONLY for the small badge & avatar ring
// ─────────────────────────────────────────────────────────────────────────────

Color _catColor(FranchiseCategory cat) {
  switch (cat) {
    case FranchiseCategory.anime:
      return const Color(0xFFE879A0); // rose
    case FranchiseCategory.movie:
      return const Color(0xFFE8A23A); // amber
    case FranchiseCategory.comics:
      return const Color(0xFF4A9EE8); // sky
    case FranchiseCategory.game:
      return const Color(0xFF3ACFA8); // teal
    case FranchiseCategory.sports:
      return const Color(0xFF8FD44A); // lime
    case FranchiseCategory.other:
      return kAdminViolet; // violet
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FranchiseTile
// ─────────────────────────────────────────────────────────────────────────────

class FranchiseTile extends StatefulWidget {
  final DraftFranchise franchise;
  const FranchiseTile({super.key, required this.franchise});

  @override
  State<FranchiseTile> createState() => _FranchiseTileState();
}

class _FranchiseTileState extends State<FranchiseTile> {
  bool _copying = false;
  bool _pressed = false;

  DraftFranchise get franchise => widget.franchise;

  // ── Copy Prompt — builds AI prompt using generateCharacters() ─────────────
  Future<void> _copyPrompt(BuildContext ctx) async {
    if (_copying) return;
    setState(() => _copying = true);
    try {
      // Collect already-existing character names for this franchise so the AI
      // doesn't re-generate duplicates.
      final existingCards = List.of(
        ctx
            .read<DraftCatalogCubit>()
            .state
            .cardsForFranchises([franchise.name]),
      )..sort((a, b) => a.name.compareTo(b.name));

      // final excludeNames = existingCards.map((c) => c.name).toList();

      // Generic prompt — reusable across any screen or card type.
      final prompt = generateCharacters(
          seriesName: franchise.name,
          count: 10,
          existingCards: existingCards,
          category: franchise.category.label
          // excludeList: excludeNames,
          );

      await Clipboard.setData(ClipboardData(text: prompt));

      if (ctx.mounted) {
        await showCopyPromptSheet(
          ctx,
          subtitleSuffix: existingCards.isEmpty
              ? ''
              : '(excludes ${existingCards.length} existing cards)',
        );
      }
    } catch (e) {
      if (ctx.mounted) _snack(ctx, 'Error: $e', err: true);
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  // ── Delete All Cards ──────────────────────────────────────────────────────
  Future<void> _confirmDeleteAllCards(BuildContext context) async {
    final cardCount = franchise.cardCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kAdminSurf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6600).withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFFF6600).withOpacity(0.4)),
            ),
            child: const Icon(Icons.delete_sweep_rounded,
                size: 16, color: Color(0xFFFF6600)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Delete All Cards?',
                style: TextStyle(
                    color: kAdminTxtPri,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ]),
        content: Text(
          'This will permanently delete all $cardCount card(s) in "${franchise.name}".\n\nThe franchise itself will NOT be deleted.',
          style: const TextStyle(
              color: kAdminTxtMut, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: kAdminTxtMut)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6600),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Delete All Cards',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final deleted =
          await context.read<DraftCatalogCubit>().deleteCardsForFranchise(franchise);
      if (context.mounted)
        _snack(context,
            deleted == 0
                ? 'No cards found for "${franchise.name}"'
                : '✓ $deleted card(s) deleted from "${franchise.name}"',
            ok: deleted > 0);
    } catch (e) {
      if (context.mounted) _snack(context, 'Error: $e', err: true);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kAdminSurf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: kAdminRed.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: kAdminRed.withOpacity(0.4)),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                size: 16, color: kAdminRed),
          ),
          const SizedBox(width: 10),
          const Text('Delete Franchise?',
              style: TextStyle(
                  color: kAdminTxtPri,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ]),
        content: Text(
          'Delete "${franchise.name}"?\n\nIts ${franchise.cardCount} card(s) will remain but become unlinked.',
          style:
              const TextStyle(color: kAdminTxtMut, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: kAdminTxtMut)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAdminRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<DraftCatalogCubit>().deleteFranchise(franchise.id);
      if (context.mounted)
        _snack(context, '"${franchise.name}" deleted', ok: true);
    } catch (e) {
      if (context.mounted) _snack(context, 'Error: $e', err: true);
    }
  }

  // ── Edit ──────────────────────────────────────────────────────────────────
  Future<void> _openEdit(BuildContext context) async {
    final catalog = context.read<DraftCatalogCubit>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: catalog,
        child: EditFranchiseSheet(franchise: franchise),
      ),
    );
  }

  void _snack(BuildContext ctx, String msg,
      {bool ok = false, bool err = false}) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: err
          ? kAdminRed
          : ok
              ? kAdminGreen
              : kAdminTxtMut,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final catColor = _catColor(franchise.category);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: kAdminSurf,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kAdminBdr, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x28000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Column(children: [
              _buildHeader(context, catColor),
              _buildDivider(),
              _buildFooter(context),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, Color catColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Avatar(franchise: franchise, catColor: catColor),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  franchise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kAdminTxtPri,
                    height: 1.2,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 7),
                Row(children: [
                  _Badge(
                    label:
                        '${franchise.category.emoji}  ${franchise.category.label.toUpperCase()}',
                    color: catColor,
                  ),
                  const SizedBox(width: 6),
                  _Badge(
                    label: '${franchise.cardCount} cards',
                    color: kAdminTxtMut,
                    icon: Icons.style_rounded,
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // AI Generate button
          GestureDetector(
            onTap: () {
              final catalog = context.read<DraftCatalogCubit>();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: catalog,
                    child:
                        AdminAiGenerateScreen(preselectedFranchise: franchise),
                  ),
                ),
              );
            },
            child: Container(
              width: 68,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF0A1829),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFF1E4080), width: 1),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🤖', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 4),
                  Text(
                    'AI Gen',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6AACFF),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Divider ───────────────────────────────────────────────────────────────

  Widget _buildDivider() {
    return Container(height: 1, color: kAdminBdr);
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context) {
    return Column(children: [
      // Row 1 — Edit | Copy Prompt | Delete franchise
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 6),
        child: Row(children: [
          _FooterBtn(
            icon: Icons.edit_rounded,
            label: 'Edit',
            color: kAdminViolet,
            onTap: () => _openEdit(context),
          ),
          const SizedBox(width: 7),
          _FooterBtn(
            icon: _copying
                ? Icons.hourglass_bottom_rounded
                : Icons.auto_awesome_rounded,
            label: _copying ? 'Copying…' : 'Copy Prompt',
            color: kAdminGreen,
            onTap: _copying ? null : () => _copyPrompt(context),
          ),
          const SizedBox(width: 7),
          GestureDetector(
            onTap: () => _confirmDelete(context),
            child: Container(
              width: 36,
              height: 34,
              decoration: BoxDecoration(
                color: kAdminRed.withOpacity(0.10),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: kAdminRed.withOpacity(0.30), width: 1),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 16, color: kAdminRed),
            ),
          ),
        ]),
      ),
      // Row 2 — Delete All Cards (destructive, full-width)
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: GestureDetector(
          onTap: () => _confirmDeleteAllCards(context),
          child: Container(
            height: 34,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6600).withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: const Color(0xFFFF6600).withOpacity(0.30), width: 1),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_sweep_rounded,
                    size: 14, color: Color(0xFFFF6600)),
                SizedBox(width: 6),
                Text(
                  'Delete All Cards',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF6600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Avatar
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final DraftFranchise franchise;
  final Color catColor;
  const _Avatar({required this.franchise, required this.catColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: catColor.withOpacity(0.55), width: 2),
      ),
      child: ClipOval(
        child: franchise.imageUrl.isNotEmpty
            ? Image.network(
                franchise.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _AvatarFill(name: franchise.name, catColor: catColor),
              )
            : _AvatarFill(name: franchise.name, catColor: catColor),
      ),
    );
  }
}

class _AvatarFill extends StatelessWidget {
  final String name;
  final Color catColor;
  const _AvatarFill({required this.name, required this.catColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kAdminRaised,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: catColor,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Badge
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.28), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: color.withOpacity(0.70)),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color.withOpacity(0.85),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FooterBtn
// ─────────────────────────────────────────────────────────────────────────────

class _FooterBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _FooterBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: disabled ? 0.40 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: color.withOpacity(0.25), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color.withOpacity(0.85)),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// AddFranchiseSheet — calls cubit.addFranchise()
// ═════════════════════════════════════════════════════════════════════════════

class AddFranchiseSheet extends StatefulWidget {
  final VoidCallback? onAdded;
  const AddFranchiseSheet({super.key, this.onAdded});

  @override
  State<AddFranchiseSheet> createState() => _AddFranchiseSheetState();
}

class _AddFranchiseSheetState extends State<AddFranchiseSheet> {
  final _nameCtrl = TextEditingController();
  FranchiseCategory _category = FranchiseCategory.anime;
  File? _imageFile;
  String _imageUrl = '';
  bool _uploading = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() {
      _imageFile = file;
      _uploading = true;
      _imageUrl = '';
    });
    try {
      final url = await CloudinaryService.uploadImage(file);
      if (mounted)
        setState(() {
          _imageUrl = url;
          _uploading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _uploading = false;
          _imageFile = null;
        });
      _snack('Upload failed: $e', err: true);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Franchise name is required', err: true);
      return;
    }
    if (_uploading) {
      _snack('Please wait for image upload', err: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<DraftCatalogCubit>().addFranchise(
            name: _nameCtrl.text.trim(),
            imageUrl: _imageUrl,
            category: _category,
          );
      widget.onAdded?.call();
      if (mounted) Navigator.pop(context);
      if (mounted) _snack('✓ "${_nameCtrl.text.trim()}" added!', ok: true);
    } catch (e) {
      _snack(e.toString(), err: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool ok = false, bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: err
          ? kAdminRed
          : ok
              ? kAdminGreen
              : kAdminTxtMut,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kAdminBdr),
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 18),
              decoration: BoxDecoration(
                  color: kAdminBdr, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kAdminAmber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kAdminAmber.withOpacity(0.35)),
              ),
              child: const Icon(Icons.collections_bookmark_rounded,
                  color: kAdminAmber, size: 17),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Franchise',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: kAdminTxtPri)),
                    Text('Add to catalogue',
                        style: TextStyle(fontSize: 11, color: kAdminTxtMut)),
                  ]),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close_rounded,
                  color: kAdminTxtMut, size: 20),
            ),
          ]),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _uploading ? null : _pickImage,
            child: _FranchiseImagePicker(
                uploading: _uploading,
                imageFile: _imageFile,
                imageUrl: _imageUrl),
          ),
          const SizedBox(height: 14),
          AdminField(
              controller: _nameCtrl,
              label: 'Franchise Name *',
              icon: Icons.movie_outlined,
              hint: 'e.g. Naruto, Marvel, FC Barcelona'),
          const SizedBox(height: 14),
          const Align(
            alignment: Alignment.centerLeft,
            child:
                _SectionLabel(label: 'Category', icon: Icons.category_rounded),
          ),
          const SizedBox(height: 8),
          FranchiseCategoryPicker(
              selected: _category,
              onChanged: (cat) => setState(() => _category = cat)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: (_saving || _uploading) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_rounded, size: 18),
              label: Text(_saving ? 'Saving…' : 'Add Franchise',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAdminAmber,
                foregroundColor: const Color(0xFF1A0E00),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EditFranchiseSheet — calls cubit.updateFranchise()
// ═════════════════════════════════════════════════════════════════════════════

class EditFranchiseSheet extends StatefulWidget {
  final DraftFranchise franchise;
  const EditFranchiseSheet({super.key, required this.franchise});

  @override
  State<EditFranchiseSheet> createState() => _EditFranchiseSheetState();
}

class _EditFranchiseSheetState extends State<EditFranchiseSheet> {
  late final TextEditingController _nameCtrl;
  late FranchiseCategory _category;
  late String _imageUrl;
  File? _imageFile;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.franchise.name);
    _category = widget.franchise.category;
    _imageUrl = widget.franchise.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() {
      _imageFile = file;
      _uploading = true;
    });
    try {
      final url = await CloudinaryService.uploadImage(file);
      if (mounted)
        setState(() {
          _imageUrl = url;
          _uploading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _uploading = false;
          _imageFile = null;
        });
      _snack('Upload failed: $e', err: true);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Name cannot be empty', err: true);
      return;
    }
    if (_uploading) {
      _snack('Please wait for image upload', err: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<DraftCatalogCubit>().updateFranchise(
            id: widget.franchise.id,
            name: _nameCtrl.text.trim(),
            imageUrl: _imageUrl,
            category: _category,
          );
      if (mounted) Navigator.pop(context);
      if (mounted) _snack('✓ Franchise updated!', ok: true);
    } catch (e) {
      _snack('Error: $e', err: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool ok = false, bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: err
          ? kAdminRed
          : ok
              ? kAdminGreen
              : kAdminTxtMut,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardBottom = mediaQuery.viewInsets.bottom;
    final safeBottom = mediaQuery.padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + keyboardBottom + safeBottom),
      decoration: BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kAdminBdr),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 18),
                decoration: BoxDecoration(
                    color: kAdminBdr, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kAdminViolet.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kAdminViolet.withOpacity(0.35)),
                ),
                child: const Icon(Icons.edit_rounded,
                    color: kAdminViolet, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Edit Franchise',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: kAdminTxtPri)),
                      Text(widget.franchise.name,
                          style: const TextStyle(
                              fontSize: 11, color: kAdminTxtMut)),
                    ]),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded,
                    color: kAdminTxtMut, size: 20),
              ),
            ]),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _uploading ? null : _pickImage,
              child: _EditFranchiseImagePicker(
                  uploading: _uploading,
                  imageFile: _imageFile,
                  imageUrl: _imageUrl),
            ),
            const SizedBox(height: 14),
            AdminField(
                controller: _nameCtrl,
                label: 'Franchise Name *',
                icon: Icons.movie_outlined,
                hint: 'e.g. Naruto, Marvel, One Piece'),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: _SectionLabel(
                  label: 'Category', icon: Icons.category_rounded),
            ),
            const SizedBox(height: 8),
            FranchiseCategoryPicker(
                selected: _category,
                onChanged: (cat) => setState(() => _category = cat)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_saving || _uploading) ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_saving ? 'Saving…' : 'Save Changes',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAdminViolet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FranchiseCategoryPicker
// ═════════════════════════════════════════════════════════════════════════════

class FranchiseCategoryPicker extends StatelessWidget {
  final FranchiseCategory selected;
  final ValueChanged<FranchiseCategory> onChanged;
  const FranchiseCategoryPicker(
      {super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: FranchiseCategory.values.map((cat) {
        final sel = selected == cat;
        final color = _catColor(cat);
        return GestureDetector(
          onTap: () => onChanged(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: sel ? color.withOpacity(0.14) : kAdminRaised,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: sel ? color.withOpacity(0.55) : kAdminBdr,
                width: 1,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(cat.emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(cat.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? color : kAdminTxtMut,
                  )),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: kAdminTxtMut),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kAdminTxtMut,
              letterSpacing: 0.6)),
    ]);
  }
}

class _FranchiseImagePicker extends StatelessWidget {
  final bool uploading;
  final File? imageFile;
  final String imageUrl;
  const _FranchiseImagePicker(
      {required this.uploading,
      required this.imageFile,
      required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        color: kAdminRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              imageUrl.isNotEmpty ? kAdminGreen.withOpacity(0.45) : kAdminBdr,
          width: 1,
        ),
      ),
      child: uploading
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  CircularProgressIndicator(
                      color: kAdminViolet, strokeWidth: 2),
                  SizedBox(height: 8),
                  Text('Uploading…',
                      style: TextStyle(color: kAdminTxtMut, fontSize: 12)),
                ])
          : imageFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.file(imageFile!,
                      width: double.infinity, height: 100, fit: BoxFit.cover))
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate_rounded,
                      color: kAdminTxtMut.withOpacity(0.5), size: 26),
                  const SizedBox(height: 6),
                  Text('Select franchise logo (optional)',
                      style: TextStyle(
                          color: kAdminTxtMut.withOpacity(0.6), fontSize: 12)),
                ]),
    );
  }
}

class _EditFranchiseImagePicker extends StatelessWidget {
  final bool uploading;
  final File? imageFile;
  final String imageUrl;
  const _EditFranchiseImagePicker(
      {required this.uploading,
      required this.imageFile,
      required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 90,
      decoration: BoxDecoration(
        color: kAdminRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              imageUrl.isNotEmpty ? kAdminGreen.withOpacity(0.45) : kAdminBdr,
          width: 1,
        ),
      ),
      child: uploading
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  CircularProgressIndicator(
                      color: kAdminViolet, strokeWidth: 2),
                  SizedBox(height: 8),
                  Text('Uploading…',
                      style: TextStyle(color: kAdminTxtMut, fontSize: 12)),
                ])
          : imageFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.file(imageFile!,
                      width: double.infinity, height: 90, fit: BoxFit.cover))
              : imageUrl.isNotEmpty
                  ? Stack(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.network(imageUrl,
                              width: double.infinity,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const AdminNoImagePlaceholder())),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(7)),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_rounded,
                                    color: Colors.white, size: 11),
                                SizedBox(width: 4),
                                Text('Change',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 11)),
                              ]),
                        ),
                      ),
                    ])
                  : const AdminNoImagePlaceholder(),
    );
  }
}
