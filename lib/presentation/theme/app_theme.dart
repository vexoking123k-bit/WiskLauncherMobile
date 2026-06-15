import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Backgrounds
  static const Color bgDeep    = Color(0xFF0A0E14);
  static const Color bgPanel   = Color(0xFF131822);
  static const Color bgPanelHi = Color(0xFF1B2230);
  static const Color stroke    = Color(0xFF252D3D);

  // Accents — a green/violet pair that nods at Minecraft without being kitsch.
  static const Color accent    = Color(0xFF5EE36F);
  static const Color accent2   = Color(0xFF8A8DFF);
  static const Color warn      = Color(0xFFFFC857);
  static const Color danger    = Color(0xFFFF5C6A);

  // Text
  static const Color textHi    = Color(0xFFEDF1F7);
  static const Color textMid   = Color(0xFFB6BFCD);
  static const Color textLo    = Color(0xFF8290A4);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme =
        GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: textHi,
      displayColor: textHi,
    );
    return base.copyWith(
      scaffoldBackgroundColor: bgDeep,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.black,
        secondary: accent2,
        surface: bgPanel,
        onSurface: textHi,
        error: danger,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bgDeep,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700, letterSpacing: -0.2),
      ),
      cardTheme: CardTheme(
        color: bgPanel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: stroke, width: 0.8),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textHi,
          side: const BorderSide(color: stroke),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgPanelHi,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.6),
        ),
        labelStyle: const TextStyle(color: textLo),
      ),
      dividerTheme: const DividerThemeData(color: stroke, thickness: 0.6),
      listTileTheme: const ListTileThemeData(
          textColor: textHi, iconColor: textMid,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgPanel,
        indicatorColor: accent.withOpacity(0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((s) =>
            TextStyle(color: s.contains(WidgetState.selected) ? textHi : textLo,
                fontWeight: FontWeight.w600, fontSize: 11)),
        iconTheme: WidgetStateProperty.resolveWith((s) =>
            IconThemeData(color: s.contains(WidgetState.selected) ? accent : textLo)),
        height: 64,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: bgPanel,
        indicatorColor: accent.withOpacity(0.18),
        unselectedLabelTextStyle: const TextStyle(color: textLo),
        selectedLabelTextStyle: const TextStyle(color: textHi, fontWeight: FontWeight.w700),
        selectedIconTheme: const IconThemeData(color: accent),
        unselectedIconTheme: const IconThemeData(color: textLo),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgPanelHi,
        contentTextStyle: const TextStyle(color: textHi),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bgPanelHi,
        selectedColor: accent.withOpacity(0.24),
        labelStyle: const TextStyle(color: textHi),
        side: const BorderSide(color: stroke),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: bgPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Reusable hero gradient — used on the home page.
const heroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1B2A2C), Color(0xFF12161F), Color(0xFF1B1C2C)],
);
