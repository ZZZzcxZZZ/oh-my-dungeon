import 'package:dnd_table_client/src/app/theme/app_theme.dart';
import 'package:dnd_table_client/src/features/app_preferences/domain/app_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme.light', () {
    test('enables Material 3', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      expect(theme.useMaterial3, isTrue);
      expect(theme.textTheme.bodyMedium?.fontFamily, 'NotoSansSC');
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

    test(
      'exposes navigation bar, rail, app bar, input, dialog, sheet, chip, card, button themes',
      () {
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
      },
    );

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

    test('chip label uses onSecondaryContainer when selected (E1)', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      // Unselected chips: label on surfaceContainerHigh.
      expect(theme.chipTheme.labelStyle?.color, theme.colorScheme.onSurface);
      // Selected chips (ChoiceChip/FilterChip/InputChip): the background
      // switches to secondaryContainer, so the label must follow the on-*
      // contract instead of staying onSurface.
      expect(
        theme.chipTheme.secondaryLabelStyle?.color,
        theme.colorScheme.onSecondaryContainer,
      );
    });

    test('dialog theme stays flat with elevation 0 (E4)', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      expect(theme.dialogTheme.elevation, 0);
      expect(theme.bottomSheetTheme.modalElevation, 0);
    });

    test('search bar is themed flat with 8dp radius (E5)', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      final searchBar = theme.searchBarTheme;
      expect(searchBar.elevation!.resolve({}), 0);
      expect(searchBar.surfaceTintColor!.resolve({}), Colors.transparent);
      final shape = searchBar.shape!.resolve({});
      expect(shape, isA<RoundedRectangleBorder>());
      final radius =
          (shape as RoundedRectangleBorder).borderRadius as BorderRadius;
      final resolved = radius.resolve(TextDirection.ltr);
      expect(resolved.topLeft.x, 8);
    });
  });

  group('AppTheme.light theme contract (DESIGN.md)', () {
    // 每个组件主题都必须落在 DESIGN.md 声明的契约上，防止 E1-E5 类
    // 回归（颜色角色 / 圆角 / 扁平化）。

    BorderRadius radiusOf(ShapeBorder? shape) {
      expect(shape, isA<RoundedRectangleBorder>());
      return ((shape as RoundedRectangleBorder).borderRadius as BorderRadius)
          .resolve(TextDirection.ltr);
    }

    test('card: surfaceContainerLow + outlineVariant border, flat, 8dp', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      expect(theme.cardTheme.color, theme.colorScheme.surfaceContainerLow);
      expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
      expect(theme.cardTheme.elevation, 0);
      final border = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(border.side.color, theme.colorScheme.outlineVariant);
      expect(radiusOf(theme.cardTheme.shape).topLeft.x, 8);
    });

    test('dialog: surfaceContainerHigh, flat, 16dp', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      expect(theme.dialogTheme.backgroundColor, theme.colorScheme.surfaceContainerHigh);
      expect(theme.dialogTheme.elevation, 0);
      expect(radiusOf(theme.dialogTheme.shape).topLeft.x, 16);
    });

    test('bottom sheet: surfaceContainerHigh, top radius 16, no elevation', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      expect(theme.bottomSheetTheme.backgroundColor, theme.colorScheme.surfaceContainerHigh);
      expect(theme.bottomSheetTheme.modalElevation, 0);
      expect(theme.bottomSheetTheme.surfaceTintColor, Colors.transparent);
      final shape = theme.bottomSheetTheme.shape as RoundedRectangleBorder;
      final radius = (shape.borderRadius as BorderRadius).resolve(TextDirection.ltr);
      expect(radius.topLeft.x, 16);
      expect(radius.bottomLeft.x, 0);
    });

    test('snackbar: floating inverseSurface with 8dp radius', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(theme.snackBarTheme.backgroundColor, theme.colorScheme.inverseSurface);
      expect(
        theme.snackBarTheme.contentTextStyle?.color,
        theme.colorScheme.onInverseSurface,
      );
      expect(radiusOf(theme.snackBarTheme.shape).topLeft.x, 8);
    });

    test('navigation: surfaceContainer bars with secondaryContainer indicator', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      expect(theme.navigationBarTheme.backgroundColor, theme.colorScheme.surfaceContainer);
      expect(theme.navigationBarTheme.indicatorColor, theme.colorScheme.secondaryContainer);
      expect(theme.navigationRailTheme.backgroundColor, theme.colorScheme.surfaceContainer);
      expect(theme.navigationRailTheme.indicatorColor, theme.colorScheme.secondaryContainer);
    });

    test('inputs: filled surfaceContainerHigh with 8dp radius', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.inputDecorationTheme.fillColor, theme.colorScheme.surfaceContainerHigh);
      final border = theme.inputDecorationTheme.border as OutlineInputBorder;
      expect(
        border.borderRadius.resolve(TextDirection.ltr).topLeft.x,
        8,
      );
    });

    test('divider: outlineVariant 1px', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      expect(theme.dividerTheme.color, theme.colorScheme.outlineVariant);
      expect(theme.dividerTheme.thickness, 1);
    });

    test('button families: filled/elevated/text/outlined roles with 8dp radius', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      final filled = theme.filledButtonTheme.style!;
      expect(filled.backgroundColor!.resolve({}), theme.colorScheme.primary);
      expect(filled.foregroundColor!.resolve({}), theme.colorScheme.onPrimary);
      expect(
        (filled.shape!.resolve({}) as RoundedRectangleBorder)
            .borderRadius
            .resolve(TextDirection.ltr)
            .topLeft
            .x,
        8,
      );

      final elevated = theme.elevatedButtonTheme.style!;
      expect(elevated.backgroundColor!.resolve({}), theme.colorScheme.surfaceContainerHigh);
      expect(elevated.foregroundColor!.resolve({}), theme.colorScheme.onSurface);
      expect(elevated.surfaceTintColor!.resolve({}), Colors.transparent);

      final text = theme.textButtonTheme.style!;
      expect(text.foregroundColor!.resolve({}), theme.colorScheme.primary);

      final outlined = theme.outlinedButtonTheme.style!;
      expect(outlined.foregroundColor!.resolve({}), theme.colorScheme.primary);
      expect(outlined.side!.resolve({})!.color, theme.colorScheme.outline);
    });

    test('switch: primary track when selected', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      expect(
        theme.switchTheme.trackColor!.resolve({WidgetState.selected}),
        theme.colorScheme.primary,
      );
      expect(
        theme.switchTheme.thumbColor!.resolve({WidgetState.selected}),
        theme.colorScheme.onPrimary,
      );
    });

    test('segmented button: selected secondaryContainer roles', () {
      final theme = AppTheme.light(AppPreferences.defaults);

      final style = theme.segmentedButtonTheme.style;
      expect(
        style!.backgroundColor!.resolve({WidgetState.selected}),
        theme.colorScheme.secondaryContainer,
      );
      expect(
        style.foregroundColor!.resolve({WidgetState.selected}),
        theme.colorScheme.onSecondaryContainer,
      );
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
      expect(
        high.colorScheme.primary,
        isNot(equals(normal.colorScheme.primary)),
      );
    });

    test('respects the dynamic scheme variant preference', () {
      final tonal = AppTheme.light(AppPreferences.defaults);
      final vibrant = AppTheme.light(
        AppPreferences.defaults.copyWith(dynamicSchemeVariant: 'vibrant'),
      );

      expect(
        vibrant.colorScheme.primary,
        isNot(equals(tonal.colorScheme.primary)),
      );
    });
  });
}
