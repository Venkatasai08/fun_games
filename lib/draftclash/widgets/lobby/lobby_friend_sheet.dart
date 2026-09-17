// lib/draftclash/widgets/lobby/lobby_friend_sheet.dart
//
// Combined "Play with Friend" bottom sheet.
// Two tabs: [Create Room] and [Join by Code].
// Create tab uses the FranchiseSpinWheelSheet for series selection.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';
import '../../models/slot_role.dart';
import '../../screens/admin_screen.dart';
import '../../../services/auth_service.dart';
import 'franchise_spin_wheel_sheet.dart';
import 'lobby_room_card.dart';

const _bg     = Color(0xFF07070F);
const _surf   = Color(0xFF0D0C1E);
const _raised = Color(0xFF14122A);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF6E44FF);
const _amber  = Color(0xFFF4A11D);
const _teal   = Color(0xFF00C9A7);
const _red    = Color(0xFFE8445A);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

// Matches FranchiseSpinWheelSheet segment colours
const _kSegColors = [
  Color(0xFF00D4FF), Color(0xFFFFD700), Color(0xFFFF5A36),
  Color(0xFF00E676), Color(0xFFFF4081), Color(0xFF7C4DFF),
  Color(0xFF00BFA5), Color(0xFFFFAB40), Color(0xFF40C4FF),
  Color(0xFFE040FB), Color(0xFFB2FF59), Color(0xFFFF6E40),
];

class LobbyFriendSheet extends StatefulWidget {
  /// 0 = Create tab, 1 = Join tab
  final int initialTab;
  const LobbyFriendSheet({super.key, this.initialTab = 0});

  @override
  State<LobbyFriendSheet> createState() => _LobbyFriendSheetState();
}

