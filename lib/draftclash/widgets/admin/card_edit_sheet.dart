// lib/draftclash/widgets/admin/card_edit_sheet.dart
//
// Dual-mode bottom sheet:
//   • Add mode  — card == null, franchiseId + franchiseName required
//   • Edit mode — card != null, franchise taken from card
//
// Franchise list in edit mode comes from DraftCatalogCubit (already loaded)
// via didChangeDependencies — no Firebase call needed.
//
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../cubit/draft_catalog_cubit.dart';
import '../../models/draft_card.dart';
import '../../models/draft_franchise.dart';
import '../../services/cloudinary_service.dart';
import '../../utils/admin_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Image source enum
// ─────────────────────────────────────────────────────────────────────────────

enum ImgSource { gallery, url }

// ─────────────────────────────────────────────────────────────────────────────
// CardEditSheet
// ─────────────────────────────────────────────────────────────────────────────

class CardEditSheet extends StatefulWidget {
  final DraftCard? card;
  final String? franchiseId;
  final String? franchiseName;
  final Future<void> Function(DraftCard result) onSaved;

  const CardEditSheet({
    super.key,
    this.card,
    this.franchiseId,
    this.franchiseName,
    required this.onSaved,
  }) : assert(
          card != null || (franchiseId != null && franchiseName != null),
          'franchiseId and franchiseName are required in Add mode',
        );

  bool get isAddMode => card == null;

  @override
  State<CardEditSheet> createState() => _CardEditSheetState();
}

