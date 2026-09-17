// lib/draftclash/screens/admin_slots_screen.dart
//
// Admin screen for managing DraftClash board slot roles.
// Uses DraftCatalogCubit (already in the widget tree) to read/write slots.
// Firebase writes are done via the cubit — no direct service calls here.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/draft_catalog_cubit.dart';
import '../models/slot_role.dart';
import '../utils/admin_theme.dart';

// ── Icons for well-known role names ──────────────────────────────────────────
IconData _iconFor(String name) {
  final key = SlotRole.iconKeyFor(name);
  return switch (key) {
    'captain'      => Icons.star_rounded,
    'vice_captain' => Icons.military_tech_rounded,
    'tank'         => Icons.shield_rounded,
    'duelist'      => Icons.flash_on_rounded,
    'support'      => Icons.favorite_rounded,
    'traitor'      => Icons.visibility_off_rounded,
    _              => Icons.radio_button_checked_rounded,
  };
}

// ── Key generator: snake_case from display name ───────────────────────────────
String _toKey(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

// ─────────────────────────────────────────────────────────────────────────────
class AdminSlotsScreen extends StatefulWidget {
  const AdminSlotsScreen({super.key});
  @override
  State<AdminSlotsScreen> createState() => _AdminSlotsScreenState();
}

class _AdminSlotsScreenState extends State<AdminSlotsScreen> {
  final _nameCtrl  = TextEditingController();
  SlotEffect _effect = SlotEffect.increment;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Add slot ──────────────────────────────────────────────────────────────
  Future<void> _addSlot() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final cubit = context.read<DraftCatalogCubit>();
    final slots = cubit.state.effectiveSlots;
    final newSlot = SlotRole(
      id:     '', // assigned by Firestore
      name:   name,
      key:    _toKey(name),
      effect: _effect,
      order:  slots.isEmpty ? 0 : (slots.last.order + 1),
    );
    final saved = await cubit.addSlot(newSlot);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved == null) {
      _snack('"$name" already exists.', isError: true);
    } else {
      _nameCtrl.clear();
      setState(() => _effect = SlotEffect.increment);
      _snack('"$name" added.');
    }
  }

  // ── Delete slot ───────────────────────────────────────────────────────────
  Future<void> _deleteSlot(SlotRole slot) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kAdminRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "${slot.name}"?',
            style: const TextStyle(color: kAdminTxtPri, fontSize: 16)),
        content: const Text(
          'This will remove the slot from future games.\n'
          'Existing game boards will not be affected.',
          style: TextStyle(color: kAdminTxtMut, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: kAdminTxtMut)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: kAdminRed)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<DraftCatalogCubit>().deleteSlot(slot.id);
    if (mounted) _snack('"${slot.name}" deleted.');
  }

  // ── Edit slot (bottom sheet) ──────────────────────────────────────────────
  void _editSlot(SlotRole slot) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BlocProvider.value(
        value: context.read<DraftCatalogCubit>(),
        child: _EditSlotSheet(slot: slot),
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: kAdminTxtPri)),
      backgroundColor: isError ? const Color(0xFF2A0A1E) : const Color(0xFF0A1E12),
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
            colors: [Color(0xFF0A0914), Color(0xFF0D0C1E), Color(0xFF07070F)],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            // ── App bar ──────────────────────────────────────────────────────
            _buildAppBar(),
            Expanded(
              child: BlocBuilder<DraftCatalogCubit, DraftCatalogState>(
                builder: (context, catalog) {
                  final slots = catalog.effectiveSlots;
                  return CustomScrollView(
                    slivers: [
                      // ── Add new slot form ─────────────────────────────────
                      SliverToBoxAdapter(child: _buildAddForm()),

                      // ── Section label ─────────────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                          child: Row(children: [
                            const Icon(Icons.list_rounded,
                                size: 14, color: kAdminTxtMut),
                            const SizedBox(width: 6),
                            Text(
                              'CURRENT SLOTS  (${slots.length})',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: kAdminTxtMut,
                                  letterSpacing: 1.1),
                            ),
                          ]),
                        ),
                      ),

                      // ── Slot list ─────────────────────────────────────────
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _SlotTile(
                            slot: slots[i],
                            onEdit:   () => _editSlot(slots[i]),
                            onDelete: () => _deleteSlot(slots[i]),
                          ),
                          childCount: slots.length,
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildAppBar() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kAdminBdr)),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kAdminRaised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kAdminBdr),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 14, color: kAdminTxtMut),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Manage Board Slots',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: kAdminTxtPri)),
          ),
        ]),
      );

  Widget _buildAddForm() => Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kAdminRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kAdminBdr),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add New Slot',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kAdminTxtPri)),
          const SizedBox(height: 12),

          // Name field
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: kAdminTxtPri, fontSize: 14),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Slot name (e.g. Captain)',
              hintStyle: TextStyle(color: kAdminTxtMut.withOpacity(0.6)),
              filled: true,
              fillColor: const Color(0xFF0D0C1E),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kAdminBdr)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kAdminBdr)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: kAdminViolet, width: 1.5)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),

          // Effect toggle
          Row(children: [
            const Text('Effect:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kAdminTxtMut)),
            const SizedBox(width: 12),
            _EffectToggle(
              value: _effect,
              onChanged: (v) => setState(() => _effect = v),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            _effect == SlotEffect.increment
                ? '+ Adds card level to your score'
                : '− Subtracts from your score, adds to opponent\'s',
            style: TextStyle(
                fontSize: 11,
                color: _effect == SlotEffect.increment
                    ? kAdminGreen.withOpacity(0.8)
                    : kAdminRed.withOpacity(0.8)),
          ),
          const SizedBox(height: 14),

          // Save button
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _saving ? null : _addSlot,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                decoration: BoxDecoration(
                  gradient: _saving
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF4A2FD0), kAdminViolet]),
                  color: _saving ? kAdminRaised : null,
                  borderRadius: BorderRadius.circular(12),
                  border: _saving ? Border.all(color: kAdminBdr) : null,
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: kAdminViolet))
                      : const Text('Add Slot',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
            ),
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Effect toggle widget
// ─────────────────────────────────────────────────────────────────────────────
class _EffectToggle extends StatelessWidget {
  final SlotEffect value;
  final ValueChanged<SlotEffect> onChanged;
  const _EffectToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _pill(
        label: '+ Increment',
        selected: value == SlotEffect.increment,
        color: kAdminGreen,
        onTap: () => onChanged(SlotEffect.increment),
      ),
      const SizedBox(width: 8),
      _pill(
        label: '− Decrement',
        selected: value == SlotEffect.decrement,
        color: kAdminRed,
        onTap: () => onChanged(SlotEffect.decrement),
      ),
    ]);
  }

  Widget _pill({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : kAdminRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? color.withOpacity(0.70) : kAdminBdr,
              width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? color : kAdminTxtMut)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slot list tile
// ─────────────────────────────────────────────────────────────────────────────
class _SlotTile extends StatelessWidget {
  final SlotRole slot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _SlotTile(
      {required this.slot, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDecrement = slot.isDecrement;
    final effectColor = isDecrement ? kAdminRed : kAdminGreen;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kAdminRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAdminBdr),
      ),
      child: Row(children: [
        // Order badge
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: kAdminBg,
            shape: BoxShape.circle,
            border: Border.all(color: kAdminBdr),
          ),
          child: Center(
            child: Text('${slot.order + 1}',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: kAdminTxtMut)),
          ),
        ),
        const SizedBox(width: 10),
        // Role icon
        Icon(_iconFor(slot.name), size: 18, color: kAdminViolet),
        const SizedBox(width: 10),
        // Name + key
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(slot.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kAdminTxtPri)),
                Text(slot.key,
                    style: const TextStyle(
                        fontSize: 10,
                        color: kAdminTxtMut,
                        fontFamily: 'monospace')),
              ]),
        ),
        // Effect badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: effectColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: effectColor.withOpacity(0.40)),
          ),
          child: Text(
            isDecrement ? '− DEC' : '+ INC',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: effectColor,
                letterSpacing: 0.5),
          ),
        ),
        const SizedBox(width: 6),
        // Edit
        IconButton(
          icon: const Icon(Icons.edit_rounded, size: 16, color: kAdminTxtMut),
          onPressed: onEdit,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        // Delete
        IconButton(
          icon: const Icon(Icons.delete_rounded, size: 16, color: kAdminRed),
          onPressed: onDelete,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit slot bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _EditSlotSheet extends StatefulWidget {
  final SlotRole slot;
  const _EditSlotSheet({required this.slot});
  @override
  State<_EditSlotSheet> createState() => _EditSlotSheetState();
}

class _EditSlotSheetState extends State<_EditSlotSheet> {
  late final TextEditingController _nameCtrl;
  late SlotEffect _effect;
  late int _order;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.slot.name);
    _effect   = widget.slot.effect;
    _order    = widget.slot.order;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final updated = widget.slot.copyWith(
      name:   name,
      key:    _toKey(name),
      effect: _effect,
      order:  _order,
    );
    await context.read<DraftCatalogCubit>().updateSlot(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kAdminRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kAdminViolet.withOpacity(0.35), width: 1.5),
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kAdminBdr,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Edit Slot',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kAdminTxtPri)),
              const SizedBox(height: 14),

              // Name
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: kAdminTxtPri, fontSize: 14),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Slot name',
                  hintStyle: TextStyle(color: kAdminTxtMut.withOpacity(0.6)),
                  filled: true,
                  fillColor: kAdminBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kAdminBdr)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kAdminBdr)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: kAdminViolet, width: 1.5)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Effect
              Row(children: [
                const Text('Effect:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kAdminTxtMut)),
                const SizedBox(width: 12),
                _EffectToggle(
                    value: _effect,
                    onChanged: (v) => setState(() => _effect = v)),
              ]),
              const SizedBox(height: 12),

              // Order
              Row(children: [
                const Text('Order:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kAdminTxtMut)),
                const SizedBox(width: 12),
                _OrderStepper(
                  value: _order,
                  onChanged: (v) => setState(() => _order = v),
                ),
              ]),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _saving ? null : _save,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: _saving
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF4A2FD0), kAdminViolet]),
                      color: _saving ? kAdminRaised : null,
                      borderRadius: BorderRadius.circular(12),
                      border: _saving ? Border.all(color: kAdminBdr) : null,
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: kAdminViolet))
                          : const Text('Save Changes',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order stepper widget
// ─────────────────────────────────────────────────────────────────────────────
class _OrderStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _OrderStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove_rounded, () {
            if (value > 0) onChanged(value - 1);
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('$value',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kAdminTxtPri)),
          ),
          _btn(Icons.add_rounded, () => onChanged(value + 1)),
        ],
      );

  Widget _btn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: kAdminRaised,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: kAdminBdr),
          ),
          child: Icon(icon, size: 14, color: kAdminTxtMut),
        ),
      );
}
