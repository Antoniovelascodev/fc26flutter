import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Night-stadium base palette. Team colors (see [teamColor]) carry identity;
/// the chrome stays neutral so they stand out.
class AppColors {
  static const ink = Color(0xFF0C1226);
  static const surface = Color(0xFF151D3A);
  static const surfaceHi = Color(0xFF1E2850);
  static const line = Color(0xFF2A3566);
  static const text = Color(0xFFEEF1FA);
  static const textDim = Color(0xFF8E9AC4);
  static const draw = Color(0xFF6D79AB);
  static const loss = Color(0xFF39457A);
  static const error = Color(0xFFFF7B72);
}

String _norm(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .trim();

const Map<String, Color> _kit = {
  'antonio': Color(0xFFFF5C4D), // coral
  'ivan': Color(0xFF4C8DFF), // blue
  'marcos': Color(0xFFFFC83D), // amber
  'mix': Color(0xFF35E0B0), // mint
};

const List<Color> _extraKits = [
  Color(0xFFC77DFF),
  Color(0xFFFF8FB1),
  Color(0xFF9BE564),
  Color(0xFFFF9A3D),
];

/// The "kit color" of a team, used everywhere its name appears.
Color teamColor(String name) {
  final key = _norm(name);
  return _kit[key] ?? _extraKits[key.hashCode.abs() % _extraKits.length];
}

/// A team color blended into a surface, for tinted panels.
Color teamWash(Color team, {int strength = 44, Color base = AppColors.surface}) =>
    Color.alphaBlend(team.withAlpha(strength), base);

/// Display face for names and scores.
///
/// Looks the font up by name so it still works if the installed google_fonts
/// version does not include it: falls back to Barlow Condensed.
TextStyle displayStyle({
  double size = 28,
  FontWeight weight = FontWeight.w800,
  Color color = AppColors.text,
  double? height,
  double letterSpacing = 0,
}) {
  TextStyle build(String family) => GoogleFonts.getFont(
        family,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height ?? 1.0,
        letterSpacing: letterSpacing,
      );
  try {
    return build('Big Shoulders Display');
  } catch (_) {
    return build('Barlow Condensed');
  }
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.text,
    onPrimary: AppColors.ink,
    secondary: AppColors.textDim,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.error,
    outline: AppColors.line,
  );

  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: scheme,
  );

  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: displayStyle(size: 34),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.surfaceHi,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.text : AppColors.textDim,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.text : AppColors.textDim,
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.text,
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textDim,
        textStyle: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHi,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(color: AppColors.textDim),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHi,
      contentTextStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
  );
}