class _LobbyFriendSheetState extends State<LobbyFriendSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Create form
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isAdmin   = false;
  List<SlotRole> _allSlots = [];
  Map<String, int> _slotCounts = {};
  int get _totalSlots => _slotCounts.values.fold(0, (a, b) => a + b);

  // Join form
  final _codeCtrl  = TextEditingController();
  final _codeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tabCtrl.addListener(_onTabChange);
    AuthService.isAdmin().then((v) { if (mounted) setState(() => _isAdmin = v); });
    if (widget.initialTab == 1) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _codeFocus.requestFocus());
    }
  }

  void _onTabChange() {
    if (_tabCtrl.index == 1) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _codeFocus.requestFocus();
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChange);
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _submitCreate(BuildContext context, DraftLobbyLoaded loaded) {
    if (!_formKey.currentState!.validate()) return;
    final selectedSlots = _selectedSlots();
    if (selectedSlots.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          selectedSlots.isEmpty
              ? 'Please add at least 6 board slots to play.'
              : 'Add at least 6 slots (${selectedSlots.length} total so far).',
          style: const TextStyle(color: _txtPri),
        ),
        backgroundColor: const Color(0xFF2A0A1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    Navigator.pop(context);
    context.read<DraftLobbyBloc>().add(DraftLobbyCreateSubmitted(
      roomName:   _nameCtrl.text.trim(),
      franchises: loaded.selectedFranchises,
      password:   loaded.hasPassword ? _passCtrl.text : null,
      slots:      selectedSlots,
    ));
  }

  List<SlotRole> _selectedSlots() {
    final selectedSlots = <SlotRole>[];
    for (final slot in _allSlots) {
      final count = _slotCounts[slot.id] ?? 0;
      if (count == 1) {
        selectedSlots.add(slot);
      } else if (count > 1) {
        for (int i = 1; i <= count; i++) {
          selectedSlots.add(slot.copyWith(
            id: '${slot.id}_$i',
            key: '${slot.key}_$i',
          ));
        }
      }
    }
    return selectedSlots;
  }

  void _decrementSlot(SlotRole slot) {
    final count = _slotCounts[slot.id] ?? 0;
    if (count <= 0) return;
    setState(() => _slotCounts[slot.id] = (count - 1).clamp(0, 9));
  }

  void _incrementSlot(SlotRole slot) {
    final count = _slotCounts[slot.id] ?? 0;
    if (count >= 9) return;
    setState(() => _slotCounts[slot.id] = (count + 1).clamp(0, 9));
  }

  void _syncSlots(List<SlotRole> slots) {
    if (slots.isEmpty) return;
    final sameSlots = _allSlots.length == slots.length &&
        _allSlots.every((slot) => slots.any((next) => next.id == slot.id));
    if (sameSlots && _slotCounts.isNotEmpty) return;
    _allSlots = slots;
    _slotCounts = {for (final slot in slots) slot.id: 1};
  }

  void _searchCode(BuildContext context) {
    context.read<DraftLobbyBloc>().add(DraftLobbySearchByCode(_codeCtrl.text));
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
      labelText: label, labelStyle: const TextStyle(color: _txtMut),
      hintText: hint, hintStyle: TextStyle(color: _txtMut.withOpacity(0.3)),
      prefixIcon: Icon(icon, color: _txtMut, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true, fillColor: _raised,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _bdr)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: _tabCtrl.index == 0 ? _amber : _teal, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _red.withOpacity(0.6))),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DraftLobbyBloc, DraftLobbyState>(
      builder: (context, state) {
        if (state is DraftLobbyCreateLoading) {
          return Container(
            height: 180,
            decoration: const BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: _amber),
                SizedBox(height: 14),
                Text('Creating room…', style: TextStyle(color: _txtMut)),
              ]),
            ),
          );
        }

        final loaded      = state is DraftLobbyLoaded ? state : null;
        final franchises  = loaded?.franchises ?? [];
        final selected    = loaded?.selectedFranchises;
        _syncSlots(loaded?.slots ?? SlotRole.defaults);
        final isSearching = state is DraftLobbySearchLoading;
        final result      = state is DraftLobbySearchResult ? state : null;
        final myUid       = FirebaseAuth.instance.currentUser?.uid;

        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          expand: false,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(children: [
                // ── Handle ──────────────────────────────────────────────
                const SizedBox(height: 12),
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: _bdr, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),

                // ── Header ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(children: [
                    const Icon(Icons.group_rounded, color: _amber, size: 22),
                    const SizedBox(width: 12),
                    const Text('Play with Friend',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                            color: _txtPri)),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Tab switcher ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: _raised,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _bdr),
                    ),
                    child: TabBar(
                      controller: _tabCtrl,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: _tabCtrl.index == 0
                              ? [const Color(0xFFB07010), _amber.withOpacity(0.6)]
                              : [const Color(0xFF007A62), _teal.withOpacity(0.6)],
                        ),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: _txtMut,
                      labelStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      tabs: const [
                        Tab(text: '🚀  Create Room'),
                        Tab(text: '🔑  Join by Code'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // ── Tab content ───────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [

                      // ════════════════════════════════════════════════════
                      // CREATE TAB
                      // ════════════════════════════════════════════════════
                      Form(
                        key: _formKey,
                        child: ListView(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                          children: [

                            // ── Room Name ──────────────────────────────
                            _Section(title: 'Room Details', icon: Icons.meeting_room_outlined,
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

                            // ── Card Series (Spin Wheel) ───────────────
                            _Section(title: 'Card Series', icon: Icons.collections_bookmark_rounded,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text(
                                  'Spin the wheel to randomly pick one series, or play with all cards.',
                                  style: TextStyle(fontSize: 12, color: _txtMut, height: 1.5),
                                ),
                                const SizedBox(height: 12),

                                // Spin button
                                _SpinWheelButton(
                                  selectedFranchises: selected,
                                  hasCards: franchises.isNotEmpty,
                                  onTap: loaded != null && franchises.isNotEmpty
                                      ? () => _openSpinWheel(context, loaded)
                                      : null,
                                ),

                                // Selected franchise banner
                                if (selected != null && selected.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  _SelectedFranchisesBanner(
                                    franchises: selected,
                                    allFranchises: franchises,
                                    onClear: () => context.read<DraftLobbyBloc>()
                                        .add(const DraftLobbyFranchiseSelected(null)),
                                  ),
                                ],

                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => const DraftAdminScreen())),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                    Icon(Icons.admin_panel_settings_rounded,
                                        size: 12, color: _isAdmin ? _violet : _txtMut),
                                    const SizedBox(width: 4),
                                    Text('Manage card catalogue',
                                        style: TextStyle(fontSize: 11,
                                            color: _isAdmin ? _violet : _txtMut,
                                            fontWeight: _isAdmin ? FontWeight.w600 : FontWeight.normal)),
                                    const SizedBox(width: 2),
                                    Icon(Icons.arrow_forward_ios_rounded,
                                        size: 9, color: _isAdmin ? _violet : _txtMut),
                                  ]),
                                ),
                              ]),
                            ).animate().fadeIn(delay: 100.ms),

                            // ── Password ───────────────────────────────
                            _Section(title: 'Board Slots', icon: Icons.grid_view_rounded,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(
                                      _totalSlots >= 6
                                          ? 'Long press a chip to add, tap a chip to reduce'
                                          : 'Choose at least 6 boards. Long press to add, tap to reduce',
                                      style: const TextStyle(
                                          fontSize: 12, color: _txtMut, height: 1.4),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _totalSlots >= 6
                                          ? _teal.withOpacity(0.14)
                                          : _amber.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _totalSlots >= 6
                                            ? _teal.withOpacity(0.45)
                                            : _amber.withOpacity(0.45),
                                      ),
                                    ),
                                    child: Text(
                                      '$_totalSlots total  -  min 6',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _totalSlots >= 6 ? _teal : _amber,
                                      ),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 12),
                                _allSlots.isEmpty
                                    ? Container(
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: _raised,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: _bdr),
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: _violet,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          for (final slot in _allSlots)
                                            _BoardSlotChip(
                                              slot: slot,
                                              count: _slotCounts[slot.id] ?? 0,
                                              onTap: () => _decrementSlot(slot),
                                              onLongPress: () => _incrementSlot(slot),
                                            ),
                                        ],
                                      ),
                              ]),
                            ).animate().fadeIn(delay: 120.ms),

                            _Section(title: 'Access', icon: Icons.security_outlined,
                              child: Column(children: [
                                Row(children: [
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      const Text('Password protect',
                                          style: TextStyle(fontSize: 13,
                                              fontWeight: FontWeight.w600, color: _txtPri)),
                                      const SizedBox(height: 2),
                                      Text(loaded?.hasPassword == true
                                          ? 'Only players with password can join'
                                          : 'Anyone with the code can join',
                                          style: const TextStyle(fontSize: 11, color: _txtMut)),
                                    ],
                                  )),
                                  Switch(
                                    value: loaded?.hasPassword ?? false,
                                    activeColor: _amber,
                                    onChanged: (v) => context.read<DraftLobbyBloc>()
                                        .add(DraftLobbyPasswordToggled(v)),
                                  ),
                                ]),
                                if (loaded?.hasPassword == true) ...[
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _passCtrl,
                                    obscureText: loaded?.obscurePassword ?? true,
                                    style: const TextStyle(color: _txtPri),
                                    decoration: _inputDeco('Room Password', Icons.lock_outline,
                                      suffix: IconButton(
                                        icon: Icon(
                                          loaded?.obscurePassword == true
                                              ? Icons.visibility_off : Icons.visibility,
                                          color: _txtMut, size: 20),
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

                            // ── Sound ──────────────────────────────────
                            _Section(title: 'Sound', icon: Icons.volume_up_rounded,
                              child: Row(children: [
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, children: const [
                                    Text('Sound effects & announcements',
                                        style: TextStyle(fontSize: 13,
                                            fontWeight: FontWeight.w600, color: _txtPri)),
                                    SizedBox(height: 2),
                                    Text('Voice announcements during the draft',
                                        style: TextStyle(fontSize: 11, color: _txtMut)),
                                  ],
                                )),
                                Switch(
                                  value: loaded?.soundEnabled ?? true,
                                  activeColor: _violet,
                                  onChanged: (v) => context.read<DraftLobbyBloc>()
                                      .add(DraftLobbySoundToggled(v)),
                                ),
                              ]),
                            ).animate().fadeIn(delay: 180.ms),

                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity, height: 54,
                              child: ElevatedButton.icon(
                                onPressed: () => _submitCreate(
                                    context, loaded ?? const DraftLobbyLoaded(rooms: [])),
                                icon: const Icon(Icons.rocket_launch_rounded, size: 19),
                                label: const Text('Create Room',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _amber,
                                  foregroundColor: const Color(0xFF1A1000),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                              ),
                            ).animate().fadeIn(delay: 220.ms),
                          ],
                        ),
                      ),

                      // ════════════════════════════════════════════════════
                      // JOIN TAB
                      // ════════════════════════════════════════════════════
                      ListView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                        children: [
                          const Text('Enter the 6-digit room code:',
                              style: TextStyle(fontSize: 13, color: _txtMut)),
                          const SizedBox(height: 14),

                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _codeCtrl,
                                focusNode: _codeFocus,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                onSubmitted: (_) => _searchCode(context),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _txtPri, fontSize: 26,
                                  fontWeight: FontWeight.w900, letterSpacing: 8,
                                ),
                                decoration: InputDecoration(
                                  hintText: '• • • • • •',
                                  hintStyle: TextStyle(
                                    color: _txtMut.withOpacity(0.25),
                                    fontSize: 22, letterSpacing: 6,
                                    fontWeight: FontWeight.normal),
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 18),
                                  filled: true, fillColor: _raised,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: _bdr)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: _teal, width: 1.5)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 62, height: 62,
                              child: ElevatedButton(
                                onPressed: isSearching ? null : () => _searchCode(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _teal,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: isSearching
                                    ? const SizedBox(width: 20, height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5, color: Colors.white))
                                    : const Icon(Icons.search_rounded, size: 26),
                              ),
                            ),
                          ]),

                          if (result != null) ...[
                            const SizedBox(height: 16),
                            result.error != null
                                ? Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: _red.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _red.withOpacity(0.3)),
                                    ),
                                    child: Row(children: [
                                      const Icon(Icons.error_outline_rounded,
                                          color: _red, size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(result.error!,
                                          style: const TextStyle(color: _red, fontSize: 13))),
                                    ]),
                                  ).animate().fadeIn()
                                : result.room != null
                                    ? LobbyRoomCard(
                                        room: result.room!,
                                        isMyRoom: myUid != null && result.room!.isHost(myUid),
                                        onJoin: () {
                                          Navigator.pop(context);
                                          context.read<DraftLobbyBloc>()
                                              .add(DraftLobbyJoinRequested(result.room!.id));
                                        },
                                      ).animate().fadeIn().slideY(begin: 0.08)
                                    : const SizedBox.shrink(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ─── Spin Wheel Button ────────────────────────────────────────────────────────

class _SpinWheelButton extends StatelessWidget {
  final List<String>? selectedFranchises;
  final bool          hasCards;
  final VoidCallback? onTap;

  const _SpinWheelButton({
    required this.selectedFranchises,
    required this.hasCards,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: hasSel
              ? null
              : LinearGradient(
                  colors: [_violet.withOpacity(0.12), _violet.withOpacity(0.04)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
          color: hasSel ? _raised : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasSel ? _bdr : _violet.withOpacity(0.45),
            width: hasSel ? 1 : 1.5,
          ),
          boxShadow: hasSel
              ? null
              : [BoxShadow(color: _violet.withOpacity(0.15), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasSel
                    ? [_raised, _raised]
                    : [_violet.withOpacity(0.28), _violet.withOpacity(0.08)],
              ),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: hasSel ? _bdr : _violet.withOpacity(0.4)),
            ),
            child: Icon(Icons.rotate_right_rounded, size: 18,
                color: hasSel ? _txtMut : _violet),
          ),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              hasSel
                  ? (count == 1 ? 'Change Series' : '$count series selected')
                  : 'Pick a Series',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: hasSel ? _violet : _txtPri),
            ),
            const SizedBox(height: 1),
            Text(
              hasSel
                  ? 'Tap to change selection'
                  : 'Select one or more franchises for the draft',
              style: const TextStyle(fontSize: 10.5, color: _txtMut),
            ),
          ])),
          Icon(Icons.chevron_right_rounded,
              color: hasSel ? _txtMut : _violet, size: 18),
        ]),
      ),
    );
  }
}

