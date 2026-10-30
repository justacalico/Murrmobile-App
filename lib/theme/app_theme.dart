import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0F0F11);
  static const surface = Color(0xFF1A1A1E);
  static const surfaceHighlight = Color(0xFF25252A);
  static const primary = Color(0xFFFF6B35);
  static const secondary = Color(0xFF00D4AA);
  static const text = Color(0xFFF5F5F5);
  static const textMuted = Color(0xFF8B8B8D);
  static const divider = Color(0xFF2A2A2E);
  static const error = Color(0xFFFF4444);
}

class LightColors {
  static const bg = Color(0xFFF5F5F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHighlight = Color(0xFFF0F0F2);
  static const primary = Color(0xFFFF6B35);
  static const secondary = Color(0xFF00D4AA);
  static const text = Color(0xFF1A1A1E);
  static const textMuted = Color(0xFF6B6B6E);
  static const divider = Color(0xFFE0E0E2);
  static const error = Color(0xFFFF4444);
}

class AmoledColors {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF0A0A0A);
  static const surfaceHighlight = Color(0xFF141414);
  static const primary = Color(0xFFFF6B35);
  static const secondary = Color(0xFF00D4AA);
  static const text = Color(0xFFF5F5F5);
  static const textMuted = Color(0xFF888888);
  static const divider = Color(0xFF1A1A1A);
  static const error = Color(0xFFFF4444);
}

class _Palette {
  const _Palette({
    required this.bg,
    required this.surface,
    required this.surfaceHighlight,
    required this.primary,
    required this.secondary,
    required this.text,
    required this.textMuted,
    required this.divider,
    required this.error,
  });

  final Color bg;
  final Color surface;
  final Color surfaceHighlight;
  final Color primary;
  final Color secondary;
  final Color text;
  final Color textMuted;
  final Color divider;
  final Color error;
}

const _darkPalette = _Palette(
  bg: AppColors.bg,
  surface: AppColors.surface,
  surfaceHighlight: AppColors.surfaceHighlight,
  primary: AppColors.primary,
  secondary: AppColors.secondary,
  text: AppColors.text,
  textMuted: AppColors.textMuted,
  divider: AppColors.divider,
  error: AppColors.error,
);

const _lightPalette = _Palette(
  bg: LightColors.bg,
  surface: LightColors.surface,
  surfaceHighlight: LightColors.surfaceHighlight,
  primary: LightColors.primary,
  secondary: LightColors.secondary,
  text: LightColors.text,
  textMuted: LightColors.textMuted,
  divider: LightColors.divider,
  error: LightColors.error,
);

const _amoledPalette = _Palette(
  bg: AmoledColors.bg,
  surface: AmoledColors.surface,
  surfaceHighlight: AmoledColors.surfaceHighlight,
  primary: AmoledColors.primary,
  secondary: AmoledColors.secondary,
  text: AmoledColors.text,
  textMuted: AmoledColors.textMuted,
  divider: AmoledColors.divider,
  error: AmoledColors.error,
);

class AppTheme {
  static ThemeData get dark =>
      _build(brightness: Brightness.dark, c: _darkPalette);

  static ThemeData get light => _build(
    brightness: Brightness.light,
    c: _lightPalette,
    light: true,
    indicatorAlpha: 0.15,
  );

  static ThemeData get amoled =>
      _build(brightness: Brightness.dark, c: _amoledPalette);

  static ColorScheme _colorScheme(bool light, _Palette c) => light
      ? ColorScheme.light(
          primary: c.primary,
          secondary: c.secondary,
          surface: c.surface,
          background: c.bg,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: c.text,
          onBackground: c.text,
          error: c.error,
        )
      : ColorScheme.dark(
          primary: c.primary,
          secondary: c.secondary,
          surface: c.surface,
          background: c.bg,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: c.text,
          onBackground: c.text,
          error: c.error,
        );

  static ThemeData _build({
    required Brightness brightness,
    required _Palette c,
    bool light = false,
    double indicatorAlpha = 0.2,
  }) => ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: c.bg,
    colorScheme: _colorScheme(light, c),
    useMaterial3: true,
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: c.text,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: c.text,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: c.text,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: c.text,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: c.textMuted,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: c.text,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: c.text,
        letterSpacing: -0.3,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: c.surface,
      selectedItemColor: c.primary,
      unselectedItemColor: c.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: c.primary.withValues(alpha: indicatorAlpha),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: c.primary);
        }
        return IconThemeData(color: c.textMuted);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: c.primary,
          );
        }
        return TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: c.textMuted,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      indicatorColor: c.primary.withValues(alpha: indicatorAlpha),
      selectedIconTheme: IconThemeData(color: c.primary),
      unselectedIconTheme: IconThemeData(color: c.textMuted),
      selectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: c.primary,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: c.textMuted,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        side: BorderSide(color: c.divider),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.primary, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
    ),
  );
}

// coverage:ignore-start
// Convenience extension kept for callers outside lib/; nothing in the app
// currently uses it.
extension BuildContextTheme on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}
// coverage:ignore-end
