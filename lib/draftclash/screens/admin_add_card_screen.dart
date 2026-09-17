// lib/draftclash/screens/admin_add_card_screen.dart
//
// Tab 1 — Franchises : searchable list with Edit / Delete per tile
// Tab 2 — Add Franchise : inline form to create a new franchise
//
// Uses DraftCatalogCubit for all data — no direct DraftService calls needed.
// Add Franchise calls cubit.addFranchise() which writes Firebase + updates state.
//
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../cubit/draft_catalog_cubit.dart';
import '../models/draft_franchise.dart';
import '../models/franchise_category.dart';
import '../services/cloudinary_service.dart';
import '../utils/admin_theme.dart';
import '../widgets/admin/admin_form_widgets.dart';
import '../widgets/admin/franchise_empty_state.dart';
import '../widgets/admin/franchise_tile.dart';

class AdminAddCardScreen extends StatefulWidget {
  const AdminAddCardScreen({super.key, this.initialTabIndex = 0});
  final int initialTabIndex;

  @override
  State<AdminAddCardScreen> createState() => _AdminAddCardScreenState();
}

class _AdminAddCardScreenState extends State<AdminAddCardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0914), kAdminBg],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            _Header(onBack: () => Navigator.pop(context)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TabBar(controller: _tabs),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const _FranchisesTab(),
                  _AddFranchiseTab(onAdded: () => _tabs.animateTo(0)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: kAdminSurf,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: kAdminBdr),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: kAdminTxtMut, size: 18),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: kAdminAmber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kAdminAmber.withOpacity(0.4)),
          ),
          child: const Icon(Icons.collections_bookmark_rounded,
              color: kAdminAmber, size: 20),
        ),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add Franchise',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: kAdminTxtPri)),
          Text('Manage series & categories',
              style: TextStyle(fontSize: 11, color: kAdminTxtMut)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab bar
// ─────────────────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: kAdminBdr),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF3A1A00), kAdminAmber]),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
                color: kAdminAmber.withOpacity(0.3),
                blurRadius: 8, offset: const Offset(0, 2))
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: kAdminTxtMut,
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: const [
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.collections_bookmark_rounded, size: 16),
            SizedBox(width: 6), Text('Franchises'),
          ])),
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_rounded, size: 16),
            SizedBox(width: 6), Text('Add Franchise'),
          ])),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Franchises list (reads from cubit, no local fetch)
// ─────────────────────────────────────────────────────────────────────────────

class _FranchisesTab extends StatefulWidget {
  const _FranchisesTab();

  @override
  State<_FranchisesTab> createState() => _FranchisesTabState();
}

