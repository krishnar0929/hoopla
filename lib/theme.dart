import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hoopla colors, taken from the approved design.
class HC {
  static const ink = Color(0xFF17142B);
  static const violet = Color(0xFF6C4CF5);
  static const lime = Color(0xFFC8F560);
  static const coral = Color(0xFFFF6B4A);
  static const ground = Color(0xFFF6F5FB);
  static const card = Colors.white;
  static const line = Color(0xFFE3E0F0);
  static const track = Color(0xFFE9E6F5);
  static const muted = Color(0xFF5E5A72);
  static const nightCard = Color(0xFF26233A);
  static const nightMuted = Color(0xFFC9C5DA);

  /// Soft tile colors for game thumbnails and vendor photos.
  static const tiles = [
    Color(0xFFFFE0D8),
    Color(0xFFE4DCFF),
    Color(0xFFE9F8C6),
    Color(0xFFD9EEFF),
  ];
}

/// Space Grotesk for headings and big numbers.
TextStyle display(double size, {Color color = HC.ink, FontWeight weight = FontWeight.w700}) {
  return GoogleFonts.spaceGrotesk(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.08,
    letterSpacing: -0.025 * size,
  );
}

/// Inter for everything else.
TextStyle body(double size, {Color color = HC.ink, FontWeight weight = FontWeight.w400}) {
  return GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: 1.35);
}

TextStyle overline({Color color = HC.muted}) {
  return GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: color,
    letterSpacing: 0.6,
  );
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: HC.violet, primary: HC.violet, surface: HC.ground),
    scaffoldBackgroundColor: HC.ground,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: HC.ink, displayColor: HC.ink),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HC.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: HC.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: HC.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: HC.violet, width: 1.5)),
    ),
  );
}
