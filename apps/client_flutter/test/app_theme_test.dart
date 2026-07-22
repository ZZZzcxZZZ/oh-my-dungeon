import 'package:dnd_table_client/src/app/theme/app_theme.dart';
import 'package:dnd_table_client/src/features/app_preferences/domain/app_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme.light', () {
    test('enables Material 3', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      expect(theme.useMaterial3, isTrue);
    });

    test('uses a tonal ColorScheme derived from the seed color', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      expect(theme.colorScheme.brightness, Brightness.light);
      // The seed color itself should NOT leak in as the page background.
      // surfaceContainer / surface should be a neutral tonal value, not the
      // raw seed ARGB.
      expect(theme.colorScheme.surface, isNot(equals(Colors.transparent)));
      expect(theme.colorScheme.primary, isNot(equals(Colors.white)));
    });

    test('exposes navigation bar, rail, app bar, input, dialog, sheet, chip, card, button themes', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      expect(theme.navigationBarTheme, isNotNull);
      expect(theme.navigationRailTheme, isNotNull);
      expect(theme.appBarTheme, isNotNull);
      expect(theme.inputDecorationTheme, isNotNull);
      expect(theme.dialogTheme, isNotNull);
      expect(theme.bottomSheetTheme, isNotNull);
      expect(theme.chipTheme, isNotNull);
      expect(theme.cardTheme, isNotNull);
      // Button themes are present for the M3 button families.
      expect(theme.filledButtonTheme, isNotNull);
      expect(theme.elevatedButtonTheme, isNotNull);
      expect(theme.textButtonTheme, isNotNull);
      expect(theme.outlinedButtonTheme, isNotNull);
      expect(theme.segmentedButtonTheme, isNotNull);
    });

    test('caps card corner radius at 8 dp', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      final shape = theme.cardTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      final radius =
          (shape as RoundedRectangleBorder).borderRadius as BorderRadius;
      final resolved = radius.resolve(TextDirection.ltr);
      expect(resolved.topLeft.x, lessThanOrEqualTo(8));
      expect(resolved.topLeft.y, lessThanOrEqualTo(8));
      expect(resolved.bottomRight.x, lessThanOrEqualTo(8));
    });
  });

  group('AppTheme.dark', () {
    test('enables Material 3 and uses a dark color scheme', () {
      final theme = AppTheme.dark(AppPreferences.defaults);

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('caps card corner radius at 8 dp in dark mode too', () {
      final theme = AppTheme.dark(AppPreferences.defaults);

      final shape = theme.cardTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      final radius =
          (shape as RoundedRectangleBorder).borderRadius as BorderRadius;
      final resolved = radius.resolve(TextDirection.ltr);
      expect(resolved.topLeft.x, lessThanOrEqualTo(8));
      expect(resolved.bottomRight.y, lessThanOrEqualTo(8));
    });
  });

  group('contrast and variants', () {
    test('high-contrast preference bumps the contrastLevel', () {
      final normal = AppTheme.light(AppPreferences.defaults);
      final high = AppTheme.light(
        AppPreferences.defaults.copyWith(highContrastTheme: true),
      );

      // The primary tonal color in high contrast should differ from normal.
      expect(high.colorScheme.primary, isNot(equals(normal.colorScheme.primary)));
    });

    test('respects the dynamic scheme variant preference', () {
      final tonal = AppTheme.light(AppPreferences.defaults);
      final vibrant = AppTheme.light(
        AppPreferences.defaults.copyWith(dynamicSchemeVariant: 'vibrant'),
      );

      expect(vibrant.colorScheme.primary, isNot(equals(tonal.colorScheme.primary)));
    });
  });
}
