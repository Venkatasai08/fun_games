// lib/draftclash/screens/admin_ai_generate_screen.dart
//
// AI character generation powered by Groq (Llama 3.3 70b).
// Admin selects a franchise → AI returns characters + raw preview images
// → admin reviews → on Save: images uploaded to Cloudinary → saved to Firestore.
//
// Run with: --dart-define=GROQ_API_KEY=gsk_your_key_here
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/draft_franchise.dart';
import '../services/draft_service.dart';
import '../services/deepseek_service.dart';
import '../services/cloudinary_service.dart';
import '../utils/admin_theme.dart';
import '../widgets/admin/ai_character_card.dart';
import '../widgets/admin/ai_empty_prompt.dart';
import '../widgets/admin/ai_error_banner.dart';
import '../widgets/admin/ai_generating_indicator.dart';
import '../widgets/admin/ai_not_configured_banner.dart';
import '../widgets/admin/ai_results_header.dart';
import '../widgets/admin/ai_saving_progress_banner.dart';
import '../widgets/admin/card_edit_sheet.dart';
import '../cubit/draft_catalog_cubit.dart';
import '../utils/prompt_utils.dart';
import '../widgets/admin/copy_prompt_sheet.dart';


class AdminAiGenerateScreen extends StatefulWidget {
  final DraftFranchise? preselectedFranchise;
  const AdminAiGenerateScreen({super.key, this.preselectedFranchise});

  @override
  State<AdminAiGenerateScreen> createState() => _AdminAiGenerateScreenState();
}

class _AdminAiGenerateScreenState extends State<AdminAiGenerateScreen> {

  DraftFranchise?      _selectedFranchise;

  int  _generateCount = 10;
  bool _generating    = false;
  bool _saving        = false;

  int    _saveTotal = 0;
  int    _saveDone  = 0;
  String _savePhase = '';

  List<GeneratedCharacter> _characters = [];
  String? _error;

  final _customContextCtrl = TextEditingController();

