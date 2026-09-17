// lib/draftclash/widgets/lobby/lobby_create_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';
import '../../screens/admin_screen.dart';
import '../../../services/auth_service.dart';
import 'lobby_franchise_chip.dart';
import 'lobby_section.dart';

const _bg     = Color(0xFF07070F);
const _surf   = Color(0xFF0D0C1E);
const _raised = Color(0xFF14122A);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF6E44FF);
const _amber  = Color(0xFFF4A11D);
const _red    = Color(0xFFE8445A);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

class LobbyCreateTab extends StatefulWidget {
  const LobbyCreateTab({super.key});

  @override
  State<LobbyCreateTab> createState() => _LobbyCreateTabState();
}

class _LobbyCreateTabState extends State<LobbyCreateTab> {
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
    context.read<DraftLobbyBloc>().add(DraftLobbyCreateSubmitted(
      roomName:   _nameCtrl.text.trim(),
      franchises: loaded.selectedFranchises,
      password:   loaded.hasPassword ? _passCtrl.text : null,
    ));
  }

  InputDecoration _inputDeco(String label, IconData icon,
      {String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label, labelStyle: const TextStyle(color: _txtMut),
      hintText: hint,
      hintStyle: TextStyle(color: _txtMut.withOpacity(0.3)),
      prefixIcon: Icon(icon, color: _txtMut, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true, fillColor: _raised,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _bdr)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _violet, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _red.withOpacity(0.6))),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _red, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DraftLobbyBloc, DraftLobbyState>(
      builder: (context, state) {
        if (state is DraftLobbyCreateLoading) {
          return const Scaffold(
            backgroundColor: _bg,
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: _amber),
                SizedBox(height: 16),
                Text('Creating room…', style: TextStyle(color: _txtMut)),
              ]),
            ),
          );
        }

        final loaded     = state is DraftLobbyLoaded ? state : null;
        final franchises = loaded?.franchises ?? [];
        final isLoading  = state is DraftLobbyCreateLoading;

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Create Room',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _txtPri)),
                  const SizedBox(height: 4),
                  const Text('Set up your Draft Clash game',
                      style: TextStyle(color: _txtMut, fontSize: 13)),
                  const SizedBox(height: 24),

                  LobbySection(
                    title: 'Room Details', icon: Icons.meeting_room_outlined,
                    children: [
                      TextFormField(
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
                    ],
                  ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.06),

                  const SizedBox(height: 16),

                  LobbySection(
                    title: 'Card Series', icon: Icons.collections_bookmark_rounded,
                    children: [
                      const Text(
                        'Filter the draft pool to one series, or use all cards.',
                        style: TextStyle(fontSize: 12, color: _txtMut, height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      if (franchises.isEmpty)
                        const Text('Loading franchises…',
                            style: TextStyle(color: _txtMut, fontSize: 12))
                      else
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            LobbyFranchiseChip(
                              label: 'All Series',
                              isSelected: loaded?.selectedFranchises == null ||
                                  loaded!.selectedFranchises!.isEmpty,
                              onTap: () => context
                                  .read<DraftLobbyBloc>()
                                  .add(const DraftLobbyFranchiseSelected(null)),
                            ),
                            ...franchises.map((f) => LobbyFranchiseChip(
                              label: f,
                              isSelected:
                                  loaded?.selectedFranchises?.contains(f) == true,
                              onTap: () {
                                final current = List<String>.from(
                                    loaded?.selectedFranchises ?? []);
                                if (current.contains(f)) {
                                  current.remove(f);
                                } else {
                                  current.add(f);
                                }
                                context.read<DraftLobbyBloc>().add(
                                    DraftLobbyFranchiseSelected(
                                        current.isEmpty ? null : current));
                              },
                            )),
                          ],
                        ),
                      if (loaded?.selectedFranchises?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _violet.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _violet.withOpacity(0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.filter_alt_rounded, size: 15, color: _violet),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                loaded!.selectedFranchises!.length == 1
                                    ? 'Draft pool: ${loaded.selectedFranchises!.first} cards only'
                                    : 'Draft pool: ${loaded.selectedFranchises!.length} series selected',
                                style: const TextStyle(fontSize: 12, color: _violet),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 12),
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
                  ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.06),

                  const SizedBox(height: 16),

                  LobbySection(
                    title: 'Access', icon: Icons.security_outlined,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Password protect',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _txtPri)),
                            const SizedBox(height: 2),
                            Text(
                              loaded?.hasPassword == true
                                  ? 'Only players with the password can join'
                                  : 'Anyone can join with the code',
                              style: const TextStyle(fontSize: 11, color: _txtMut),
                            ),
                          ]),
                        ),
                        Switch(
                          value: loaded?.hasPassword ?? false, activeColor: _violet,
                          onChanged: (v) => context.read<DraftLobbyBloc>().add(DraftLobbyPasswordToggled(v)),
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
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: _txtMut, size: 20,
                              ),
                              onPressed: () => context
                                  .read<DraftLobbyBloc>()
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
                    ],
                  ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.06),

                  const SizedBox(height: 16),

                  LobbySection(
                    title: 'Sound', icon: Icons.volume_up_rounded,
                    children: [
                      Row(children: [
                        const Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Sound effects & announcements',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _txtPri)),
                            SizedBox(height: 2),
                            Text('Voice announcements during the draft',
                                style: TextStyle(fontSize: 11, color: _txtMut)),
                          ]),
                        ),
                        Switch(
                          value: loaded?.soundEnabled ?? true, activeColor: _amber,
                          onChanged: (v) => context.read<DraftLobbyBloc>().add(DraftLobbySoundToggled(v)),
                        ),
                      ]),
                    ],
                  ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.06),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => _submit(context, loaded ?? const DraftLobbyLoaded(rooms: [])),
                      icon: isLoading
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.rocket_launch_rounded, size: 20),
                      label: Text(
                        isLoading ? 'Creating…' : 'Create Room',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _amber,
                        foregroundColor: const Color(0xFF1A1000),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ).animate().fadeIn(delay: 280.ms),

                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
