
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const indigo = Color(0xFF4F46E5);
  static const secondary = Color(0xFF06B6D4);
  static const accent = Color(0xFF8B5CF6);
  static const dark = Color(0xFF0F172A);
  static const ink = Color(0xFF111111);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);

  static const warnBg = Color(0xFFFFFBEB);
  static const warnFg = Color(0xFFB45309);

  static const muted = Color(0xFF64748B);
  static const textMuted = Color(0xFF888888);
  static const textFaint = Color(0xFF999999);
  static const textGhost = Color(0xFFAAAAAA);

  static const border = Color(0xFFEFEFEF);
  static const borderSoft = Color(0xFFF4F4F4);
  static const fieldBg = Color(0xFFF4F4F4);
  static const headerBg = Color(0xFFF9F9F9);

  // Chip / status palettes
  static const chipBlueBg = Color(0xFFEEF2FF);
  static const chipBlueFg = Color(0xFF4F46E5);
  static const chipGreenBg = Color(0xFFECFDF5);
  static const chipGreenFg = Color(0xFF047857);
  static const chipOrangeBg = Color(0xFFFFF7ED);
  static const chipOrangeFg = Color(0xFFC2410C);
  static const chipNeutralBg = Color(0xFFF4F4F4);
  static const chipNeutralFg = Color(0xFF555555);

  static const statusClosedBg = Color(0xFFF1F5F9);
  static const statusClosedFg = Color(0xFF64748B);

  static const danger = Color(0xFFEF4444);
  static const dangerBg = Color(0xFFFEF2F2);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.indigo,
      primary: AppColors.indigo,
    ),
  );

  return base.copyWith(
    textTheme: GoogleFonts.beVietnamProTextTheme(base.textTheme),
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: Colors.white,
      indicatorColor: AppColors.chipBlueBg,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.beVietnamPro(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.indigo : const Color(0xFFBBBBBB),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? AppColors.indigo : const Color(0xFFBBBBBB),
        );
      }),
    ),
  );
}
