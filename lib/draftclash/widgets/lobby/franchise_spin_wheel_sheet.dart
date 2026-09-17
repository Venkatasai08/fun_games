// lib/draftclash/widgets/lobby/franchise_spin_wheel_sheet.dart
//
// Franchise selection sheet — two modes in one:
//
//   🎯  Direct Mode — tap any ONE franchise → confirm instantly   (default)
//   🎰  Spin Mode   — pick 6–12 franchises → spin wheel → confirm
//
// Usage:
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//     builder: (_) => FranchiseSpinWheelSheet(
//       franchises: franchiseList,
//       currentFranchise: selectedFranchise,
//       onConfirmed: (f) { /* f == null means "All Series" */ },
//     ),
//   );
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _bg     = Color(0xFF07070F);
const _surf   = Color(0xFF0D0C1E);
const _raised = Color(0xFF14122A);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF6E44FF);
const _amber  = Color(0xFFF4A11D);
const _green  = Color(0xFF43E97B);
const _teal   = Color(0xFF00C9A7);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

const _kSegColors = [
  Color(0xFF00D4FF), Color(0xFFFFD700), Color(0xFFFF5A36),
  Color(0xFF00E676), Color(0xFFFF4081), Color(0xFF7C4DFF),
  Color(0xFF00BFA5), Color(0xFFFFAB40), Color(0xFF40C4FF),
  Color(0xFFE040FB), Color(0xFFB2FF59), Color(0xFFFF6E40),
];

Color _segColor(String franchise, List<String> all) {
  final idx = all.indexOf(franchise);
  if (idx >= 0) return _kSegColors[idx % _kSegColors.length];
  return _kSegColors[franchise.codeUnits.fold(0, (a, b) => a ^ b).abs() % _kSegColors.length];
}

// ─── Public widget ─────────────────────────────────────────────────────────────
class FranchiseSpinWheelSheet extends StatefulWidget {
  final List<String> franchises;
  /// Legacy single-franchise seed (for online lobby back-compat).
  final String? currentFranchise;
  /// Multi-franchise seed (for Pass & Play).
  final List<String>? currentFranchises;
  /// null = All Series; non-empty list = selected franchises.
  final ValueChanged<List<String>?> onConfirmed;
  /// Optional hook for callers that need one more step before this sheet closes.
  /// Return false to keep the picker open.
  final Future<bool> Function(List<String>? franchises)? onBeforeClose;

  const FranchiseSpinWheelSheet({
    super.key,
    required this.franchises,
    this.currentFranchise,
    this.currentFranchises,
    required this.onConfirmed,
    this.onBeforeClose,
  });

  @override
  State<FranchiseSpinWheelSheet> createState() => _FranchiseSpinWheelSheetState();
}

