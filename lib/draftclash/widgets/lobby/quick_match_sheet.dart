// lib/draftclash/widgets/lobby/quick_match_sheet.dart
//
// Bottom sheet for Quick Match — optional franchise spin wheel before searching.
// User can:
//   • Spin the wheel to pick a preferred franchise
//   • Skip / use any franchise
//   • Tap "Find Match" to fire DraftLobbyQuickMatchRequested
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';
import 'franchise_spin_wheel_sheet.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg     = Color(0xFF07070F);
const _surf   = Color(0xFF0D0C1E);
const _raised = Color(0xFF14122A);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF7B5CFA);
const _amber  = Color(0xFFF5A623);
const _txtPri = Color(0xFFEEECFF);
const _txtMut = Color(0xFF7A78A8);

// Matches FranchiseSpinWheelSheet segment colours for consistent colouring
const _kSegColors = [
  Color(0xFF00D4FF), Color(0xFFFFD700), Color(0xFFFF5A36),
  Color(0xFF00E676), Color(0xFFFF4081), Color(0xFF7C4DFF),
  Color(0xFF00BFA5), Color(0xFFFFAB40), Color(0xFF40C4FF),
  Color(0xFFE040FB), Color(0xFFB2FF59), Color(0xFFFF6E40),
];

class QuickMatchSheet extends StatefulWidget {
  const QuickMatchSheet({super.key});

  @override
  State<QuickMatchSheet> createState() => _QuickMatchSheetState();
}

class _QuickMatchSheetState extends State<QuickMatchSheet> {
  List<String>? _selectedFranchises;

  void _openSpinWheel(BuildContext context, List<String> franchises) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FranchiseSpinWheelSheet(
        franchises: franchises,
        currentFranchises: _selectedFranchises,
        onConfirmed: (list) => setState(() => _selectedFranchises = list),
      ),
    );
  }

  void _findMatch(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    context.read<DraftLobbyBloc>().add(
      DraftLobbyQuickMatchRequested(franchises: _selectedFranchises),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DraftLobbyBloc, DraftLobbyState>(
      builder: (context, state) {
        final loaded     = state is DraftLobbyLoaded ? state : null;
        final franchises = loaded?.franchises ?? [];

        return Container(
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle ──────────────────────────────────────────────
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: _bdr, borderRadius: BorderRadius.circular(2)),
                  ),
                ),

                // ── Header ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                  child: Row(children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B5CFA), Color(0xFF4A1FCC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: _violet.withOpacity(0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Quick Match',
                                style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: _txtPri)),
                            Text('Spin first or jump straight in',
                                style: TextStyle(fontSize: 12, color: _txtMut)),
                          ]),
                    ),
                    // Live count pill from lobby state
                    if ((loaded?.ongoingRooms.length ?? 0) > 0)
                      _LivePill(count: loaded!.ongoingRooms.length),
                  ]),
                ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: 20),

                // ── Divider ───────────────────────────────────────────────
                const Divider(height: 1, color: Color(0xFF1E1B38)),
                const SizedBox(height: 20),

                // ── Spin Wheel Button ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: _SpinRowButton(
                    selectedFranchises: _selectedFranchises,
                    franchises: franchises,
                    onTap: franchises.isNotEmpty
                        ? () => _openSpinWheel(context, franchises)
                        : null,
                  ),
                ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.08, end: 0),

                const SizedBox(height: 12),

                // ── Selected franchise / "Any" pill ─────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: (_selectedFranchises?.isNotEmpty == true)
                        ? _FranchisePill(
                            key: ValueKey(_selectedFranchises),
                            franchises: _selectedFranchises!,
                            allFranchises: franchises,
                            onClear: () =>
                                setState(() => _selectedFranchises = null),
                          )
                        : _AnySeriesPill(
                            key: const ValueKey('any'),
                          ),
                  ),
                ).animate().fadeIn(delay: 120.ms),

                const SizedBox(height: 24),

                // ── Find Match CTA ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                  child: _FindMatchButton(onTap: () => _findMatch(context)),
                ).animate().fadeIn(delay: 160.ms),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Spin row button ───────────────────────────────────────────────────────────

