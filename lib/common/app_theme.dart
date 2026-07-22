import 'package:flutter/material.dart';

/// Centralized Material 3 (Expressive) theme for DHQ Clash.
///
/// Before this, `ThemeData` only carried a `ColorScheme` + `useMaterial3`, so
/// every surface fell back to framework defaults. This module defines shared
/// shape/motion tokens and component themes so a single change re-skins the
/// whole app consistently. Individual widgets should reference [AppTheme]
/// radius tokens instead of hard-coding values.
class AppTheme {
  const AppTheme._();

  // Corner radius tokens (expressive scale — rounder than stock M3).
  static const double radiusXs = 10;
  static const double radiusSm = 14;
  static const double radiusMd = 18;
  static const double radiusLg = 24;
  static const double radiusXl = 28;
  static const double radiusXxl = 32;

  static BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  static BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  static BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);
  static BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);

  static final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radiusLg),
  );

  /// Build the full app [ThemeData] from a resolved [colorScheme].
  static ThemeData build({
    required ColorScheme colorScheme,
    required PageTransitionsTheme pageTransitionsTheme,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
    );

    // Expressive typography: heavier titles/labels, same M3 metrics/font so
    // existing layouts and the user-selectable font are untouched.
    final tt = base.textTheme;
    final textTheme = tt.copyWith(
      headlineLarge: tt.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    const stadium = StadiumBorder();

    return base.copyWith(
      pageTransitionsTheme: pageTransitionsTheme,
      textTheme: textTheme,
      // Expressive ripple.
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      // Pill-shaped buttons across the board.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: stadium,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: stadium,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: stadium,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: stadium,
          textStyle: textTheme.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(shape: stadium),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXs)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXl)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
      ),
      // Unify the desktop rail with the mobile NavigationBar look.
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        indicatorShape: stadium,
        selectedIconTheme: IconThemeData(color: colorScheme.onSecondaryContainer),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