class _FranchiseSpinWheelSheetState extends State<FranchiseSpinWheelSheet>
    with TickerProviderStateMixin {

  // ── Mode: 0 = direct pick (default), 1 = spin wheel ─────────────────────
  int _mode = 0;

  // ── Spin mode state ──────────────────────────────────────────────────────
  final Set<String> _spinSelected = {};
  static const int _minPick = 6;
  static const int _maxPick = 12;
  bool _showingWheel = false;

  late final AnimationController _spinCtrl;
  late Animation<double> _spinAnim;
  double _wheelAngle = 0;
  bool   _isSpinning = false;
  String? _landedOn;

  // ── Direct pick state (multi-select) ───────────────────────────────────
  final Set<String> _directPickSelected = {};

  @override
  void initState() {
    super.initState();
    // Seed from currentFranchises (multi) or currentFranchise (single, legacy)
    final seeds = widget.currentFranchises?.isNotEmpty == true
        ? widget.currentFranchises!
        : (widget.currentFranchise != null ? [widget.currentFranchise!] : <String>[]);
    _directPickSelected.addAll(seeds);
    _spinSelected.addAll(seeds);
    _spinCtrl = AnimationController(vsync: this);
    _spinAnim = Tween<double>(begin: 0, end: 0).animate(_spinCtrl);
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  void _toggleSpinPick(String f) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_spinSelected.contains(f)) {
        if (_spinSelected.length > 1) _spinSelected.remove(f);
      } else {
        if (_spinSelected.length < _maxPick) _spinSelected.add(f);
      }
    });
  }

  void _goToWheel() {
    if (_spinSelected.length < _minPick) return;
    setState(() {
      _showingWheel = true;
      _landedOn     = null;
      _wheelAngle   = 0;
    });
  }

  void _spin() {
    if (_isSpinning) return;
    HapticFeedback.mediumImpact();
    final list   = _spinSelected.toList();
    final n      = list.length;
    final segRad = (2 * math.pi) / n;
    final rng    = math.Random();
    final target = rng.nextInt(n);

    final targetRmod = (2 * math.pi) -
        ((target + 0.5) * segRad) % (2 * math.pi);
    final currentMod = _wheelAngle % (2 * math.pi);
    double delta = (targetRmod - currentMod + 2 * math.pi) % (2 * math.pi);
    if (delta < 0.01) delta = 2 * math.pi;

    final extraSpins = (5 + rng.nextInt(4)) * 2 * math.pi;
    final jitter     = (rng.nextDouble() - 0.5) * segRad * 0.3;
    final endAngle   = _wheelAngle + extraSpins + delta + jitter;

    setState(() => _isSpinning = true);
    _spinCtrl.duration = const Duration(milliseconds: 5000);
    _spinAnim = Tween<double>(begin: _wheelAngle, end: endAngle).animate(
      CurvedAnimation(parent: _spinCtrl, curve: Curves.easeOutExpo));
    _spinCtrl
      ..reset()
      ..forward().then((_) {
        setState(() {
          _wheelAngle  = endAngle;
          _landedOn    = list[target];
          _isSpinning  = false;
        });
        HapticFeedback.heavyImpact();
      });
  }

  /// Called by the Spin Wheel step — wraps the single result in a list.
  Future<void> _confirmFromWheel(String? franchise) async {
    final selection = franchise == null ? null : [franchise];
    final shouldClose = await widget.onBeforeClose?.call(selection) ?? true;
    if (!shouldClose || !mounted) return;
    widget.onConfirmed(selection);
    Navigator.pop(context);
  }

  /// Called by the Direct Pick step.
  Future<void> _confirmDirect(Set<String> sel) async {
    final selection = sel.isEmpty ? null : sel.toList();
    final shouldClose = await widget.onBeforeClose?.call(selection) ?? true;
    if (!shouldClose || !mounted) return;
    widget.onConfirmed(selection);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      height: screenH * (_showingWheel ? 0.92 : 0.88),
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: _bdr, borderRadius: BorderRadius.circular(2)))),

        if (!_showingWheel) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _ModeToggle(
              selected: _mode,
              onChanged: (v) => setState(() {
                _mode = v;
                HapticFeedback.selectionClick();
              }),
            ),
          ),
          const SizedBox(height: 4),
        ],

        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 340),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
                    .animate(anim),
                child: child,
              ),
            ),
            child: _showingWheel
                ? _WheelStep(
                    key: const ValueKey('wheel'),
                    franchises: _spinSelected.toList(),
                    spinCtrl: _spinCtrl,
                    spinAnim: _spinAnim,
                    wheelAngle: _wheelAngle,
                    isSpinning: _isSpinning,
                    landedOn: _landedOn,
                    onSpin: _spin,
                    onBack: _isSpinning ? null : () => setState(() {
                      _showingWheel = false;
                      _landedOn     = null;
                    }),
                    onConfirm: _confirmFromWheel,
                  )
                : _mode == 0
                    ? _DirectPickStep(
                        key: const ValueKey('direct'),
                        franchises: widget.franchises,
                        selected: _directPickSelected,
                        onToggle: (f) => setState(() {
                          if (_directPickSelected.contains(f)) {
                            _directPickSelected.remove(f);
                          } else {
                            _directPickSelected.add(f);
                          }
                        }),
                        onClearAll: () => setState(() => _directPickSelected.clear()),
                        onConfirm: _confirmDirect,
                      )
                    : _SpinPickerStep(
                        key: const ValueKey('spin-picker'),
                        franchises: widget.franchises,
                        selected: _spinSelected,
                        onToggle: _toggleSpinPick,
                        onProceed: _goToWheel,
                      ),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODE TOGGLE