class _CardEditSheetState extends State<CardEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _urlCtrl;
  late double _level;

  ImgSource _imgSource       = ImgSource.url;
  File?     _pickedFile;
  bool      _urlPreviewError = false;
  bool      _saving          = false;
  String    _savingStatus    = '';

  // ── Multi-franchise state (edit mode only) ────────────────────────────────
  List<DraftFranchise> _allFranchises     = [];
  bool                 _loadingFranchises = true;  // true until didChangeDependencies runs
  late Set<String>     _editableFranchiseIds;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.card?.name ?? '');
    _descCtrl = TextEditingController(text: widget.card?.description ?? '');
    _urlCtrl  = TextEditingController(text: widget.card?.imageUrl ?? '');
    _level    = widget.card?.level ?? 5.0;
    _editableFranchiseIds = Set.from(widget.card?.franchiseIds ?? []);
    // Franchise list is populated in didChangeDependencies from the cubit.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Populate franchise list from the session cubit — no Firebase call needed.
    // Called once after initState when the widget is fully in the tree.
    if (!widget.isAddMode && _loadingFranchises) {
      final catalog = context.read<DraftCatalogCubit>();
      if (catalog.state.allFranchises.isNotEmpty) {
        setState(() {
          _allFranchises     = catalog.state.allFranchises;
          _loadingFranchises = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Color  get _tc => tierColor(_level);
  String get _tl => tierLabel(_level);
  String get _ld => _level == _level.roundToDouble()
      ? _level.toInt().toString() : _level.toStringAsFixed(1);

  List<String> get _effectiveFranchiseIds =>
      widget.isAddMode ? [widget.franchiseId!] : _editableFranchiseIds.toList();

  String get _effectiveFranchiseName =>
      widget.isAddMode ? widget.franchiseName! : widget.card!.franchiseName;

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85,
    );
    if (picked == null) return;
    setState(() { _pickedFile = File(picked.path); _imgSource = ImgSource.gallery; });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() { _saving = true; _savingStatus = 'Uploading image…'; });

    String finalUrl = widget.card?.imageUrl ?? '';

    try {
      if (_imgSource == ImgSource.gallery && _pickedFile != null) {
        finalUrl = await CloudinaryService.uploadImage(_pickedFile!);
      } else if (_imgSource == ImgSource.url) {
        final typed = _urlCtrl.text.trim();
        if (typed.isNotEmpty && typed != (widget.card?.imageUrl ?? '')) {
          finalUrl = await CloudinaryService.uploadImageFromUrl(typed);
          if (finalUrl.isEmpty) finalUrl = typed;
        } else {
          finalUrl = typed;
        }
      }

      setState(() => _savingStatus = widget.isAddMode ? 'Adding card…' : 'Saving card…');

      final result = DraftCard(
        id:            widget.card?.id ?? '',
        franchiseIds:  _effectiveFranchiseIds,
        franchiseName: _effectiveFranchiseName,
        name:          _nameCtrl.text.trim(),
        description:   _descCtrl.text.trim(),
        level:         _level,
        imageUrl:      finalUrl,
      );

      await widget.onSaved(result);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() { _saving = false; _savingStatus = ''; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: kAdminRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isAdd  = widget.isAddMode;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottom),
      decoration: const BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: kAdminBdr, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: (isAdd ? kAdminAmber : kAdminViolet).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: (isAdd ? kAdminAmber : kAdminViolet).withOpacity(0.4)),
                ),
                child: Icon(isAdd ? Icons.add_card_rounded : Icons.edit_rounded,
                    color: isAdd ? kAdminAmber : kAdminViolet, size: 18),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isAdd ? 'Add Card' : 'Edit Card',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kAdminTxtPri)),
                Text(_effectiveFranchiseName,
                    style: TextStyle(fontSize: 11, color: kAdminViolet.withOpacity(0.85))),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: _saving ? null : () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded, color: kAdminTxtMut, size: 20),
              ),
            ]),
            const SizedBox(height: 20),

            const CardSheetSectionLabel(label: 'Character Image', icon: Icons.image_rounded),
            const SizedBox(height: 10),
            CardImgSourceToggle(
              selected: _imgSource,
              onChanged: _saving ? null : (s) => setState(() => _imgSource = s),
            ),
            const SizedBox(height: 12),

            if (_imgSource == ImgSource.gallery)
              CardGalleryPicker(pickedFile: _pickedFile, disabled: _saving, onPick: _pickFromGallery),

            if (_imgSource == ImgSource.url)
              CardUrlImageInput(
                controller: _urlCtrl,
                tierColor: _tc,
                disabled: _saving,
                onChanged: (_) => setState(() => _urlPreviewError = false),
                previewError: _urlPreviewError,
                onPreviewError: () => setState(() => _urlPreviewError = true),
              ),

            const SizedBox(height: 16),
            if (!widget.isAddMode) ..._buildFranchisesSection(),

            const CardSheetSectionLabel(label: 'Card Details', icon: Icons.style_rounded),
            const SizedBox(height: 10),
            CardSheetField(controller: _nameCtrl, label: 'Character Name', icon: Icons.person_outline),
            const SizedBox(height: 12),
            CardSheetField(controller: _descCtrl, label: 'Description', icon: Icons.description_outlined, maxLines: 2),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kAdminRaised,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _tc.withOpacity(0.25)),
              ),
              child: Column(children: [
                Row(children: [
                  const Text('Power Level',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kAdminTxtPri)),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _tc.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _tc.withOpacity(0.4)),
                    ),
                    child: Text('$_ld · $_tl',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _tc, letterSpacing: 0.5)),
                  ),
                ]),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor:   _tc,
                    inactiveTrackColor: kAdminBdr,
                    thumbColor:         _tc,
                    overlayColor:       _tc.withOpacity(0.2),
                    trackHeight: 5,
                  ),
                  child: Slider(
                    value: _level, min: 1.0, max: 10.0, divisions: 90,
                    onChanged: _saving ? null : (v) => setState(() => _level = v),
                  ),
                ),
                const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('1.0  COMMON', style: TextStyle(fontSize: 9.5, color: kAdminTxtMut)),
                  Text('LEGENDARY  10.0', style: TextStyle(fontSize: 9.5, color: kAdminTxtMut)),
                ]),
              ]),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAdd ? kAdminAmber : kAdminViolet,
                  foregroundColor: isAdd ? const Color(0xFF1A0E00) : Colors.white,
                  disabledBackgroundColor: (isAdd ? kAdminAmber : kAdminViolet).withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        const SizedBox(width: 12),
                        Text(_savingStatus,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ])
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(isAdd ? Icons.add_card_rounded : Icons.save_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(isAdd ? 'Add Card' : 'Save Changes',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Franchises multi-select section (edit mode only) ──────────────────────
  List<Widget> _buildFranchisesSection() {
    return [
      const CardSheetSectionLabel(
          label: 'Linked Franchises', icon: Icons.collections_bookmark_rounded),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kAdminRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kAdminBdr),
        ),
        child: _loadingFranchises
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                      color: kAdminViolet, strokeWidth: 2),
                ))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8, runSpacing: 6,
                    children: [
                      ..._editableFranchiseIds.map((id) {
                        final f = _allFranchises
                            .where((f) => f.id == id)
                            .firstOrNull;
                        final name = f?.name ?? id;
                        final isPrimary = id == (widget.card?.franchiseId ?? '');
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: kAdminViolet.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: kAdminViolet.withOpacity(0.45)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (isPrimary)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.star_rounded,
                                    size: 11, color: kAdminAmber),
                              ),
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: kAdminViolet)),
                            if (!isPrimary) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => setState(
                                    () => _editableFranchiseIds.remove(id)),
                                child: const Icon(Icons.close_rounded,
                                    size: 12, color: kAdminViolet),
                              ),
                            ],
                          ]),
                        );
                      }),
                      GestureDetector(
                        onTap: () => _showFranchisePicker(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: kAdminAmber.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: kAdminAmber.withOpacity(0.45)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded,
                                  size: 13, color: kAdminAmber),
                              SizedBox(width: 4),
                              Text('Add Franchise',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: kAdminAmber)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.card!.franchiseId.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.star_rounded,
                          size: 10, color: kAdminAmber),
                      const SizedBox(width: 4),
                      Text(
                        'Primary franchise cannot be removed',
                        style: TextStyle(
                            fontSize: 9.5,
                            color: kAdminTxtMut.withOpacity(0.6)),
                      ),
                    ]),
                  ],
                ],
              ),
      ),
      const SizedBox(height: 16),
    ];
  }

  void _showFranchisePicker() {
    final remaining = _allFranchises
        .where((f) => !_editableFranchiseIds.contains(f.id))
        .toList();
    if (remaining.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('All franchises are already linked',
            style: TextStyle(color: Colors.white)),
        backgroundColor: kAdminTxtMut,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FranchisePickerSheet(
        franchises: remaining,
        onSelect: (f) {
          setState(() => _editableFranchiseIds.add(f.id));
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Franchise picker sheet
// ─────────────────────────────────────────────────────────────────────────────

class _FranchisePickerSheet extends StatelessWidget {
  final List<DraftFranchise> franchises;
  final void Function(DraftFranchise) onSelect;
  const _FranchisePickerSheet(
      {required this.franchises, required this.onSelect});

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
            decoration: BoxDecoration(
                color: kAdminBdr, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        const Row(children: [
          Icon(Icons.collections_bookmark_rounded, size: 16, color: kAdminViolet),
          SizedBox(width: 8),
          Text('Add to Franchise',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kAdminTxtPri)),
        ]),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: franchises.length,
            itemBuilder: (_, i) {
              final f = franchises[i];
              return GestureDetector(
                onTap: () => onSelect(f),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: kAdminRaised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kAdminBdr),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: kAdminViolet.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kAdminViolet.withOpacity(0.3)),
                      ),
                      child: f.imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.network(f.imageUrl, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.movie_outlined, size: 16, color: kAdminViolet)))
                          : const Icon(Icons.movie_outlined, size: 16, color: kAdminViolet),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(f.name, style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold, color: kAdminTxtPri)),
                        Text('${f.cardCount} cards',
                            style: const TextStyle(fontSize: 10, color: kAdminTxtMut)),
                      ]),
                    ),
                    const Icon(Icons.add_circle_outline_rounded, size: 18, color: kAdminViolet),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image source toggle
