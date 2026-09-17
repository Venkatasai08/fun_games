// lib/tambola/widgets/number_board_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/app_theme.dart';

class NumberBoardWidget extends StatelessWidget {
  final int maxNumber;
  final List<int> calledNumbers;
  final int? lastCalled;

  const NumberBoardWidget({
    super.key,
    required this.maxNumber,
    required this.calledNumbers,
    this.lastCalled,
  });

  @override
  Widget build(BuildContext context) {
    final rows = (maxNumber / 10).ceil();
    final progress = calledNumbers.length / maxNumber;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Progress bar ──────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${calledNumbers.length} called',
                    style: const TextStyle(
                      color: AppTheme.primaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${maxNumber - calledNumbers.length} remaining',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.bgDark,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 1.0 ? AppTheme.accent : AppTheme.primary,
                  ),
                  minHeight: 7,
                ),
              ),
            ],
          ),
        ),

        // ── Number grid ──────────────────────────────────────────
        ...List.generate(rows, (row) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: List.generate(10, (col) {
              final num = row * 10 + col + 1;
              if (num > maxNumber) {
                return const Expanded(child: SizedBox());
              }
              final isCalled = calledNumbers.contains(num);
              final isLast = num == lastCalled;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _NumberCell(
                    number: num,
                    isCalled: isCalled,
                    isLast: isLast,
                  ),
                ),
              );
            }),
          ),
        )),

        // ── Legend ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppTheme.bgCardLight, border: AppTheme.border, label: 'Not called'),
              const SizedBox(width: 16),
              _LegendDot(color: AppTheme.primary, label: 'Called'),
              const SizedBox(width: 16),
              _LegendDot(color: AppTheme.secondary, label: 'Last called'),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberCell extends StatelessWidget {
  final int number;
  final bool isCalled;
  final bool isLast;

  const _NumberCell({
    required this.number,
    required this.isCalled,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: 400.ms,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: isLast
            ? const LinearGradient(
                colors: [AppTheme.secondary, Color(0xFFFF9068)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : isCalled
                ? const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
        color: (!isCalled && !isLast) ? AppTheme.bgCardLight : null,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isLast
              ? AppTheme.secondary.withOpacity(0.8)
              : isCalled
                  ? AppTheme.primary.withOpacity(0.6)
                  : AppTheme.border,
          width: isLast ? 2 : 1,
        ),
        boxShadow: isLast
            ? [BoxShadow(
                color: AppTheme.secondary.withOpacity(0.45),
                blurRadius: 10,
                spreadRadius: 1,
              )]
            : isCalled
                ? [BoxShadow(
                    color: AppTheme.primary.withOpacity(0.25),
                    blurRadius: 6,
                  )]
                : null,
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 11,
              fontWeight: (isCalled || isLast) ? FontWeight.bold : FontWeight.w400,
              color: (isCalled || isLast)
                  ? Colors.white
                  : AppTheme.textSecondary.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final Color? border;
  final String label;

  const _LegendDot({required this.color, this.border, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: border != null ? Border.all(color: border!, width: 1) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
