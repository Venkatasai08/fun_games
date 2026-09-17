// lib/cardroomgame/widgets/table_area_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/card_model.dart';
import '../models/card_room_model.dart';
import 'playing_card_widget.dart';
import '../../config/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TableAreaWidget
//
// The shared card table in the center of the game screen.
// Acts as a DragTarget<PlayingCard> — players drop cards here.
// Displays stacked/fanned table cards that everyone can see.
// ─────────────────────────────────────────────────────────────────────────────

class TableAreaWidget extends StatelessWidget {
  final List<TableCard> tableCards;
  final bool isHost;
  final bool isActive; // false when game hasn't started yet
  final VoidCallback? onClearTable;
  final void Function(PlayingCard card)? onCardDropped;

  const TableAreaWidget({
    super.key,
    required this.tableCards,
    required this.isHost,
    required this.isActive,
    this.onClearTable,
    this.onCardDropped,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<PlayingCard>(
      onWillAcceptWithDetails: (_) => isActive,
      onAcceptWithDetails: (details) => onCardDropped?.call(details.data),
      builder: (ctx, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isHovering
                ? AppTheme.accent.withOpacity(0.12)
                : AppTheme.bgCard.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHovering
                  ? AppTheme.accent
                  : isActive
                      ? AppTheme.border
                      : AppTheme.border.withOpacity(0.4),
              width: isHovering ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              _buildHeader(isHovering),
              Expanded(child: _buildCardArea()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isHovering) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: isHovering ? AppTheme.accent : AppTheme.border,
                width: isHovering ? 1.5 : 1)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.table_restaurant_rounded,
            size: 16,
            color: isHovering ? AppTheme.accent : AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            isHovering ? 'Drop card here' : 'TABLE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: isHovering ? AppTheme.accent : AppTheme.textSecondary,
            ),
          ),
          if (tableCards.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${tableCards.length}',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary),
              ),
            ),
          ],
          const Spacer(),
          if (isHost && tableCards.isNotEmpty)
            GestureDetector(
              onTap: onClearTable,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.clear_all_rounded,
                        size: 12, color: Colors.redAccent),
                    SizedBox(width: 4),
                    Text('Clear',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardArea() {
    if (!isActive) {
      return const Center(
        child: Text(
          'Game not started yet',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      );
    }

    if (tableCards.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.drag_indicator_rounded,
                color: AppTheme.textSecondary.withOpacity(0.5), size: 28),
            const SizedBox(height: 6),
            Text(
              'Drag cards here to play',
              style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Show up to 6 most-recent cards as a slight fan / stack
    final visible = tableCards.reversed.take(10).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          for (int i = 0; i < visible.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayingCardWidget(
                    card: visible[i].card,
                    width: 50,
                    height: 76,
                  )
                      .animate(key: ValueKey(visible[i].card.id))
                      .scale(
                          begin: const Offset(0.7, 0.7),
                          end: const Offset(1, 1),
                          duration: 300.ms,
                          curve: Curves.elasticOut)
                      .fadeIn(duration: 200.ms),
                  const SizedBox(height: 4),
                  Text(
                    visible[i].placedByUsername,
                    style: const TextStyle(
                        fontSize: 9, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
