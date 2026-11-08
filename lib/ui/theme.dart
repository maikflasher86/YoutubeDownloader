import 'package:flutter/material.dart';

const _bg = Color(0xFF0F0F12);
const _surface = Color(0xFF17171B);
const surfaceHigh = Color(0xFF212126);
const accent = Color(0xFFE05A6D);

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    brightness: Brightness.dark,
    surface: _surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: _bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: _surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0x14FFFFFF)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Colors.white70,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    ),
    dividerTheme: const DividerThemeData(color: Color(0x14FFFFFF)),
  );
}
