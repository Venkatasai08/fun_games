// lib/draftclash/widgets/lobby/lobby_create_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';
import '../../screens/admin_screen.dart';
import '../../../services/auth_service.dart';
import 'franchise_spin_wheel_sheet.dart';

const _bg     = Color(0xFF07070F);
const _surf   = Color(0xFF0D0C1E);
const _raised = Color(0xFF14122A);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF6E44FF);
const _amber  = Color(0xFFF4A11D);
const _red    = Color(0xFFE8445A);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

// Mirrors _kSegColors from the spin wheel for consistent colouring
const _kSegColors = [
  Color(0xFF00D4FF), Color(0xFFFFD700), Color(0xFFFF5A36),
  Color(0xFF00E676), Color(0xFFFF4081), Color(0xFF7C4DFF),
  Color(0xFF00BFA5), Color(0xFFFFAB40), Color(0xFF40C4FF),
  Color(0xFFE040FB), Color(0xFFB2FF59), Color(0xFFFF6E40),
];

class LobbyCreateSheet extends StatefulWidget {
  const LobbyCreateSheet({super.key});

  @override
  State<LobbyCreateSheet> createState() => _LobbyCreateSheetState();
}

class _LobbyCreateSheetState extends State<LobbyCreateSheet> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isAdmin   = false;

  @override
  void initState() {
    super.initState();
    AuthService.isAdmin().then((v) {
      if (mounted) setState(() => _isAdmin = v);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context, DraftLobbyLoaded loaded) {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context);
    context.read<DraftLobbyBloc>().add(DraftLobbyCreateSubmitted(
      roomName:   _nameCtrl.text.trim(),
      franchises: loaded.selectedFranchises,
      password:   loaded.hasPassword ? _passCtrl.text : null,
    ));
  }

  void _openSpinWheel(BuildContext context, DraftLobbyLoaded loaded) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FranchiseSpinWheelSheet(
        franchises:        loaded.franchises,
        currentFranchises: loaded.selectedFranchises,
        onConfirmed: (list) => context.read<DraftLobbyBloc>()
            .add(DraftLobbyFranchiseSelected(list)),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, {String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _txtMut),
      hintText: hint,
      hintStyle: TextStyle(color: _txtMut.withOpacity(0.3)),
      prefixIcon: Icon(icon, color: _txtMut, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true, fillColor: _raised,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _bdr),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _amber, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _red.withOpacity(0.6)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _red, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DraftLobbyBloc, DraftLobbyState>(
      builder: (context, state) {
        if (state is DraftLobbyCreateLoading) {
          return Container(
            height: 200,
            decoration: const BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: _amber),
                SizedBox(height: 16),
                Text('Creating room…', style: TextStyle(color: _txtMut, fontSize: 14)),
              ]),
            ),
          );
        }

        final loaded     = state is DraftLobbyLoaded ? state : null;
        final selected   = loaded?.selectedFranchises;

        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.zero,
                  children: [
                    // ── Handle ───────────────────────────────────────────
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: _bdr, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),

                    // ── Header ───────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Row(children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF4A11D), Color(0xFFE8820A)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: _amber.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                          Text('Play with Friend',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _txtPri)),
                          Text('Create a room & share the code',
                              style: TextStyle(fontSize: 12, color: _txtMut)),
                        ]),
                      ]),
                    ),

                    const SizedBox(height: 24),
                    const _Divider(),

                    // ── Room Name ────────────────────────────────────────
                    _Section(
                      title: 'Room Details',
                      icon: Icons.meeting_room_outlined,
                      child: TextFormField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: _txtPri),
                        decoration: _inputDeco('Room Name', Icons.label_outline,
                            hint: 'e.g. Naruto vs Marvel'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Room name required';
                          if (v.trim().length < 3) return 'Min 3 characters';
                          return null;
                        },
                      ),
                    ).animate().fadeIn(delay: 60.ms),

                    // ── Card Series ──────────────────────────────────────
                    _Section(
                      title: 'Card Series',
                      icon: Icons.collections_bookmark_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Spin the wheel to randomly pick one series, or play with all cards.',
                            style: TextStyle(fontSize: 12, color: _txtMut, height: 1.5),
                          ),
                          const SizedBox(height: 14),

                          // ── Spin Wheel button ──────────────────────────
                          _SpinWheelButton(
                            selectedFranchise: selected,
                            franchises: loaded?.franchises ?? [],
                            onTap: loaded != null && loaded.franchises.isNotEmpty
                                ? () => _openSpinWheel(context, loaded)
                                : null,
                          ),

                          // ── Selected franchise banner ──────────────────
                          if (selected != null && selected.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _SelectedFranchisesBanner(
                              franchises: selected,
                              allFranchises: loaded?.franchises ?? [],
                              onClear: () => context.read<DraftLobbyBloc>()
                                  .add(const DraftLobbyFranchiseSelected(null)),
                            ),
                          ],

                          const SizedBox(height: 10),

                          // ── Admin link ─────────────────────────────────
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DraftAdminScreen()),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.admin_panel_settings_rounded,
                                    size: 13, color: _isAdmin ? _violet : _txtMut),
                                const SizedBox(width: 5),
                                Text('Manage card catalogue',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _isAdmin ? _violet : _txtMut,
                                      fontWeight: _isAdmin ? FontWeight.w600 : FontWeight.normal,
                                    )),
                                const SizedBox(width: 3),
                                Icon(Icons.arrow_forward_ios_rounded,
                                    size: 10, color: _isAdmin ? _violet : _txtMut),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms),

                    // ── Access ───────────────────────────────────────────
                    _Section(
                      title: 'Access',
                      icon: Icons.security_outlined,
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Password protect',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _txtPri)),
                              const SizedBox(height: 2),
                              Text(
                                loaded?.hasPassword == true
                                    ? 'Only players with password can join'
                                    : 'Anyone with the code can join',
                                style: const TextStyle(fontSize: 11, color: _txtMut),
                              ),
                            ]),
                          ),
                          Switch(
                            value: loaded?.hasPassword ?? false,
                            activeColor: _amber,
                            onChanged: (v) => context.read<DraftLobbyBloc>()
                                .add(DraftLobbyPasswordToggled(v)),
                          ),
                        ]),
                        if (loaded?.hasPassword == true) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: loaded?.obscurePassword ?? true,
                            style: const TextStyle(color: _txtPri),
                            decoration: _inputDeco(
                              'Room Password', Icons.lock_outline,
                              suffix: IconButton(
                                icon: Icon(
                                  loaded?.obscurePassword == true
                                      ? Icons.visibility_off : Icons.visibility,
                                  color: _txtMut, size: 20,
                                ),
                                onPressed: () => context.read<DraftLobbyBloc>()
                                    .add(DraftLobbyPasswordVisibilityToggled()),
                              ),
                            ),
                            validator: (v) {
                              if (loaded?.hasPassword == true && (v == null || v.isEmpty))
                                return 'Password required';
                              return null;
                            },
                          ),
                        ],
                      ]),
                    ).animate().fadeIn(delay: 140.ms),

                    // ── Sound ────────────────────────────────────────────
                    _Section(
                      title: 'Sound',
                      icon: Icons.volume_up_rounded,
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                            Text('Sound effects & announcements',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _txtPri)),
                            SizedBox(height: 2),
                            Text('Voice announcements during the draft',
                                style: TextStyle(fontSize: 11, color: _txtMut)),
                          ]),
                        ),
                        Switch(
                          value: loaded?.soundEnabled ?? true,
                          activeColor: _violet,
                          onChanged: (v) => context.read<DraftLobbyBloc>()
                              .add(DraftLobbySoundToggled(v)),
                        ),
                      ]),
                    ).animate().fadeIn(delay: 180.ms),

                    // ── Create Button ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () => _submit(
                              context, loaded ?? const DraftLobbyLoaded(rooms: [])),
                          icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                          label: const Text('Create Room',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _amber,
                            foregroundColor: const Color(0xFF1A1000),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 220.ms),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Spin Wheel Button ────────────────────────────────────────────────────────

