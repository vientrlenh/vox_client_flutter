import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/models/practice_session.dart';

/// Resolves the icon names carried by the models onto Material icons.
///
/// The models keep icons as plain strings so the data layer stays free of
/// Flutter imports — and so the backend can send the same names later.
IconData iconForName(String name) {
  switch (name) {
    case 'sports_soccer':
      return Icons.sports_soccer;
    case 'flight_takeoff':
      return Icons.flight_takeoff;
    case 'smart_toy':
      return Icons.smart_toy_outlined;
    case 'restaurant':
      return Icons.restaurant;
    case 'location_city':
      return Icons.location_city;
    case 'devices':
      return Icons.devices;
    case 'school':
      return Icons.school_outlined;
    case 'work_outline':
      return Icons.work_outline;
    case 'forum':
      return Icons.forum_outlined;
    case 'history_edu':
      return Icons.history_edu;
    case 'graphic_eq':
      return Icons.graphic_eq;
    case 'mic':
      return Icons.mic;
    case 'flag_outlined':
      return Icons.flag_outlined;
    case 'chat_bubble_outline':
    default:
      return Icons.chat_bubble_outline;
  }
}

/// Palette + glyph for one kind of correction, shared by the session bubbles,
/// the correction card and the weakness cards.
class CorrectionStyle {
  const CorrectionStyle({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.underline,
  });

  final Color background;
  final Color foreground;
  final IconData icon;

  /// Colour of the wavy underline drawn under the learner's transcript.
  final Color underline;
}

CorrectionStyle styleForCorrection(CorrectionType type) {
  switch (type) {
    case CorrectionType.grammar:
      return const CorrectionStyle(
        background: AppColors.chipOrangeBg,
        foreground: AppColors.chipOrangeFg,
        icon: Icons.history_edu,
        underline: AppColors.warning,
      );
    case CorrectionType.vocabulary:
      return const CorrectionStyle(
        background: Color(0xFFF5F3FF),
        foreground: Color(0xFF7C3AED),
        icon: Icons.auto_fix_high,
        underline: AppColors.accent,
      );
    case CorrectionType.pronunciation:
      return const CorrectionStyle(
        background: AppColors.chipGreenBg,
        foreground: AppColors.chipGreenFg,
        icon: Icons.graphic_eq,
        underline: AppColors.success,
      );
    case CorrectionType.fluency:
      return const CorrectionStyle(
        background: Color(0xFFECFEFF),
        foreground: Color(0xFF0E7490),
        icon: Icons.speed,
        underline: AppColors.secondary,
      );
  }
}

/// `mm:ss`
String formatClock(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Signed one-decimal delta, e.g. `+0.4` / `-0.2`.
String formatDelta(double delta) =>
    '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}';

/// The white "card" surface used across the summary / profile screens.
BoxDecoration get cardDecoration => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: const Color(0xFFE2E8F0)),
);

/// The lighter bordered row used on the home and list screens.
BoxDecoration get rowDecoration => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: AppColors.border, width: 1.5),
);

/// Standard page padding for the personalize screens.
const pagePadding = EdgeInsets.fromLTRB(20, 16, 20, 24);