  // ── Paste JSON tab ─────────────────────────────────────────────────────────
  bool   _pasteMode        = true;
  // Phase 1: AI is normalising the raw text
  bool   _normalisingAi    = false;
  // Phase 2: fetching images one by one
  bool   _fetchingImages   = false;
  int    _imagesDone       = 0;
  int    _imagesTotal      = 0;
  String _pasteError       = '';
  final  _pasteCtrl        = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedFranchise = widget.preselectedFranchise;
  }

  @override
  void dispose() {
    _customContextCtrl.dispose();
    _pasteCtrl.dispose();
    super.dispose();
  }

  // ── Load from pasted text — Step 1: AI normalise, Step 2: fetch images ──
  Future<void> _loadFromPastedJson() async {
    final raw = _pasteCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _pasteError = 'Paste something first — any format works.');
      return;
    }

    setState(() {
      _pasteError    = '';
      _normalisingAi = true;
      _fetchingImages = false;
      _imagesDone    = 0;
      _imagesTotal   = 0;
      _characters    = [];
    });

    List<GeneratedCharacter> chars;
    try {
      // ── Step 1: AI normalises any input into clean name/description/power_level
      chars = await DeepSeekService.normaliseToCharacters(raw);
    } catch (e) {
      if (mounted) setState(() {
        _pasteError    = e.toString().replaceFirst('Exception: ', '');
        _normalisingAi = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _normalisingAi  = false;
      _fetchingImages = true;
      _imagesDone     = 0;
      _imagesTotal    = chars.length;
      // don't set _characters yet — show only the progress UI until all images are done
    });

    // ── Step 2: fetch images one by one with live N/total counter
    final isAnime = _selectedFranchise?.category.name == 'anime';
    final franchiseName = _selectedFranchise?.name ?? '';
    for (int i = 0; i < chars.length; i++) {
      final url = isAnime
          ? await DeepSeekService.fetchJikanImage(chars[i].name)
          : await DeepSeekService.fetchWikipediaImage(chars[i].name, franchise: franchiseName);
      chars[i].rawImageUrl = url;
      if (mounted) setState(() => _imagesDone = i + 1);
    }

    // only now reveal the list
    if (mounted) setState(() { _fetchingImages = false; _characters = chars; });
  }

  void _openAddCardSheet() {
    final franchise = _selectedFranchise;
    if (franchise == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CardEditSheet(
        franchiseId:   franchise.id,
        franchiseName: franchise.name,
        onSaved: (newCard) async {
          await DraftService.addCard(newCard);
          if (mounted) {
            _snack('✓ "${newCard.name}" added to ${franchise.name}!');
          }
        },
      ),
    );
  }

  Future<void> _generate() async {
    if (_selectedFranchise == null) {
      _snack('Please select a franchise first', isError: true); return;
    }

    setState(() { _generating = true; _characters = []; _error = null; });

    try {
      final existingCards = await DraftService.getAllCards(franchise: _selectedFranchise!.name);

      if (_selectedFranchise!.category.needsCustomContext &&
          _customContextCtrl.text.trim().isEmpty) {
        setState(() => _generating = false);
        _snack('Please describe what this franchise is about', isError: true);
        return;
      }

      final chars = await DeepSeekService.generateCharacters(
        franchise:     _selectedFranchise!.name,
        count:         _generateCount,
        existingCards: existingCards,
        category:      _selectedFranchise!.category,
        customContext: _customContextCtrl.text.trim(),
      );
      if (mounted) setState(() { _characters = chars; _generating = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error     = e.toString().replaceFirst('Exception: ', '');
        _generating = false;
      });
    }
  }

  Future<void> _saveSelected() async {
    final toSave = _characters.where((c) => c.selected).toList();
    if (toSave.isEmpty) {
      _snack('Select at least one character to save', isError: true); return;
    }
    if (_selectedFranchise == null) {
      _snack('Select a franchise first', isError: true); return;
    }

    setState(() {
      _saving    = true;
      _saveTotal = toSave.length;
      _saveDone  = 0;
      _savePhase = 'uploading';
    });

    // ── Phase 1: upload images to Cloudinary one by one
    for (final char in toSave) {
      char.imageUrl = await CloudinaryService.uploadImageFromUrl(char.rawImageUrl);
      if (mounted) setState(() => _saveDone++);
    }

    // ── Phase 2: batch-save all cards to Firestore, then increment count once
    if (mounted) setState(() { _saveDone = 0; _savePhase = 'saving'; });

    final cards = toSave.map((char) => DeepSeekService.toCard(
      character:     char,
      franchiseId:   _selectedFranchise!.id,
      franchiseName: _selectedFranchise!.name,
    )).toList();

    int saved = 0;
    try {
      saved = await DraftService.addCards(cards);
      if (mounted) setState(() => _saveDone = saved);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _savePhase = ''; });
      _snack('Save failed: $e', isError: true);
      return;
    }

    if (mounted) setState(() { _saving = false; _savePhase = ''; });
    _snack('✓ $saved card${saved == 1 ? '' : 's'} saved to ${_selectedFranchise!.name}!');
    setState(() { for (final c in toSave) c.selected = false; });
  }

  void _toggleAll(bool select) =>
      setState(() { for (final c in _characters) c.selected = select; });

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
    return Scaffold(
      backgroundColor: kAdminBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF050510), kAdminBg, Color(0xFF070714)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),

              // ── Mode toggle: Generate | Paste JSON ────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _buildModeToggle(),
                ),
              ),

              // ── PASTE JSON mode ────────────────────────────────────────
              if (_pasteMode) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _buildPastePanel(),
                  ),
                ),

                if (_pasteError.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: AiErrorBanner(message: _pasteError),
                    ),
                  ),

                // Phase 1: AI normalising
                if (_normalisingAi)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _buildNormalisingBanner(),
                    ),
                  ),

                // Phase 2: fetching images with N/total counter
                if (_fetchingImages)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: AiSavingProgressBanner(
                        phase: 'uploading',
                        done:  _imagesDone,
                        total: _imagesTotal,
                        label: 'Fetching images…',
                      ),
                    ),
                  ),
              ],

              // ── GENERATE mode ─────────────────────────────────────────────
              if (!_pasteMode && !DeepSeekService.isConfigured)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: AiNotConfiguredBanner(),
                  ),
                ),

              if (!_pasteMode && DeepSeekService.isConfigured) ...[

                if (_selectedFranchise?.category.needsCustomContext == true)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: _buildCustomContextField(),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _buildAddCardButton(),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _buildGenerateControls(),
                  ),
                ),

                if (_error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: AiErrorBanner(message: _error!),
                    ),
                  ),

                if (_generating)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: AiGeneratingIndicator(
                          franchise: _selectedFranchise?.name ?? ''),
                    ),
                  ),

              ], // end Generate mode

              // ── Save progress (shared — shown in both modes while saving) ──────
              if (_saving)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: AiSavingProgressBanner(
                      phase: _savePhase,
                      done:  _saveDone,
                      total: _saveTotal,
                      label: _savePhase == 'uploading'
                          ? 'Uploading images to Cloudinary…'
                          : 'Saving to database…',
                    ),
                  ),
                ),

              // ── Shared results list (both modes) ──────────────────────
              if (_characters.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: AiResultsHeader(
                        characters: _characters,
                        franchise:  _selectedFranchise?.name ?? '',
                        saving:     _saving,
                        onSelectAll:   () => _toggleAll(true),
                        onDeselectAll: () => _toggleAll(false),
                        onSave:        _saveSelected,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => AiCharacterCard(
                          character: _characters[i],
                          index:     i,
                          onToggle:  () => setState(
                              () => _characters[i].selected = !_characters[i].selected),
                          onLevelChanged: (v) => setState(
                              () => _characters[i].level = v),
                        ).animate()
                            .fadeIn(delay: Duration(milliseconds: 40 * i))
                            .slideY(begin: 0.06),
                        childCount: _characters.length,
                      ),
                    ),
                  ),
                ],

              if (!_pasteMode && !_generating && _characters.isEmpty && _error == null)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 32, 16, 32),
                    child: AiEmptyPrompt(),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mode toggle widget ────────────────────────────────────────────────────
  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAdminBdr),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        Expanded(child: _toggleBtn('📋  Paste JSON', _pasteMode, () {
          if (!_pasteMode) setState(() { _pasteMode = true; _characters = []; _error = null; });
        })),
        const SizedBox(width: 4),
        Expanded(child: _toggleBtn('🤖  AI Generate', !_pasteMode, () {
          if (_pasteMode) setState(() { _pasteMode = false; _characters = []; _error = null; });
        })),
      ]),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0066CC).withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? const Color(0xFF0066CC).withOpacity(0.5) : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: active ? const Color(0xFF4DA6FF) : kAdminTxtMut,
            ),
          ),
        ),
      ),
    );
  }

  // ── Phase 1 banner: AI normalising ──────────────────────────────────────
  Widget _buildNormalisingBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0066CC).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0066CC).withOpacity(0.35)),
      ),
      child: const Row(children: [
        SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Color(0xFF4DA6FF))),
        SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AI is reading your input…',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: Color(0xFF4DA6FF))),
            SizedBox(height: 2),
            Text('Extracting characters, descriptions and power levels',
                style: TextStyle(fontSize: 11, color: kAdminTxtMut)),
          ]),
        ),
        Text('🤖', style: TextStyle(fontSize: 20)),
      ]),
    );
  }

  // ── Paste JSON panel ──────────────────────────────────────────────────────
  Widget _buildPastePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF0066CC).withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.data_object_rounded, size: 15, color: Color(0xFF4DA6FF)),
          SizedBox(width: 7),
          Text('Paste Character JSON',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                  color: kAdminTxtMut, letterSpacing: 0.6)),
        ]),
        const SizedBox(height: 4),
        const Text(
          'Paste anything — JSON, a list, plain text, any format. '
          'AI will extract the characters automatically, then images are fetched one by one.',
          style: TextStyle(fontSize: 11, color: kAdminTxtMut, height: 1.5),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pasteCtrl,
          maxLines: 7,
          style: const TextStyle(color: kAdminTxtPri, fontSize: 12,
              fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'Paste any format: JSON array, wrapped object, plain list, prose…',
            hintStyle: TextStyle(color: kAdminTxtMut.withOpacity(0.35), fontSize: 11),
            filled: true,
            fillColor: kAdminRaised,
            contentPadding: const EdgeInsets.all(12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kAdminBdr),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0066CC), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // ── Copy Prompt + Clear All ──────────────────────────────────────
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (_selectedFranchise == null) {
                  _snack('Select a franchise first', isError: true);
                  return;
                }
                final existingCards = List.of(
                  context
                      .read<DraftCatalogCubit>()
                      .state
                      .cardsForFranchises([_selectedFranchise!.name]),
                )..sort((a, b) => a.name.compareTo(b.name));
                final prompt = generateCharacters(
                  seriesName:    _selectedFranchise!.name,
                  count:         10,
                  existingCards: existingCards,
                  category:      _selectedFranchise!.category.label,
                );
                await Clipboard.setData(ClipboardData(text: prompt));
                if (context.mounted) {
                  await showCopyPromptSheet(
                    context,
                    subtitleSuffix: existingCards.isEmpty
                        ? ''
                        : '(excludes ${existingCards.length} existing cards)',
                  );
                }
              },
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: kAdminGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: kAdminGreen.withOpacity(0.30), width: 1),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.copy_rounded, size: 13, color: kAdminGreen),
                    SizedBox(width: 6),
                    Text('Copy Prompt',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kAdminGreen)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _pasteCtrl.clear();
                setState(() {
                  _pasteError    = '';
                  _characters    = [];
                  _normalisingAi = false;
                  _fetchingImages = false;
                  _imagesDone    = 0;
                  _imagesTotal   = 0;
                });
              },
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: kAdminRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: kAdminRed.withOpacity(0.30), width: 1),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.clear_all_rounded, size: 14, color: kAdminRed),
                    SizedBox(width: 6),
                    Text('Clear All',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kAdminRed)),
                  ],
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity, height: 46,
          child: ElevatedButton(
            onPressed: (_normalisingAi || _fetchingImages) ? null : _loadFromPastedJson,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: EdgeInsets.zero,
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: (_normalisingAi || _fetchingImages)
                    ? null
                    : const LinearGradient(colors: [Color(0xFF003A8C), Color(0xFF0066CC)]),
                color: (_normalisingAi || _fetchingImages) ? kAdminRaised : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                alignment: Alignment.center,
                child: (_normalisingAi || _fetchingImages)
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white)),
                        const SizedBox(width: 10),
                        Text(
                          _normalisingAi
                              ? 'AI reading input…'
                              : 'Fetching images $_imagesDone / $_imagesTotal…',
                          style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ])
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('🖼️', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text('Load & Fetch Images',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.bold, color: Colors.white)),
                      ]),
              ),
            ),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.04);
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: kAdminSurf,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: kAdminBdr),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: kAdminTxtMut, size: 18),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF001A3A), Color(0xFF0066CC)]),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0066CC).withOpacity(0.45),
                  blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: const Center(child: Text('🤖', style: TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AI Generate',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                  color: kAdminTxtPri, letterSpacing: 0.5)),
          Text(
            _selectedFranchise != null
                ? _selectedFranchise!.name
                : 'Groq · Llama 3.3 · Free',
            style: const TextStyle(fontSize: 11, color: kAdminTxtMut),
          ),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: DeepSeekService.isConfigured
                ? const Color(0xFF0066CC).withOpacity(0.12)
                : kAdminRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: DeepSeekService.isConfigured
                  ? const Color(0xFF0066CC).withOpacity(0.4)
                  : kAdminRed.withOpacity(0.4),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: DeepSeekService.isConfigured
                    ? const Color(0xFF4DA6FF) : kAdminRed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              DeepSeekService.isConfigured ? 'READY' : 'NOT SET',
              style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.bold,
                color: DeepSeekService.isConfigured
                    ? const Color(0xFF4DA6FF) : kAdminRed,
                letterSpacing: 1,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCustomContextField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kAdminAmber.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.edit_note_rounded, size: 15, color: kAdminAmber),
          SizedBox(width: 7),
          Text('Describe this franchise',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                  color: kAdminTxtMut, letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 4),
        const Text('Help the AI understand what kind of characters to generate.',
            style: TextStyle(fontSize: 11, color: kAdminTxtMut)),
        const SizedBox(height: 10),
        TextField(
          controller: _customContextCtrl,
          maxLines: 3,
          style: const TextStyle(color: kAdminTxtPri, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'e.g. "Ancient Greek mythology — gods, heroes and monsters"',
            hintStyle: TextStyle(color: kAdminTxtMut.withOpacity(0.4), fontSize: 12),
            filled: true,
            fillColor: kAdminRaised,
            contentPadding: const EdgeInsets.all(12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kAdminBdr),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kAdminAmber, width: 1.5),
            ),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.04);
  }

  Widget _buildAddCardButton() {
    final hasFranchise = _selectedFranchise != null;

    return GestureDetector(
      onTap: hasFranchise ? _openAddCardSheet : () =>
          _snack('Select a franchise first to add a card manually', isError: true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: hasFranchise
              ? kAdminAmber.withOpacity(0.08)
              : kAdminSurf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasFranchise
                ? kAdminAmber.withOpacity(0.45)
                : kAdminBdr,
            width: hasFranchise ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: hasFranchise
                  ? kAdminAmber.withOpacity(0.15)
                  : kAdminRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.add_card_rounded,
                size: 18,
                color: hasFranchise ? kAdminAmber : kAdminTxtMut),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Add Card Manually',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: hasFranchise ? kAdminAmber : kAdminTxtMut,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasFranchise
                    ? 'Add a single card to ${_selectedFranchise!.name}'
                    : 'Select a franchise above first',
                style: TextStyle(
                  fontSize: 10.5,
                  color: hasFranchise
                      ? kAdminAmber.withOpacity(0.65)
                      : kAdminTxtMut.withOpacity(0.5),
                ),
              ),
            ]),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: hasFranchise ? kAdminAmber : kAdminTxtMut.withOpacity(0.3),
          ),
        ]),
      ),
    ).animate().fadeIn(delay: 70.ms).slideY(begin: 0.04);
  }

  Widget _buildGenerateControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kAdminBdr),
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.tag_rounded, size: 15, color: Color(0xFF4DA6FF)),
          const SizedBox(width: 7),
          const Text('Count',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                  color: kAdminTxtMut, letterSpacing: 0.5)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0066CC).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0066CC).withOpacity(0.5)),
            ),
            child: Text('$_generateCount characters',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: Color(0xFF4DA6FF))),
          ),
        ]),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor:   const Color(0xFF0066CC),
            inactiveTrackColor: kAdminRaised,
            thumbColor:         const Color(0xFF4DA6FF),
            overlayColor:       const Color(0xFF0066CC).withOpacity(0.15),
            trackHeight:        5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: _generateCount.toDouble(),
            min: 10, max: 50, divisions: 40,
            onChanged: (v) => setState(() => _generateCount = v.round()),
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('10', style: TextStyle(fontSize: 10, color: kAdminTxtMut)),
            Text('50', style: TextStyle(fontSize: 10, color: kAdminTxtMut)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: (_generating || _saving) ? null : _generate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: EdgeInsets.zero,
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: (_generating || _saving)
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF003A8C), Color(0xFF0066CC)]),
                color: (_generating || _saving) ? kAdminRaised : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Container(
                alignment: Alignment.center,
                child: _generating
                    ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white)),
                        SizedBox(width: 12),
                        Text('Asking Groq…',
                            style: TextStyle(fontSize: 15,
                                fontWeight: FontWeight.bold, color: Colors.white)),
                      ])
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('🤖', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Text(
                          _selectedFranchise != null
                              ? 'Generate ${_selectedFranchise!.name} Characters'
                              : 'Generate Characters',
                          style: const TextStyle(fontSize: 15,
                              fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ]),
              ),
            ),
          ),
        ),
      ]),
    ).animate().fadeIn(delay: 90.ms).slideY(begin: 0.04);
  }
}
