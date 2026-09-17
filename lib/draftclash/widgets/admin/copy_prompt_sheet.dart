// lib/draftclash/widgets/admin/copy_prompt_sheet.dart
//
// showCopyPromptSheet — call this immediately after writing to the clipboard.
// Displays a bottom sheet confirming the copy and offering one-tap shortcuts
// to open ChatGPT or Gemini (app if installed, browser otherwise).
//
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/admin_theme.dart';

/// Shows the "Prompt copied" bottom sheet.
/// Call after [Clipboard.setData] succeeds.
///
/// [subtitleSuffix] — optional extra detail shown in the subtitle,
/// e.g. "(excludes 12 existing cards)".
Future<void> showCopyPromptSheet(
  BuildContext context, {
  String subtitleSuffix = '',
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: false,
    builder: (_) => _CopyPromptSheet(subtitleSuffix: subtitleSuffix),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _CopyPromptSheet extends StatelessWidget {
  final String subtitleSuffix;
  const _CopyPromptSheet({required this.subtitleSuffix});

  Future<void> _open(BuildContext ctx, String url) async {
    Navigator.pop(ctx); // close sheet first
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: const Text('Could not open app',
              style: TextStyle(color: Colors.white)),
          backgroundColor: kAdminRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: const Text('Could not open app',
              style: TextStyle(color: Colors.white)),
          backgroundColor: kAdminRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = subtitleSuffix.isNotEmpty
        ? 'Copied $subtitleSuffix — paste it below'
        : 'Paste it into ChatGPT or Gemini';

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      decoration: BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kAdminBdr),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Drag handle ────────────────────────────────────────────────
        Center(
          child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 18),
            decoration: BoxDecoration(
                color: kAdminBdr, borderRadius: BorderRadius.circular(2)),
          ),
        ),

        // ── Header ────────────────────────────────────────────────────
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: kAdminGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAdminGreen.withOpacity(0.35)),
            ),
            child: const Icon(Icons.check_rounded, color: kAdminGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Prompt Copied!',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kAdminTxtPri)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: kAdminTxtMut)),
          ]),
        ]),

        const SizedBox(height: 20),

        // ── App buttons ───────────────────────────────────────────────
        Row(children: [
          // ChatGPT
          Expanded(
            child: _AppButton(
              emoji: '🤖',
              label: 'ChatGPT',
              sublabel: 'Open & paste',
              gradientColors: const [Color(0xFF0D4B30), Color(0xFF10A37F)],
              borderColor: const Color(0xFF10A37F),
              onTap: () => _open(context, 'https://chat.openai.com'),
            ),
          ),
          const SizedBox(width: 12),
          // Gemini
          Expanded(
            child: _AppButton(
              emoji: '✨',
              label: 'Gemini',
              sublabel: 'Open & paste',
              gradientColors: const [Color(0xFF1A1060), Color(0xFF4B6EFF)],
              borderColor: const Color(0xFF4B6EFF),
              onTap: () => _open(context, 'https://gemini.google.com'),
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // ── Dismiss ───────────────────────────────────────────────────
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: double.infinity,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kAdminRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAdminBdr),
            ),
            child: const Text('Dismiss',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kAdminTxtMut)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AppButton
// ─────────────────────────────────────────────────────────────────────────────

class _AppButton extends StatelessWidget {
  final String emoji;
  final String label;
  final String sublabel;
  final List<Color> gradientColors;
  final Color borderColor;
  final VoidCallback onTap;

  const _AppButton({
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.gradientColors,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              gradientColors[0].withOpacity(0.35),
              gradientColors[1].withOpacity(0.20),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor.withOpacity(0.55), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: borderColor)),
            Text(sublabel,
                style: TextStyle(
                    fontSize: 10,
                    color: borderColor.withOpacity(0.65))),
          ],
        ),
      ),
    );
  }
}
