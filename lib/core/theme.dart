import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const primary = Color(0xFF5F447B), p600 = Color(0xFF9274AF), p300 = Color(0xFFC8A8E6),
      p100 = Color(0xFFE4D3F3), bg = Color(0xFFF8F7FA), surface = Colors.white,
      text = Color(0xFF25202B), text2 = Color(0xFF6B6470), border = Color(0xFFE6E1EA),
      success = Color(0xFF2E8B67), warning = Color(0xFFD99A2B), error = Color(0xFFC94A4A),
      info = Color(0xFF3B82A0),
      marca = Color(0xFF593286); // morado del icono SENDA (arranque y encabezados)
}

/// Alturas mínimas: 48dp general, 64dp modo paciente.
double minTap(bool patient) => patient ? 64 : 48;

ThemeData buildTheme({bool highContrast = false, bool patient = false}) {
  final text = highContrast ? Colors.black : C.text;
  final primary = highContrast ? const Color(0xFF3A2650) : C.primary;
  TextStyle s(double sz, double h, FontWeight w) =>
      GoogleFonts.inter(fontSize: sz, height: h / sz, fontWeight: w, color: text);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary, error: C.error, surface: C.surface),
    scaffoldBackgroundColor: highContrast ? Colors.white : C.bg,
    textTheme: TextTheme(
      headlineLarge: s(32, 40, FontWeight.w700), headlineMedium: s(26, 34, FontWeight.w700),
      headlineSmall: s(20, 28, FontWeight.w600), bodyLarge: s(18, 27, FontWeight.w400),
      bodyMedium: s(16, 24, FontWeight.w400), labelLarge: s(16, 24, FontWeight.w600),
      bodySmall: s(14, 20, FontWeight.w500)),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        minimumSize: Size(48, minTap(patient)), backgroundColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        minimumSize: Size(48, minTap(patient)), foregroundColor: primary,
        side: BorderSide(color: highContrast ? Colors.black : C.border, width: highContrast ? 2 : 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: C.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 2))),
    cardTheme: CardThemeData(color: C.surface, elevation: 0, margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.border))),
  );
}
