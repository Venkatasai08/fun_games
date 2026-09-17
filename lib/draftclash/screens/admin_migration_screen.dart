// lib/draftclash/screens/admin_migration_screen.dart
//
// One-time data migration utilities for DraftClash admin.
//
//  Button 1 — Migrate franchiseId → franchiseIds
//    Reads every card that still has the old scalar `franchiseId` field and
//    rewrites it as `franchiseIds: [franchiseId]`.  Already-migrated cards
//    are skipped automatically.  Safe to run multiple times.
//
//  Button 2 — Recalculate franchise card counts
//    Tallies cards per franchise from scratch and writes the correct
//    `cardCount` to every franchise document.
//
import 'package:flutter/material.dart';
import '../services/draft_service.dart';
import '../utils/admin_theme.dart';

class AdminMigrationScreen extends StatefulWidget {
  const AdminMigrationScreen({super.key});

  @override
  State<AdminMigrationScreen> createState() => _AdminMigrationScreenState();
}

class _AdminMigrationScreenState extends State<AdminMigrationScreen> {
  // ── Migration 1 state ─────────────────────────────────────────────────────
  bool   _migrating      = false;
  int    _migDone        = 0;
  int    _migTotal       = 0;
  String _migStatus      = '';
  Map<String, int>? _migResult;

  // ── Migration 2 state ─────────────────────────────────────────────────────
  bool   _recalculating  = false;
  int    _recalcDone     = 0;
  int    _recalcTotal    = 0;
  String _recalcStatus   = '';
  int?   _recalcResult;

  // ─────────────────────────────────────────────────────────────────────────
  // Migration 1: franchiseId → franchiseIds
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _runMigration() async {
    setState(() {
      _migrating = true;
      _migDone   = 0;
      _migTotal  = 0;
      _migStatus = 'Reading cards…';
      _migResult = null;
    });

    try {
      final result = await DraftService.migrateCardFranchiseIds(
        onProgress: (done, total) {
          if (mounted) setState(() {
            _migDone   = done;
            _migTotal  = total;
            _migStatus = 'Migrating cards…';
          });
        },
      );
      if (mounted) setState(() {
        _migResult = result;
        _migStatus = 'Done';
        _migrating = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _migStatus = 'Error: $e';
        _migrating = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Migration 2: recalculate franchise card counts
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _runRecalculate() async {
    setState(() {
      _recalculating = true;
      _recalcDone    = 0;
      _recalcTotal   = 0;
      _recalcStatus  = 'Counting cards…';
      _recalcResult  = null;
    });

    try {
      final updated = await DraftService.recalculateFranchiseCardCounts(
        onProgress: (done, total) {
          if (mounted) setState(() {
            _recalcDone   = done;
            _recalcTotal  = total;
            _recalcStatus = 'Updating franchises…';
          });
        },
      );
      if (mounted) setState(() {
        _recalcResult  = updated;
        _recalcStatus  = 'Done';
        _recalculating = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _recalcStatus  = 'Error: $e';
        _recalculating = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0914), kAdminBg],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                        color: kAdminSurf,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: kAdminBdr)),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: kAdminTxtMut, size: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: kAdminRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kAdminRed.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.build_rounded,
                      color: kAdminRed, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Data Migration',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: kAdminTxtPri)),
                      Text('One-time Firestore updates',
                          style: TextStyle(
                              fontSize: 11, color: kAdminTxtMut)),
                    ]),
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // ── Warning banner ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kAdminAmber.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: kAdminAmber.withOpacity(0.4)),
                    ),
                    child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: kAdminAmber, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'These operations write directly to Firestore. '
                              'They are safe to run multiple times — already-migrated '
                              'data is automatically skipped.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: kAdminAmber,
                                  height: 1.5),
                            ),
                          ),
                        ]),
                  ),
                  const SizedBox(height: 24),

                  // ── Card 1: Migrate franchiseId → franchiseIds ──────
                  _MigrationCard(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Migrate franchiseId → franchiseIds',
                    description:
                        'Converts every card that still has the old scalar '
                        'franchiseId string field to the new franchiseIds list.\n\n'
                        'Cards already on the new format are skipped. '
                        'Run this once after updating the app.',
                    running:   _migrating,
                    done:      _migDone,
                    total:     _migTotal,
                    status:    _migStatus,
                    result:    _migResult == null
                        ? null
                        : '✓ Migrated: ${_migResult!['migrated']}  '
                          '· Skipped: ${_migResult!['skipped']}  '
                          '· Failed: ${_migResult!['failed']}',
                    resultIsError:
                        (_migResult?['failed'] ?? 0) > 0,
                    onRun: (_migrating || _recalculating)
                        ? null
                        : _runMigration,
                  ),

                  const SizedBox(height: 16),

                  // ── Card 2: Recalculate franchise card counts ────────
                  _MigrationCard(
                    icon: Icons.calculate_rounded,
                    title: 'Recalculate franchise card counts',
                    description:
                        'Counts every card per franchise from scratch and '
                        'writes the correct cardCount to each franchise document.\n\n'
                        'Run this after the migration above, or any time '
                        'counts look wrong.',
                    running:   _recalculating,
                    done:      _recalcDone,
                    total:     _recalcTotal,
                    status:    _recalcStatus,
                    result:    _recalcResult == null
                        ? null
                        : '✓ Updated $_recalcResult franchise(s)',
                    resultIsError: false,
                    onRun: (_migrating || _recalculating)
                        ? null
                        : _runRecalculate,
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable migration card widget
// ─────────────────────────────────────────────────────────────────────────────

class _MigrationCard extends StatelessWidget {
  final IconData   icon;
  final String     title;
  final String     description;
  final bool       running;
  final int        done;
  final int        total;
  final String     status;
  final String?    result;
  final bool       resultIsError;
  final VoidCallback? onRun;

  const _MigrationCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.running,
    required this.done,
    required this.total,
    required this.status,
    required this.result,
    required this.resultIsError,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (total > 0) ? done / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kAdminSurf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kAdminBdr),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Title row
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: kAdminViolet.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAdminViolet.withOpacity(0.35)),
            ),
            child: Icon(icon, size: 17, color: kAdminViolet),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: kAdminTxtPri)),
          ),
        ]),
        const SizedBox(height: 12),

        // Description
        Text(description,
            style: const TextStyle(
                fontSize: 12, color: kAdminTxtMut, height: 1.55)),
        const SizedBox(height: 16),

        // Progress bar (only while running)
        if (running) ...[
          Row(children: [
            const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: kAdminViolet)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                total > 0 ? '$status  $done / $total' : status,
                style: const TextStyle(
                    fontSize: 11, color: kAdminViolet),
              ),
            ),
          ]),
          if (total > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: kAdminRaised,
                valueColor:
                    const AlwaysStoppedAnimation(kAdminViolet),
                minHeight: 5,
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],

        // Result
        if (result != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: (resultIsError ? kAdminRed : kAdminGreen)
                  .withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: (resultIsError ? kAdminRed : kAdminGreen)
                      .withOpacity(0.35)),
            ),
            child: Text(result!,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color:
                        resultIsError ? kAdminRed : kAdminGreen)),
          ),
          const SizedBox(height: 12),
        ],

        // Run button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: onRun,
            icon: running
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(icon, size: 16),
            label: Text(
                running ? 'Running…' : 'Run',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: onRun == null
                  ? kAdminRaised
                  : kAdminViolet,
              foregroundColor: Colors.white,
              disabledBackgroundColor: kAdminRaised,
              disabledForegroundColor: kAdminTxtMut,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    );
  }
}