class _SpinRowButton extends StatelessWidget {
  final List<String>? selectedFranchises;
  final List<String>  franchises;
  final VoidCallback? onTap;

  const _SpinRowButton({
    required this.selectedFranchises,
    required this.franchises,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSel = selectedFranchises?.isNotEmpty == true;
    final count  = selectedFranchises?.length ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: hasSel
              ? null
              : LinearGradient(
                  colors: [
                    _violet.withOpacity(0.14),
                    _violet.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: hasSel ? _raised : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasSel ? _bdr : _violet.withOpacity(0.45),
            width: hasSel ? 1.0 : 1.5,
          ),
          boxShadow: hasSel
              ? null
              : [
                  BoxShadow(
                      color: _violet.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 4)),
                ],
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasSel
                    ? [_raised, _raised]
                    : [_violet.withOpacity(0.28), _violet.withOpacity(0.08)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasSel ? _bdr : _violet.withOpacity(0.45),
              ),
            ),
            child: Icon(
              Icons.rotate_right_rounded,
              size: 20,
              color: hasSel ? _txtMut : _violet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                hasSel
                    ? (count == 1 ? 'Re-spin the Wheel' : '$count series picked')
                    : 'Spin for a Series',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: hasSel ? _violet : _txtPri,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasSel
                    ? 'Tap to change your preferred series'
                    : 'Pick franchises, spin for a lucky pick',
                style: const TextStyle(fontSize: 11, color: _txtMut),
              ),
            ]),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: hasSel ? _txtMut : _violet,
            size: 20,
          ),
        ]),
      ),
    );
  }
}

// ─── Franchise pill ────────────────────────────────────────────────────────────

class _FranchisePill extends StatelessWidget {
  final List<String> franchises;     // selected
  final List<String> allFranchises;
  final VoidCallback onClear;

  const _FranchisePill({
    super.key,
    required this.franchises,
    required this.allFranchises,
    required this.onClear,
  });

  Color _colorFor(String f) {
    final idx = allFranchises.indexOf(f);
    if (idx >= 0) return _kSegColors[idx % _kSegColors.length];
    return _kSegColors[f.codeUnits.fold(0, (a, b) => a ^ b).abs() % _kSegColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final accent = franchises.length == 1 ? _colorFor(franchises.first) : _violet;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.1), blurRadius: 12)],
      ),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.18),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: accent.withOpacity(0.5)),
          ),
          child: Center(child: Text('${franchises.length}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: accent))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              franchises.length == 1
                  ? 'Preferred: ${franchises.first}'
                  : '${franchises.length} series preferred',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: accent),
              overflow: TextOverflow.ellipsis,
            ),
            Text('(or any open room)',
              style: const TextStyle(fontSize: 10.5, color: _txtMut)),
          ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onClear,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _raised,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _bdr),
            ),
            child: const Icon(Icons.close_rounded, size: 13, color: _txtMut),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.05, end: 0);
  }
}

// ─── Any series pill ───────────────────────────────────────────────────────────

class _AnySeriesPill extends StatelessWidget {
  const _AnySeriesPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _surf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: _txtMut.withOpacity(0.4), shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        const Text(
          'Any series  —  matching all open rooms',
          style: TextStyle(fontSize: 12.5, color: _txtMut),
        ),
      ]),
    );
  }
}

// ─── Find Match button ─────────────────────────────────────────────────────────

class _FindMatchButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FindMatchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.search_rounded, size: 22),
        label: const Text('Find Match',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _violet,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: _violet.withOpacity(0.45),
        ),
      ),
    );
  }
}

// ─── Live pill ─────────────────────────────────────────────────────────────────

class _LivePill extends StatelessWidget {
  final int count;
  const _LivePill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _amber.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: _amber, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text('$count OPEN',
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _amber,
                letterSpacing: 1,
                decoration: TextDecoration.none)),
      ]),
    );
  }
}
