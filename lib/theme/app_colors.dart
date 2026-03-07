import 'package:flutter/material.dart';

class AppColors {
  // ── Backgrounds ────────────────────────────────────────────────────────────
  static const Color background = Color(
    0xFFF8F9FB,
  ); // Cooler, cleaner off-white
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(
    0xFFF1F4F9,
  ); // Subtle card variant / input fills

  // ── Primary Brand — deeper, more confident blue ────────────────────────────
  static const Color primary = Color(
    0xFF1D4ED8,
  ); // Richer indigo-blue (was flat 2563EB)
  static const Color primaryLight = Color(
    0xFF3B82F6,
  ); // Softer hover / icon tint
  static const Color primaryDark = Color(
    0xFF1E3A8A,
  ); // Deep press / header gradient end
  static const Color primaryMuted = Color(
    0xFFEFF4FF,
  ); // Chip backgrounds, row highlights

  // ── Vendor — earthy, trustworthy green (less neon) ─────────────────────────
  static const Color vendor = Colors.green; // Deeper forest green
  static const Color vendorLight = Color(
    0xFF22C55E,
  ); // Badge / active indicator
  static const Color vendorMuted = Color(
    0xFFF0FDF4,
  ); // Vendor chip / row highlight

  // ── Sand / Accent — pulled from your logo's yellow ─────────────────────────
  // This ties the UI back to the product (sand) and the splash truck
  static const Color sand = Color(
    0xFFF59E0B,
  ); // Warm amber — star, warning, badge
  static const Color sandLight = Color(
    0xFFFEF3C7,
  ); // Sand-tinted chip background
  static const Color sandDark = Color(0xFFB45309); // Pressed state / dark label

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color titleText = Color(
    0xFF0F172A,
  ); // Slate-900: sharper, more contrast
  static const Color bodyText = Color(
    0xFF475569,
  ); // Slate-600: readable, not washed out
  static const Color subtleText = Color(
    0xFF94A3B8,
  ); // Placeholder / disabled / hints

  // ── Status ─────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B); // Same as sand — intentional
  static const Color error = Color(0xFFDC2626); // Slightly deeper red

  // ── Borders & Dividers ─────────────────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0); // Slate-200: crisper lines
  static const Color borderFocus = Color(
    0xFF1D4ED8,
  ); // Primary when field is focused
  static const Color divider = Color(0xFFF1F5F9); // Ultra-subtle between rows

  // ── Shadows (use as BoxShadow color) ───────────────────────────────────────
  static const Color shadowSoft = Color(
    0x0A000000,
  ); // 4% black — card resting shadow
  static const Color shadowMedium = Color(
    0x14000000,
  ); // 8% black — elevated cards
  static const Color shadowPrimary = Color(
    0x291D4ED8,
  ); // 16% primary — glowing button shadow

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient vendorGradient = LinearGradient(
    colors: [Color(0xFF15803D), Color(0xFF14532D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sandGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