// ═══════════════════════════════════════════════════════════════════════════════

class _ModeToggle extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _ModeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        _ModeTab(icon: Icons.ads_click_rounded, label: 'Direct Pick',
            isSelected: selected == 0, activeColor: _teal, onTap: () => onChanged(0)),
        _ModeTab(icon: Icons.casino_rounded, label: 'Spin Wheel',
            isSelected: selected == 1, activeColor: _violet, onTap: () => onChanged(1)),
      ]),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;
  const _ModeTab({required this.icon, required this.label, required this.isSelected,
      required this.activeColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: isSelected ? LinearGradient(
              colors: [activeColor.withOpacity(0.28), activeColor.withOpacity(0.10)],
              begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: activeColor.withOpacity(0.5), width: 1) : null,
            boxShadow: isSelected ? [BoxShadow(color: activeColor.withOpacity(0.20), blurRadius: 10)] : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: isSelected ? activeColor : _txtMut),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : _txtMut)),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DIRECT PICK STEP  —  multi-select
// ═══════════════════════════════════════════════════════════════════════════════

class _DirectPickStep extends StatelessWidget {
  final List<String>         franchises;
  final Set<String>          selected;
  final ValueChanged<String> onToggle;
  final VoidCallback         onClearAll;
  final Future<void> Function(Set<String>) onConfirm;

  const _DirectPickStep({
    super.key,
    required this.franchises,
    required this.selected,
    required this.onToggle,
    required this.onClearAll,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final hasAny = selected.isNotEmpty;

    // Build a blended preview color from the selected franchises
    Color previewColor = _teal;
    if (selected.length == 1) {
      previewColor = _segColor(selected.first, franchises);
    } else if (selected.length > 1) {
      previewColor = _violet;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Header ────────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
        child: Row(children: [
          _HeaderIcon(
            icon: Icons.ads_click_rounded,
            gradientColors: const [Color(0xFF00C9A7), Color(0xFF0087A5)],
            glowColor: _teal,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Pick Series',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _txtPri)),
              Text(
                hasAny
                    ? '${selected.length} series selected'
                    : 'Tap franchises to include in the draft',
                style: TextStyle(
                  fontSize: 11,
                  color: hasAny ? previewColor.withOpacity(0.85) : _txtMut,
                  fontWeight: hasAny ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ]),
          ),
          // ── All / Clear toggle ───────────────────────────────────────────
          GestureDetector(
            onTap: onClearAll,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: !hasAny ? _teal.withOpacity(0.18) : _raised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: !hasAny ? _teal.withOpacity(0.55) : _bdr,
                  width: !hasAny ? 1.5 : 1,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.all_inclusive_rounded, size: 13,
                    color: !hasAny ? _teal : _txtMut),
                const SizedBox(width: 5),
                Text('All', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: !hasAny ? _teal : _txtMut)),
              ]),
            ),
          ),
        ]),
      ),

      const SizedBox(height: 12),
      const Divider(height: 1, color: _bdr),

      // ── Chip grid ─────────────────────────────────────────────────────────
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (int i = 0; i < franchises.length; i++)
                _FranchiseTile(
                  label: franchises[i],
                  color: _kSegColors[i % _kSegColors.length],
                  isSelected: selected.contains(franchises[i]),
                  isBlocked: false,
                  checkIcon: Icons.check_circle_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onToggle(franchises[i]);
                  },
                ).animate()
                  .fadeIn(delay: Duration(milliseconds: i * 25))
                  .slideY(begin: 0.10, end: 0),
            ],
          ),
        ),
      ),

      // ── Selected summary bar ──────────────────────────────────────────────
      AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: hasAny
            ? Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: previewColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: previewColor.withOpacity(0.35), width: 1.5),
                    boxShadow: [BoxShadow(color: previewColor.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: Row(children: [
                    // Count badge
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: previewColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: previewColor.withOpacity(0.5)),
                      ),
                      child: Center(
                        child: Text('${selected.length}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                              color: previewColor)),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('SELECTED', style: TextStyle(fontSize: 9.5,
                            color: _txtMut, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                        Text(
                          selected.length == 1
                              ? selected.first
                              : selected.take(3).join(', ') +
                                  (selected.length > 3 ? ' +${selected.length - 3} more' : ''),
                          style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w700, color: _txtPri),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ]),
                    ),
                    GestureDetector(
                      onTap: onClearAll,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _raised,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: _bdr),
                        ),
                        child: const Icon(Icons.close_rounded, size: 13, color: _txtMut),
                      ),
                    ),
                  ]),
                ).animate().fadeIn(duration: 220.ms).slideX(begin: 0.04, end: 0),
              )
            : const SizedBox.shrink(),
      ),

      // ── Confirm button ────────────────────────────────────────────────────
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
          child: _GradientButton(
            onTap: () {
              onConfirm(Set.from(selected));
            },
            colors: hasAny
                ? [previewColor, _darken(previewColor, 0.12)]
                : [_teal, const Color(0xFF0087A5)],
            glowColor: hasAny ? previewColor : _teal,
            icon: Icons.check_rounded,
            label: hasAny
                ? (selected.length == 1
                    ? 'Use ${selected.first}'
                    : 'Use ${selected.length} Series')
                : 'Use All Series',
          ),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPIN PICKER STEP