// ─────────────────────────────────────────────────────────────────────────────

class CardImgSourceToggle extends StatelessWidget {
  final ImgSource selected;
  final ValueChanged<ImgSource>? onChanged;
  const CardImgSourceToggle({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    return Row(children: [
      Expanded(child: _SourceCard(
        icon: Icons.photo_library_rounded, label: 'Gallery', sublabel: 'Pick from device',
        active: selected == ImgSource.gallery, activeColor: kAdminGreen,
        disabled: disabled, onTap: disabled ? null : () => onChanged!(ImgSource.gallery),
      )),
      const SizedBox(width: 10),
      Expanded(child: _SourceCard(
        icon: Icons.travel_explore_rounded, label: 'Network URL', sublabel: 'Paste image link',
        active: selected == ImgSource.url, activeColor: kAdminViolet,
        disabled: disabled, onTap: disabled ? null : () => onChanged!(ImgSource.url),
      )),
    ]);
  }
}

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final bool active, disabled;
  final Color activeColor;
  final VoidCallback? onTap;
  const _SourceCard({
    required this.icon, required this.label, required this.sublabel,
    required this.active, required this.activeColor,
    required this.disabled, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(0.10) : kAdminRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? activeColor.withOpacity(0.55) : kAdminBdr,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [BoxShadow(color: activeColor.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: active ? activeColor.withOpacity(0.18) : kAdminBdr.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: active ? activeColor : kAdminTxtMut),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold,
                  color: active ? activeColor : kAdminTxtPri)),
              const SizedBox(height: 1),
              Text(sublabel, style: TextStyle(fontSize: 9.5,
                  color: active ? activeColor.withOpacity(0.7) : kAdminTxtMut)),
            ]),
          ),
          if (active)
            Container(width: 7, height: 7,
                decoration: BoxDecoration(color: activeColor, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: activeColor.withOpacity(0.5), blurRadius: 5)])),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gallery picker
