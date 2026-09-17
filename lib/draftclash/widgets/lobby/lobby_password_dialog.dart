// lib/draftclash/widgets/lobby/lobby_password_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/lobby/draft_lobby_bloc.dart';

const _surf   = Color(0xFF0D0C1E);
const _raised = Color(0xFF14122A);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF6E44FF);
const _amber  = Color(0xFFF4A11D);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

class LobbyPasswordDialog extends StatefulWidget {
  final String roomId;
  final String roomName;
  const LobbyPasswordDialog({super.key, required this.roomId, required this.roomName});

  @override
  State<LobbyPasswordDialog> createState() => _LobbyPasswordDialogState();
}

class _LobbyPasswordDialogState extends State<LobbyPasswordDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context);
    context.read<DraftLobbyBloc>().add(DraftLobbyPasswordVerified(
      roomId: widget.roomId,
      password: _ctrl.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(children: [
        Icon(Icons.lock_rounded, color: _amber, size: 20),
        SizedBox(width: 8),
        Text('Enter Password', style: TextStyle(color: _txtPri, fontSize: 16)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('"${widget.roomName}" is password protected',
            style: const TextStyle(color: _txtMut, fontSize: 13)),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          obscureText: _obscure,
          autofocus: true,
          onSubmitted: (_) => _submit(),
          style: const TextStyle(color: _txtPri),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: const TextStyle(color: _txtMut),
            prefixIcon: const Icon(Icons.lock_outline, color: _txtMut),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                  color: _txtMut, size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            filled: true, fillColor: _raised,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _bdr),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _violet, width: 1.5),
            ),
          ),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: _txtMut)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _violet, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