// ═══════════════════════════════════════════════════════════════════════════════

class _SpinPickerStep extends StatelessWidget {
  final List<String>         franchises;
  final Set<String>          selected;
  final ValueChanged<String> onToggle;
  final VoidCallback         onProceed;
  const _SpinPickerStep({super.key, required this.franchises, required this.selected,
      required this.onToggle, required this.onProceed});

  static const _min = 6;
  static const _max = 12;

  @override
  Widget build(BuildContext context) {
    final canProceed = selected.length >= _min;
    final progress   = selected.length / _max;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
        child: Row(children: [
          _HeaderIcon(icon: Icons.casino_rounded,
              gradientColors: const [Color(0xFF6E44FF), Color(0xFF9C70FF)], glowColor: _violet),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Build Your Wheel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _txtPri)),
            Text('Pick $_min–$_max franchises to fill the spin wheel',
                style: const TextStyle(fontSize: 11, color: _txtMut)),
          ])),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: progress, backgroundColor: _bdr,
                    valueColor: AlwaysStoppedAnimation(canProceed ? _green : _amber), minHeight: 5),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                  color: canProceed ? _green : _amber),
              child: Text('${selected.length}/$_max'),
            ),
          ]),
          const SizedBox(height: 5),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              key: ValueKey(canProceed),
              canProceed
                  ? selected.length < _max
                      ? '✓  Ready! Add up to ${_max - selected.length} more or spin now.'
                      : '✓  Wheel full — time to spin!'
                  : 'Select ${_min - selected.length} more to continue',
              style: TextStyle(fontSize: 11, color: canProceed ? _green : _txtMut,
                  fontWeight: canProceed ? FontWeight.w600 : FontWeight.normal),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      const Divider(height: 1, color: _bdr),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (int i = 0; i < franchises.length; i++)
                _FranchiseTile(
                  label: franchises[i],
                  color: _kSegColors[i % _kSegColors.length],
                  isSelected: selected.contains(franchises[i]),
                  isBlocked: !selected.contains(franchises[i]) && selected.length >= _max,
                  checkIcon: Icons.check_circle_rounded,
                  onTap: () => onToggle(franchises[i]),
                ).animate().fadeIn(delay: Duration(milliseconds: i * 30)).slideY(begin: 0.12, end: 0),
            ],
          ),
        ),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
          child: _GradientButton(
            onTap: canProceed ? onProceed : null,
            colors: canProceed
                ? [const Color(0xFF6E44FF), const Color(0xFF9C70FF)]
                : [_raised, _raised],
            glowColor: canProceed ? _violet : Colors.transparent,
            icon: Icons.rotate_right_rounded,
            label: canProceed
                ? 'Spin the Wheel  →'
                : 'Select ${_min - selected.length} more to continue',
          ),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WHEEL STEP
// ═══════════════════════════════════════════════════════════════════════════════

