import 'package:flutter/material.dart';

class NColors {
  static const bg = Color(0xFF04060C);
  static const bg2 = Color(0xFF0A101C);
  static const surface = Color(0xFF0B1220);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFFA78BFA);
  static const lime = Color(0xFFA3E635);
  static const amber = Color(0xFFFBBF24);
  static const pink = Color(0xFFF472B6);
  static const text = Color(0xFFE9F2FF);
  static const muted = Color(0xFF7E8DA5);
  static const line = Color(0xFF1B2638);

  static const List<Color> accentGradient = [cyan, violet];
}

const TextStyle kMono = TextStyle(
  fontFamily: 'JetBrainsMono',
  fontSize: 10,
  letterSpacing: 1.6,
  color: NColors.muted,
  fontWeight: FontWeight.w500,
);

const TextStyle kMonoBright = TextStyle(
  fontFamily: 'JetBrainsMono',
  fontSize: 10,
  letterSpacing: 1.4,
  color: NColors.cyan,
  fontWeight: FontWeight.w600,
);

ThemeData buildNexusTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: 'SpaceGrotesk',
    colorScheme: const ColorScheme.dark(
      primary: NColors.cyan,
      onPrimary: Color(0xFF00151A),
      secondary: NColors.violet,
      surface: NColors.surface,
      onSurface: NColors.text,
      error: Color(0xFFFF6B81),
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: NColors.bg,
    canvasColor: NColors.bg,
    dividerColor: Colors.white.withValues(alpha: 0.06),
    textTheme: base.textTheme
        .apply(bodyColor: NColors.text, displayColor: NColors.text)
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.05,
          ),
          headlineMedium: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleLarge: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, height: 1.25),
          titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.65, color: Color(0xFFC7D3E4)),
          bodySmall: const TextStyle(fontSize: 12, height: 1.55, color: NColors.muted),
          labelSmall: TextStyle(fontSize: 10, letterSpacing: 1.2, color: NColors.muted.withValues(alpha: 0.9)),
        ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.035),
      hintStyle: TextStyle(color: NColors.muted.withValues(alpha: 0.7), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: NColors.cyan, width: 1.2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: NColors.surface,
      contentTextStyle: const TextStyle(color: NColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
