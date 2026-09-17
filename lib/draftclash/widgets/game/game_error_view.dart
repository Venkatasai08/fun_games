// lib/draftclash/widgets/game/game_error_view.dart
import 'package:flutter/material.dart';

const _bg     = Color(0xFF07070F);
const _bdr    = Color(0xFF1E1B38);
const _red    = Color(0xFFE8445A);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

class GameErrorView extends StatelessWidget {
  final String message;
  const GameErrorView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.1), shape: BoxShape.circle,
                  border: Border.all(color: _red.withOpacity(0.3)),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: _red, size: 34),
              ),
              const SizedBox(height: 18),
              Text(message,
                  style: const TextStyle(color: _txtMut, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 15),
                label: const Text('Go Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _txtPri,
                  side: const BorderSide(color: _bdr),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