class _FranchisesTabState extends State<_FranchisesTab> {
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim()));
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<DraftFranchise> _filtered(List<DraftFranchise> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DraftCatalogCubit, DraftCatalogState>(
      builder: (context, catalog) {
        final all      = catalog.allFranchises;
        final loading  = catalog.isLoading;
        final filtered = _filtered(all);
        final isFocused = _searchFocus.hasFocus;
        final hasQuery  = _query.isNotEmpty;

        return Column(children: [
          // ── Creative search bar ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 52,
              decoration: BoxDecoration(
                color: isFocused
                    ? kAdminViolet.withOpacity(0.06) : kAdminRaised,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isFocused
                      ? kAdminViolet.withOpacity(0.7)
                      : hasQuery
                          ? kAdminAmber.withOpacity(0.45) : kAdminBdr,
                  width: isFocused ? 1.5 : 1,
                ),
                boxShadow: isFocused
                    ? [BoxShadow(
                        color: kAdminViolet.withOpacity(0.18),
                        blurRadius: 18, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: isFocused
                        ? LinearGradient(colors: [
                            kAdminViolet.withOpacity(0.25),
                            kAdminViolet.withOpacity(0.05)])
                        : null,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      bottomLeft: Radius.circular(15)),
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        hasQuery
                            ? Icons.manage_search_rounded
                            : Icons.search_rounded,
                        key: ValueKey(hasQuery), size: 20,
                        color: isFocused
                            ? kAdminViolet
                            : hasQuery ? kAdminAmber : kAdminTxtMut,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    style: const TextStyle(
                        color: kAdminTxtPri, fontSize: 14,
                        fontWeight: FontWeight.w500, letterSpacing: 0.2),
                    decoration: InputDecoration(
                      hintText: isFocused
                          ? 'Type a franchise name…'
                          : 'Search franchises…',
                      hintStyle: TextStyle(
                        color: isFocused
                            ? kAdminViolet.withOpacity(0.4)
                            : kAdminTxtMut.withOpacity(0.45),
                        fontSize: 13),
                      border:        InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: true, fillColor: Colors.transparent,
                      isDense: true, contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: hasQuery
                      ? GestureDetector(
                          key: const ValueKey('clear'),
                          onTap: () {
                            _searchCtrl.clear();
                            _searchFocus.unfocus();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: kAdminRed.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: kAdminRed.withOpacity(0.35)),
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 13, color: kAdminRed),
                          ),
                        )
                      : Padding(
                          key: const ValueKey('count'),
                          padding: const EdgeInsets.only(right: 12),
                          child: loading
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: kAdminViolet))
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: kAdminBdr,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('${all.length}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: kAdminTxtMut)),
                                ),
                        ),
                ),
              ]),
            ),
          ),

          // ── Result count hint ──────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: hasQuery && !loading
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 16, 8),
                    child: Row(children: [
                      Container(
                        width: 3, height: 10,
                        decoration: BoxDecoration(
                          color: filtered.isEmpty
                              ? kAdminRed : kAdminViolet,
                          borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        filtered.isEmpty
                            ? 'No franchises match "$_query"'
                            : '${filtered.length} of ${all.length} matching',
                        style: TextStyle(
                          fontSize: 11,
                          color: filtered.isEmpty
                              ? kAdminRed.withOpacity(0.8) : kAdminTxtMut),
                      ),
                    ]),
                  )
                : const SizedBox.shrink(),
          ),

          // ── List ───────────────────────────────────────────────────
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(
                    color: kAdminViolet, strokeWidth: 2))
                : all.isEmpty
                    ? FranchiseEmptyState(onAdd: () {})
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 60, height: 60,
                                  decoration: BoxDecoration(
                                    color: kAdminRaised,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: kAdminBdr),
                                  ),
                                  child: const Icon(
                                      Icons.search_off_rounded,
                                      color: kAdminTxtMut, size: 28),
                                ),
                                const SizedBox(height: 14),
                                Text('"$_query" not found',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: kAdminTxtPri)),
                                const SizedBox(height: 4),
                                const Text('Try a different name',
                                    style: TextStyle(
                                        fontSize: 12, color: kAdminTxtMut)),
                              ],
                            ).animate().fadeIn(duration: 200.ms),
                          )
                        : RefreshIndicator(
                            // Pull-to-refresh forces a full re-fetch.
                            onRefresh: () => context
                                .read<DraftCatalogCubit>()
                                .refresh(),
                            color: kAdminViolet,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 4, 16, 32),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => FranchiseTile(
                                franchise: filtered[i],
                              )
                                  .animate(
                                      delay: Duration(
                                          milliseconds: 35 * i))
                                  .fadeIn(duration: 200.ms)
                                  .slideX(
                                      begin: 0.04,
                                      curve: Curves.easeOutCubic),
                            ),
                          ),
          ),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Add Franchise (calls cubit.addFranchise)
// ─────────────────────────────────────────────────────────────────────────────

class _AddFranchiseTab extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddFranchiseTab({required this.onAdded});

  @override
  State<_AddFranchiseTab> createState() => _AddFranchiseTabState();
}

