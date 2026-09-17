// lib/draftclash/utils/admin_theme.dart
//
// Shared design tokens and tier helpers for all DraftClash admin screens.
// Import this file instead of referencing admin_screen.dart for tokens.
//
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Neon Noir palette
// ─────────────────────────────────────────────────────────────────────────────

const kAdminBg     = Color(0xFF07070F);
const kAdminSurf   = Color(0xFF0D0C1E);
const kAdminRaised = Color(0xFF14122A);
const kAdminBdr    = Color(0xFF1E1B38);
const kAdminViolet = Color(0xFF6E44FF);
const kAdminAmber  = Color(0xFFF4A11D);
const kAdminRed    = Color(0xFFE8445A);
const kAdminGreen  = Color(0xFF3ADE80);
const kAdminTxtPri = Color(0xFFEAE8FF);
const kAdminTxtMut = Color(0xFF6A6898);

// ─────────────────────────────────────────────────────────────────────────────
// Tier colours
// ─────────────────────────────────────────────────────────────────────────────

const kTierLegendary = Color(0xFFFF3B5C); // crimson-red (top tier)
const kTierMythic    = Color(0xFFFFD700); // gold (second tier)
const kTierEpic      = Color(0xFF9C27B0); // purple
const kTierRare      = Color(0xFF2196F3); // blue
const kTierCommon    = Color(0xFF4CAF50); // green

Color tierColor(double level) {
  if (level >= 9.6) return kTierLegendary;
  if (level >= 8.5) return kTierMythic;
  if (level >= 6.5) return kTierEpic;
  if (level >= 3.5) return kTierRare;
  return kTierCommon;
}

String tierLabel(double level) {
  if (level >= 9.6) return 'LEGENDARY';
  if (level >= 8.5) return 'MYTHIC';
  if (level >= 6.5) return 'EPIC';
  if (level >= 3.5) return 'RARE';
  return 'COMMON';
}