// ─── Selected Franchises Banner (multi-select) ────────────────────────────────

class _SelectedFranchisesBanner extends StatelessWidget {
  final List<String> franchises;    // selected
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withOpacity(0.5)),
          ),
          child: Center(
            child: Text('${franchises.length}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: accent)),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('DRAFT POOL',
              style: TextStyle(fontSize: 9, color: _txtMut,
                  letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              franchises.length == 1
                  ? franchises.first
                  : franchises.take(3).join(', ') +
                      (franchises.length > 3 ? ' +${franchises.length - 3} more' : ''),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ]),
        ),
        GestureDetector(
          onTap: onClear,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _raised, borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _bdr)),
            child: const Icon(Icons.close_rounded, size: 12, color: _txtMut),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.05, end: 0);
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _BoardSlotChip extends StatelessWidget {
  final SlotRole slot;
  final int count;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BoardSlotChip({
    required this.slot,
    required this.count,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    final accent = slot.isDecrement ? _red : _violet;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: count > 0 ? onTap : null,
      onLongPress: count < 9 ? onLongPress : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.fromLTRB(8, 6, 7, 6),
        decoration: BoxDecoration(
          color: active ? accent.withOpacity(0.10) : _raised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? accent.withOpacity(0.48) : _bdr,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [BoxShadow(color: accent.withOpacity(0.10), blurRadius: 12)]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color:
                  active ? accent.withOpacity(0.16) : const Color(0xFF0D0C1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active ? accent.withOpacity(0.55) : _bdr,
              ),
            ),
            child: Icon(_slotIcon(slot),
                size: 15, color: active ? accent : _txtMut),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: Text(
              slot.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: active ? _txtPri : _txtMut,
              ),
            ),
          ),
          const SizedBox(width: 9),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Container(
              key: ValueKey(count),
              width: 30,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    active ? accent.withOpacity(0.15) : const Color(0xFF0D0C1E),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: active ? accent.withOpacity(0.55) : _bdr),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: active ? accent : _txtMut,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

IconData _slotIcon(SlotRole slot) {
  switch (SlotRole.iconKeyFor(slot.name)) {
    case 'captain':
      return Icons.star_rounded;
    case 'vice_captain':
      return Icons.star_half_rounded;
    case 'tank':
      return Icons.shield_rounded;
    case 'duelist':
      return Icons.flash_on_rounded;
    case 'support':
      return Icons.favorite_rounded;
    case 'traitor':
      return Icons.dangerous_rounded;
    default:
      return slot.isDecrement
          ? Icons.trending_down_rounded
          : Icons.grid_view_rounded;
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: _violet),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: _txtMut, letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}