class _AddFranchiseTabState extends State<_AddFranchiseTab> {
  final _nameCtrl = TextEditingController();
  FranchiseCategory _category = FranchiseCategory.anime;
  File?  _imageFile;
  String _imageUrl  = '';
  bool   _uploading = false;
  bool   _saving    = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 400, maxHeight: 400, imageQuality: 85);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() { _imageFile = file; _uploading = true; _imageUrl = ''; });
    try {
      final url = await CloudinaryService.uploadImage(file);
      if (mounted) setState(() { _imageUrl = url; _uploading = false; });
    } catch (e) {
      if (mounted) setState(() { _uploading = false; _imageFile = null; });
      _snack('Upload failed: $e', isError: true);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Franchise name is required', isError: true); return;
    }
    if (_uploading) {
      _snack('Please wait for image upload', isError: true); return;
    }
    setState(() => _saving = true);
    try {
      // Cubit writes to Firebase AND inserts into the in-memory franchise list.
      await context.read<DraftCatalogCubit>().addFranchise(
        name:     _nameCtrl.text.trim(),
        imageUrl: _imageUrl,
        category: _category,
      );
      if (mounted) {
        _snack('✓ "${_nameCtrl.text.trim()}" added!');
        _nameCtrl.clear();
        setState(() {
          _imageFile = null;
          _imageUrl  = '';
          _category  = FranchiseCategory.anime;
        });
        widget.onAdded();
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? kAdminRed : kAdminGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionLabel(label: 'Franchise Logo', icon: Icons.image_outlined),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _uploading ? null : _pickImage,
          child: _ImagePicker(
              uploading: _uploading,
              imageFile: _imageFile,
              imageUrl:  _imageUrl),
        ).animate().fadeIn(delay: 40.ms),

        const SizedBox(height: 20),

        _SectionLabel(label: 'Franchise Name *', icon: Icons.movie_outlined),
        const SizedBox(height: 8),
        AdminField(
          controller: _nameCtrl,
          label: 'Franchise Name *',
          icon:  Icons.movie_outlined,
          hint:  'e.g. Naruto, Marvel, FC Barcelona',
        ).animate().fadeIn(delay: 60.ms),

        const SizedBox(height: 20),

        _SectionLabel(label: 'Category', icon: Icons.category_rounded),
        const SizedBox(height: 10),
        FranchiseCategoryPicker(
          selected:  _category,
          onChanged: (cat) => setState(() => _category = cat),
        ).animate().fadeIn(delay: 80.ms),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: (_saving || _uploading) ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add_rounded, size: 20),
            label: Text(
                _saving ? 'Saving…' : 'Add Franchise',
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
        ).animate().fadeIn(delay: 100.ms),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String   label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 15, color: kAdminViolet),
      const SizedBox(width: 7),
      Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold,
              color: kAdminTxtMut, letterSpacing: 0.8)),
    ]);
  }
}

class _ImagePicker extends StatelessWidget {
  final bool   uploading;
  final File?  imageFile;
  final String imageUrl;
  const _ImagePicker({
    required this.uploading,
    required this.imageFile,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, height: 120,
      decoration: BoxDecoration(
        color: kAdminRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: imageUrl.isNotEmpty
              ? kAdminGreen.withOpacity(0.5) : kAdminBdr,
          width: imageUrl.isNotEmpty ? 1.5 : 1,
        ),
      ),
      child: uploading
          ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(color: kAdminViolet, strokeWidth: 2),
              SizedBox(height: 8),
              Text('Uploading…',
                  style: TextStyle(color: kAdminTxtMut, fontSize: 12)),
            ])
          : imageFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.file(imageFile!,
                      width: double.infinity, height: 120, fit: BoxFit.cover))
              : imageUrl.isNotEmpty
                  ? Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.network(imageUrl,
                            width: double.infinity,
                            height: 120, fit: BoxFit.cover),
                      ),
                      Positioned(bottom: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(7)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: Colors.greenAccent, size: 12),
                              SizedBox(width: 4),
                              Text('Uploaded',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        )),
                    ])
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: kAdminAmber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(11)),
                          child: const Icon(
                              Icons.add_photo_alternate_rounded,
                              color: kAdminAmber, size: 20),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                            'Tap to select franchise logo (optional)',
                            style: TextStyle(
                                color: kAdminTxtMut, fontSize: 12)),
                      ]),
    );
  }
}