class _WheelStep extends StatelessWidget {
  final List<String>          franchises;
  final AnimationController   spinCtrl;
  final Animation<double>     spinAnim;
  final double                wheelAngle;
  final bool                  isSpinning;
  final String?               landedOn;
  final VoidCallback          onSpin;
  final VoidCallback?         onBack;
  final Future<void> Function(String?) onConfirm;
  const _WheelStep({super.key, required this.franchises, required this.spinCtrl,
      required this.spinAnim, required this.wheelAngle, required this.isSpinning,
      required this.landedOn, required this.onSpin, required this.onBack, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _BackButton(onTap: onBack),
          Expanded(child: Column(children: [
            const Text('SPIN THE WHEEL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                color: _txtPri, letterSpacing: 2)),
            Text(isSpinning ? 'Spinning…'
                : landedOn != null ? 'Landed on  ✦  $landedOn'
                : 'Tap SPIN to pick a franchise',
              style: TextStyle(fontSize: 11, color: landedOn != null ? _amber : _txtMut,
                  fontWeight: landedOn != null ? FontWeight.w600 : FontWeight.normal)),
          ])),
          const SizedBox(width: 40),
        ]),
      ),
      Expanded(
        child: Center(
          child: AnimatedBuilder(
            animation: spinCtrl,
            builder: (_, __) {
              final angle = spinCtrl.isAnimating ? spinAnim.value : wheelAngle;
              return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                Container(width: 310, height: 310,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: _violet.withOpacity(isSpinning ? 0.30 : 0.15),
                      blurRadius: 60, spreadRadius: 15)])),
                Transform.rotate(angle: angle,
                  child: CustomPaint(size: const Size(300, 300),
                      painter: _WheelPainter(franchises: franchises))),
                _CentreHub(isSpinning: isSpinning),
                Positioned(top: 0, child: _PointerArrow()),
              ]);
            },
          ),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic,
        child: landedOn != null
            ? Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _ResultCard(franchise: landedOn!, franchises: franchises,
                    onConfirm: () {
                      onConfirm(landedOn);
                    })
                    .animate().fadeIn(duration: 350.ms).slideY(begin: 0.25, end: 0))
            : const SizedBox.shrink(),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
          child: _SpinButton(isSpinning: isSpinning, hasResult: landedOn != null, onSpin: onSpin),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared Widgets
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Franchise Tile ───────────────────────────────────────────────────────────
// The check icon appears at the LEADING (left) position when selected,
// replacing the colour dot. The dot is only shown when NOT selected.

class _FranchiseTile extends StatelessWidget {
  final String   label;
  final Color    color;
  final bool     isSelected;
  final bool     isBlocked;
  final IconData checkIcon;
  final VoidCallback onTap;

  const _FranchiseTile({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.isBlocked,
    required this.checkIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = isBlocked ? color.withOpacity(0.22) : color;
    return GestureDetector(
      onTap: isBlocked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? c.withOpacity(0.14) : _surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? c : c.withOpacity(isBlocked ? 0.12 : 0.24),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: c.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // ── Leading indicator: check icon OR colour dot ────────────
          if (isSelected)
            Icon(checkIcon, size: 13, color: c)
          else
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: c.withOpacity(isBlocked ? 0.2 : 0.4),
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 8),
          // ── Label ─────────────────────────────────────────────────
          Text(label, style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : isBlocked ? const Color(0xFF201E3A) : _txtPri.withOpacity(0.78),
          )),
        ]),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback? onTap;
  final List<Color>   colors;
  final Color         glowColor;
  final IconData      icon;
  final String        label;
  const _GradientButton({required this.onTap, required this.colors, required this.glowColor,
      required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      height: 54,
      decoration: BoxDecoration(
        gradient: active ? LinearGradient(colors: colors,
            begin: Alignment.centerLeft, end: Alignment.centerRight) : null,
        color: active ? null : _raised,
        borderRadius: BorderRadius.circular(15),
        boxShadow: active
            ? [BoxShadow(color: glowColor.withOpacity(0.38), blurRadius: 18, offset: const Offset(0, 5))]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: active ? Colors.white : _txtMut),
            const SizedBox(width: 9),
            Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800,
                letterSpacing: 0.2, color: active ? Colors.white : _txtMut)),
          ]),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String franchise;
  final List<String> franchises;
  final VoidCallback onConfirm;
  const _ResultCard({required this.franchise, required this.franchises, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final c = _segColor(franchise, franchises);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: c.withOpacity(0.07), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: c.withOpacity(0.12), blurRadius: 18)]),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: c.withOpacity(0.18), borderRadius: BorderRadius.circular(11),
              border: Border.all(color: c.withOpacity(0.5)),
              boxShadow: [BoxShadow(color: c.withOpacity(0.3), blurRadius: 8)]),
          child: Center(child: Text(franchise[0].toUpperCase(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('LANDED ON', style: TextStyle(fontSize: 9.5, color: _txtMut,
              letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          Text(franchise, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _txtPri),
              overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onConfirm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: c.withOpacity(0.18), borderRadius: BorderRadius.circular(11),
                border: Border.all(color: c.withOpacity(0.5)),
                boxShadow: [BoxShadow(color: c.withOpacity(0.18), blurRadius: 8)]),
            child: Text('USE THIS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                color: c, letterSpacing: 0.5)),
          ),
        ),
      ]),
    );
  }
}

