import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murrmobile/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('dark theme has expected colors', () {
      final theme = AppTheme.dark;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.bg);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.secondary, AppColors.secondary);
      expect(theme.colorScheme.surface, AppColors.surface);
      expect(theme.colorScheme.error, AppColors.error);
      expect(theme.useMaterial3, isTrue);
      expect(theme.textTheme.displayLarge!.color, AppColors.text);
      expect(theme.textTheme.bodyMedium!.color, AppColors.textMuted);
      expect(theme.cardTheme.color, AppColors.surface);
      expect(theme.dividerTheme.color, AppColors.divider);
      expect(
        theme.bottomNavigationBarTheme.selectedItemColor,
        AppColors.primary,
      );
      expect(
        theme.elevatedButtonTheme.style!.backgroundColor!.resolve({}),
        AppColors.primary,
      );
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.inputDecorationTheme.fillColor, AppColors.surface);
    });

    test('light theme has expected colors', () {
      final theme = AppTheme.light;
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, LightColors.bg);
      expect(theme.colorScheme.primary, LightColors.primary);
      expect(theme.colorScheme.surface, LightColors.surface);
      expect(theme.textTheme.displayLarge!.color, LightColors.text);
      expect(theme.cardTheme.color, LightColors.surface);
      expect(theme.inputDecorationTheme.fillColor, LightColors.surface);
    });

    test('amoled theme has pure black surfaces', () {
      final theme = AppTheme.amoled;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, Colors.black);
      expect(theme.colorScheme.surface, AmoledColors.surface);
      expect(theme.cardTheme.color, AmoledColors.surface);
      expect(theme.dividerTheme.color, AmoledColors.divider);
    });

    test('navigation bar theme resolves selected and unselected states', () {
      final theme = AppTheme.dark;
      final iconTheme = theme.navigationBarTheme.iconTheme!;
      expect(
        iconTheme.resolve({WidgetState.selected})!.color,
        AppColors.primary,
      );
      expect(iconTheme.resolve({})!.color, AppColors.textMuted);

      final labelStyle = theme.navigationBarTheme.labelTextStyle!;
      expect(
        labelStyle.resolve({WidgetState.selected})!.color,
        AppColors.primary,
      );
      expect(labelStyle.resolve({})!.color, AppColors.textMuted);
    });

    test('light theme navigation bar resolves states too', () {
      final theme = AppTheme.light;
      final iconTheme = theme.navigationBarTheme.iconTheme!;
      expect(
        iconTheme.resolve({WidgetState.selected})!.color,
        LightColors.primary,
      );
      expect(iconTheme.resolve({})!.color, LightColors.textMuted);
      final labelStyle = theme.navigationBarTheme.labelTextStyle!;
      expect(
        labelStyle.resolve({WidgetState.selected})!.color,
        LightColors.primary,
      );
      expect(labelStyle.resolve({})!.color, LightColors.textMuted);
    });

    test('amoled navigation bar resolves states', () {
      final theme = AppTheme.amoled;
      final iconTheme = theme.navigationBarTheme.iconTheme!;
      expect(
        iconTheme.resolve({WidgetState.selected})!.color,
        AmoledColors.primary,
      );
      expect(iconTheme.resolve({})!.color, AmoledColors.textMuted);
      final labelStyle = theme.navigationBarTheme.labelTextStyle!;
      expect(
        labelStyle.resolve({WidgetState.selected})!.color,
        AmoledColors.primary,
      );
      expect(labelStyle.resolve({})!.color, AmoledColors.textMuted);
      expect(
        theme.inputDecorationTheme.hintStyle!.color,
        AmoledColors.textMuted,
      );
    });
  });
}