class _SpinWheelButton extends StatelessWidget {
  final List<String>? selectedFranchise; // now a list
  final List<String>  franchises;
  final VoidCallback? onTap;

  const _SpinWheelButton({
    required this.selectedFranchise,
    required this.franchises,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedFranchise != null && selectedFranchise!.isNotEmpty;
    final count = selectedFranchise?.length ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: hasSelection
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _violet.withOpacity(0.12),
                    const Color(0xFF2A1080).withOpacity(0.08),
                  ],
                ),
          color: hasSelection ? _raised : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasSelection ? _bdr : _violet.withOpacity(0.45),
            width: 1.5,
          ),
          boxShadow: hasSelection
              ? null
              : [BoxShadow(color: _violet.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          // Wheel mini-icon
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasSelection
                    ? [_raised, _raised]
                    : [_violet.withOpacity(0.25), _violet.withOpacity(0.08)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasSelection ? _bdr : _violet.withOpacity(0.4),
              ),
            ),
            child: Icon(
              Icons.rotate_right_rounded,
              size: 20,
              color: hasSelection ? _txtMut : _violet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                hasSelection
                    ? (count == 1 ? 'Change Series' : '$count series selected')
                    : 'Pick a Series',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: hasSelection ? _violet : _txtPri,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasSelection
                    ? 'Tap to change selection'
                    : 'Select one or more franchises for the draft',
                style: const TextStyle(fontSize: 11, color: _txtMut),
              ),
            ]),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: hasSelection ? _txtMut : _violet,
            size: 20,
          ),
        ]),
      ),
    );
  }
}

// ─── Selected franchises banner (multi-select) ────────────────────────────────

class _SelectedFranchisesBanner extends StatelessWidget {
  final List<String> franchises;    // selected ones
  final List<String> allFranchises;
  final VoidCallback onClear;

  const _SelectedFranchisesBanner({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.1), blurRadius: 12)],
      ),
      child: Row(children: [
        // Count badge
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.18),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: accent.withOpacity(0.5)),
          ),
          child: Center(
            child: Text('${franchises.length}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: accent)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('DRAFT POOL',
              style: TextStyle(fontSize: 9.5, color: _txtMut,
                  letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Wrap(
              spacing: 6, runSpacing: 3,
              children: [
                ...franchises.take(4).map((f) {
                  final c = _colorFor(f);
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(f, style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w600, color: c),
                      overflow: TextOverflow.ellipsis),
                  ]);
                }),
                if (franchises.length > 4)
                  Text('+${franchises.length - 4} more',
                    style: const TextStyle(fontSize: 11, color: _txtMut)),
              ],
            ),
          ]),
        ),
        GestureDetector(
          onTap: onClear,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _raised, borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _bdr)),
            child: const Icon(Icons.close_rounded, size: 13, color: _txtMut),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.05, end: 0);
  }
}

// ─── Internal helpers ─────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: Color(0xFF1E1B38));
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 15, color: const Color(0xFF6E44FF)),
            const SizedBox(width: 7),
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6A6898),
                    letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