// ─────────────────────────────────────────────────────────────────────────────

class CardGalleryPicker extends StatelessWidget {
  final File? pickedFile;
  final bool disabled;
  final VoidCallback onPick;
  const CardGalleryPicker({super.key, required this.pickedFile, required this.disabled, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onPick,
      child: Container(
        width: double.infinity, height: 165,
        decoration: BoxDecoration(
          color: kAdminRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: pickedFile != null ? kAdminGreen.withOpacity(0.5) : kAdminBdr,
            width: pickedFile != null ? 1.5 : 1,
          ),
        ),
        child: pickedFile != null
            ? Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(13),
                    child: Image.file(pickedFile!, width: double.infinity, height: 130, fit: BoxFit.cover)),
                Positioned(bottom: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text('Change', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ]),
                  ),
                ),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: kAdminViolet.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.add_photo_alternate_rounded, color: kAdminViolet, size: 22),
                ),
                const SizedBox(height: 8),
                const Text('Tap to pick from gallery',
                    style: TextStyle(color: kAdminTxtMut, fontSize: 12.5)),
              ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// URL image input with live preview
// ─────────────────────────────────────────────────────────────────────────────

class CardUrlImageInput extends StatelessWidget {
  final TextEditingController controller;
  final Color tierColor;
  final bool disabled;
  final ValueChanged<String> onChanged;
  final bool previewError;
  final VoidCallback onPreviewError;

  const CardUrlImageInput({
    super.key,
    required this.controller,
    required this.tierColor,
    required this.disabled,
    required this.onChanged,
    required this.previewError,
    required this.onPreviewError,
  });

  @override
  Widget build(BuildContext context) {
    final url = controller.text.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: controller,
        enabled: !disabled,
        onChanged: onChanged,
        style: const TextStyle(color: kAdminTxtPri, fontSize: 13),
        decoration: InputDecoration(
          labelText: 'Image URL',
          labelStyle: const TextStyle(color: kAdminTxtMut, fontSize: 12),
          hintText: 'https://example.com/image.jpg',
          hintStyle: TextStyle(color: kAdminTxtMut.withOpacity(0.35), fontSize: 12),
          prefixIcon: const Icon(Icons.link_rounded, color: kAdminTxtMut, size: 18),
          filled: true, fillColor: kAdminRaised,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kAdminBdr)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kAdminViolet, width: 1.5)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kAdminBdr)),
        ),
      ),
      if (url.isNotEmpty) ...[
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: previewError
              ? Container(
                  width: double.infinity, height: 80,
                  decoration: BoxDecoration(color: kAdminRaised,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kAdminRed.withOpacity(0.4))),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.broken_image_outlined, color: kAdminRed, size: 22),
                    SizedBox(height: 4),
                    Text('Cannot load preview', style: TextStyle(color: kAdminRed, fontSize: 10.5)),
                  ]),
                )
              : Image.network(url, width: double.infinity, height: 110, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => onPreviewError());
                    return const SizedBox.shrink();
                  },
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(height: 110, color: kAdminRaised,
                          child: const Center(child: CircularProgressIndicator(
                              color: kAdminViolet, strokeWidth: 2)))),
        ),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sheet helpers
// ─────────────────────────────────────────────────────────────────────────────

class CardSheetSectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const CardSheetSectionLabel({super.key, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: kAdminViolet),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
          color: kAdminTxtMut, letterSpacing: 0.7)),
    ]);
  }
}

class CardSheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const CardSheetField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(color: kAdminTxtPri, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kAdminTxtMut, fontSize: 12),
        prefixIcon: Icon(icon, color: kAdminTxtMut, size: 18),
        filled: true, fillColor: kAdminRaised,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kAdminBdr)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kAdminViolet, width: 1.5)),
      ),
    );
  }
}

class CardTierBadge extends StatelessWidget {
  final String label;
  final Color color;
  const CardTierBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold,
              color: color, letterSpacing: 0.8)),
    );
  }
}
