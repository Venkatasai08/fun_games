// lib/draftclash/widgets/draft_card_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/draft_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tier colour palette
// ─────────────────────────────────────────────────────────────────────────────

class _Tier {
  final Color glow;
  final Color mid;
  final Color dark;
  final String label;
  const _Tier({
    required this.glow,
    required this.mid,
    required this.dark,
    required this.label,
  });
}

const _legendary = _Tier(
  glow: Color(0xFFFF3B5C),
  mid: Color(0xFF7A001A),
  dark: Color(0xFF130007),
  label: 'LEGENDARY',
);
const _mythic = _Tier(
  glow: Color(0xFFFFAA00),
  mid: Color(0xFF7A4E00),
  dark: Color(0xFF110B00),
  label: 'MYTHIC',
);
const _epic = _Tier(
  glow: Color(0xFFBB6CFF),
  mid: Color(0xFF5C1FA0),
  dark: Color(0xFF0D0817),
  label: 'EPIC',
);
const _rare = _Tier(
  glow: Color(0xFF38C7FF),
  mid: Color(0xFF0B5F84),
  dark: Color(0xFF04101A),
  label: 'RARE',
);
const _common = _Tier(
  glow: Color(0xFF3ADE80),
  mid: Color(0xFF0C5531),
  dark: Color(0xFF030D08),
  label: 'COMMON',
);

_Tier _tierFor(double level) {
  if (level >= 9.6) return _legendary;
  if (level >= 8.5) return _mythic;
  if (level >= 6.5) return _epic;
  if (level >= 3.5) return _rare;
  return _common;
}

// ─────────────────────────────────────────────────────────────────────────────
// DraftCardWidget
// ─────────────────────────────────────────────────────────────────────────────

class DraftCardWidget extends StatelessWidget {
  final DraftCard card;
  final bool compact;
  final bool glowing;

  const DraftCardWidget({
    super.key,
    required this.card,
    this.compact = false,
    this.glowing = false,
  });

  @override
  Widget build(BuildContext context) =>
      compact ? _buildCompact() : _buildFull();

  // ── Full card ─────────────────────────────────────────────────────────────

  Widget _buildFull() {
    final t = _tierFor(card.level);
    final isLegendary = card.level >= 8.0; // legendary + mythic both shimmer

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.mid.withOpacity(0.4), t.dark, const Color(0xFF07070F)],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(
          color: glowing ? t.glow : t.glow.withOpacity(0.28),
          width: glowing ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: t.glow.withOpacity(glowing ? 0.5 : 0.12),
            blurRadius: glowing ? 32 : 12,
            spreadRadius: glowing ? 2 : 0,
          ),
          const BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            // Holographic shimmer for legendary
            if (isLegendary)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x08FFFFFF),
                          Colors.transparent,
                          Color(0x06FFFBE0),
                          Colors.transparent,
                          Color(0x05FFFFFF),
                        ],
                        stops: [0.0, 0.3, 0.5, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImage(t, 118),
                _buildMeta(t),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .scaleXY(begin: 0.86, duration: 360.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 180.ms);
  }

  Widget _buildImage(_Tier t, double h) {
    Widget img;
    if (card.imageUrl.isNotEmpty) {
      img = Image.network(
        card.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: h,
        errorBuilder: (_, __, ___) => _placeholder(t, h),
      );
    } else {
      img = _placeholder(t, h);
    }

    return Stack(
      children: [
        SizedBox(height: h, child: img),
        // Bottom fade into card body
        Positioned(
          bottom: 0, left: 0, right: 0,
          height: 52,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, t.dark],
              ),
            ),
          ),
        ),
        // Top-left: franchise pill
        Positioned(
          top: 8, left: 8,
          child: _pill(
            card.franchiseName.isEmpty ? 'UNKNOWN' : card.franchiseName.toUpperCase(),
            t.glow,
          ),
        ),
        // Top-right: tier badge
        Positioned(
          top: 8, right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: t.glow.withOpacity(0.18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: t.glow.withOpacity(0.45)),
              boxShadow: [
                BoxShadow(color: t.glow.withOpacity(0.2), blurRadius: 8),
              ],
            ),
            child: Text(
              t.label,
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
                color: t.glow,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(_Tier t, double h) {
    return Container(
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.mid.withOpacity(0.5), t.dark],
        ),
      ),
      child: Center(
        child: Text(
          card.name.isNotEmpty ? card.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: h * 0.52,
            fontWeight: FontWeight.w900,
            color: t.glow.withOpacity(0.12),
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildMeta(_Tier t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          Text(
            card.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFFEAE8FF),
              letterSpacing: 0.1,
              height: 1.1,
            ),
          ),
          if (card.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              card.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                height: 1.45,
                color: Color(0xFF6A6898),
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Level bar
          Row(children: [
            Text(
              'PWR',
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
                color: t.glow.withOpacity(0.45),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: card.level / 10,
                  minHeight: 5,
                  backgroundColor: const Color(0x14FFFFFF),
                  valueColor: AlwaysStoppedAnimation<Color>(t.glow),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [t.mid.withOpacity(0.6), t.dark],
                ),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: t.glow.withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(color: t.glow.withOpacity(0.25), blurRadius: 8),
                ],
              ),
              child: Center(
                child: Text(
                  '${card.level}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: t.glow,
                    height: 1,
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xBB07070F),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
          color: color.withOpacity(0.85),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ── Compact (inside board slot) ───────────────────────────────────────────

  Widget _buildCompact() {
    final t = _tierFor(card.level);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.mid.withOpacity(0.35), t.dark],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.glow.withOpacity(0.4)),
      ),
      child: Row(children: [
        // Thumbnail avatar
        Container(
          width: 38,
          height: 38,
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [t.mid.withOpacity(0.6), t.dark],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: t.glow.withOpacity(0.25)),
          ),
          child: card.imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.network(
                    card.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _compactLetter(t),
                  ),
                )
              : _compactLetter(t),
        ),
        // Name + franchise
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                card.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEAE8FF),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                card.franchiseName.isEmpty
                    ? t.label
                    : card.franchiseName.toUpperCase(),
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w600,
                  color: t.glow.withOpacity(0.65),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        // Level badge
        Container(
          margin: const EdgeInsets.only(right: 6),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: t.glow.withOpacity(0.14),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: t.glow.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              '${card.level}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: t.glow,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _compactLetter(_Tier t) {
    return Center(
      child: Text(
        card.name.isNotEmpty ? card.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: t.glow.withOpacity(0.8),
        ),
      ),
    );
  }
}
