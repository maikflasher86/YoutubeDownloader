import 'package:flutter/material.dart';

const _bg = Color(0xFF11151D);
const _surface = Color(0xFF191F2A);
const surfaceHigh = Color(0xFF202837);
const borderColor = Color(0xFF2B3343);
const mutedColor = Color(0xFF9BA8BF);
const accent = Color(0xFF5889FF);

ThemeData buildDarkTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        dynamicSchemeVariant: DynamicSchemeVariant.neutral,
        brightness: Brightness.dark,
        surface: _surface,
      ).copyWith(
        primary: accent,
        onPrimary: Colors.white,
        onSurface: const Color(0xFFF2F5FC),
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
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: borderColor),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Colors.white70,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    ),
    dividerTheme: const DividerThemeData(color: borderColor),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: _surface,
      indicatorColor: Color(0xFF203153),
    ),
  );
}