class _CentreHub extends StatelessWidget {
  final bool isSpinning;
  const _CentreHub({required this.isSpinning});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 62, height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          isSpinning ? const Color(0xFF3A2A80) : const Color(0xFF211D50),
          const Color(0xFF0A0918)]),
        border: Border.all(
            color: isSpinning ? _violet.withOpacity(0.7) : Colors.white.withOpacity(0.10), width: 2),
        boxShadow: [BoxShadow(
            color: isSpinning ? _violet.withOpacity(0.5) : Colors.black.withOpacity(0.5),
            blurRadius: isSpinning ? 24 : 16)]),
      child: Center(child: Icon(Icons.stars_rounded,
          color: isSpinning ? _violet : _violet.withOpacity(0.45), size: 25)),
    );
  }
}

class _PointerArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 13, height: 26,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFFFF6060), Color(0xFFCC1010)]),
          boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 8)])),
      CustomPaint(size: const Size(20, 12), painter: _TrianglePainter(color: const Color(0xFFBB0C0C))),
    ]);
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(Path()..moveTo(0,0)..lineTo(size.width,0)..lineTo(size.width/2,size.height)..close(),
        Paint()..color = color);
  }
  @override bool shouldRepaint(_TrianglePainter o) => o.color != color;
}

class _SpinButton extends StatelessWidget {
  final bool isSpinning;
  final bool hasResult;
  final VoidCallback onSpin;
  const _SpinButton({required this.isSpinning, required this.hasResult, required this.onSpin});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      height: 54,
      decoration: BoxDecoration(
        gradient: isSpinning ? null : const LinearGradient(
            colors: [Color(0xFFF4A11D), Color(0xFFFF7A00)],
            begin: Alignment.centerLeft, end: Alignment.centerRight),
        color: isSpinning ? _raised : null,
        borderRadius: BorderRadius.circular(15),
        boxShadow: isSpinning ? null : [
          BoxShadow(color: _amber.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 5))]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSpinning ? null : onSpin,
          borderRadius: BorderRadius.circular(15),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (isSpinning)
              const SizedBox(width: 19, height: 19,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: _txtMut))
            else
              const Icon(Icons.rotate_right_rounded, size: 21, color: Color(0xFF1A0D00)),
            const SizedBox(width: 9),
            Text(isSpinning ? 'Spinning…' : hasResult ? 'SPIN AGAIN' : 'SPIN!',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1,
                  color: isSpinning ? _txtMut : const Color(0xFF1A0D00))),
          ]),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _BackButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: onTap != null ? _raised : _raised.withOpacity(0.4),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _bdr)),
        child: Icon(Icons.arrow_back_ios_rounded, size: 15,
            color: onTap != null ? _txtPri : _txtMut)),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final List<Color> gradientColors;
  final Color glowColor;
  const _HeaderIcon({required this.icon, required this.gradientColors, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [BoxShadow(color: glowColor.withOpacity(0.38), blurRadius: 12, offset: const Offset(0, 3))]),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Wheel CustomPainter
// ═══════════════════════════════════════════════════════════════════════════════

class _WheelPainter extends CustomPainter {
  final List<String> franchises;
  const _WheelPainter({required this.franchises});

  @override
  void paint(Canvas canvas, Size size) {
    final n = franchises.length;
    if (n == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 2;
    final innerR = outerR * 0.24;
    final segRad = (2 * math.pi) / n;
    final textR  = innerR + (outerR - innerR) * 0.58;

    for (int i = 0; i < n; i++) {
      final startAngle = -math.pi / 2 + i * segRad;
      final baseColor  = _kSegColors[i % _kSegColors.length];
      final fillColor  = i.isEven ? baseColor : _darken(baseColor, 0.18);
      final path       = _segPath(center, outerR, innerR, startAngle, segRad);

      canvas.drawPath(path, Paint()..color = fillColor);
      canvas.drawPath(_segPath(center, outerR-1, outerR-12, startAngle+segRad*0.05, segRad*0.9),
          Paint()..color = Colors.white.withOpacity(0.06));
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke
          ..color = Colors.black.withOpacity(0.4)..strokeWidth = 1.8);
      canvas.drawArc(Rect.fromCircle(center: center, radius: outerR-1), startAngle, segRad, false,
          Paint()..style = PaintingStyle.stroke..color = Colors.white.withOpacity(0.16)..strokeWidth = 1.5);
      _drawLabel(canvas, center, textR, startAngle, segRad, franchises[i]);
    }

    canvas.drawCircle(center, outerR+6, Paint()..style = PaintingStyle.stroke
        ..color = Colors.black.withOpacity(0.5)..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6));
    canvas.drawCircle(center, outerR+2, Paint()..style = PaintingStyle.stroke
        ..shader = SweepGradient(colors: [
          Colors.white.withOpacity(0.55), Colors.white.withOpacity(0.08),
          Colors.white.withOpacity(0.45), Colors.white.withOpacity(0.06),
          Colors.white.withOpacity(0.55)]).createShader(Rect.fromCircle(center: center, radius: outerR+2))
        ..strokeWidth = 8);
    canvas.drawCircle(center, outerR, Paint()..style = PaintingStyle.stroke
        ..color = Colors.white.withOpacity(0.10)..strokeWidth = 1.5);
  }

  Path _segPath(Offset c, double oR, double iR, double start, double sweep) {
    return Path()
      ..moveTo(c.dx + iR*math.cos(start), c.dy + iR*math.sin(start))
      ..lineTo(c.dx + oR*math.cos(start), c.dy + oR*math.sin(start))
      ..arcTo(Rect.fromCircle(center: c, radius: oR), start, sweep, false)
      ..lineTo(c.dx + iR*math.cos(start+sweep), c.dy + iR*math.sin(start+sweep))
      ..arcTo(Rect.fromCircle(center: c, radius: iR), start+sweep, -sweep, false)
      ..close();
  }

  void _drawLabel(Canvas canvas, Offset center, double textR,
      double startAngle, double segRad, String text) {
    final mid   = startAngle + segRad / 2;
    final maxW  = (textR * segRad * 0.85).clamp(28.0, 110.0);
    final fSize = (segRad * textR * 0.34).clamp(9.0, 14.5);
    final tp = TextPainter(
      text: TextSpan(text: text.toUpperCase(), style: TextStyle(
        fontSize: fSize, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.4,
        shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 5, offset: const Offset(0, 1.5))])),
      textDirection: TextDirection.ltr, textAlign: TextAlign.center,
    )..layout(maxWidth: maxW);
    canvas.save();
    canvas.translate(center.dx + textR*math.cos(mid), center.dy + textR*math.sin(mid));
    canvas.rotate(mid + math.pi / 2);
    if (tp.width > maxW) canvas.scale(maxW / tp.width);
    tp.paint(canvas, Offset(-tp.width/2, -tp.height/2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelPainter o) => !_eq(o.franchises, franchises);
  bool _eq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) if (a[i] != b[i]) return false;
    return true;
  }
}

Color _darken(Color c, double amount) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - amount).clamp(0.0, 1.0)).toColor();
}
