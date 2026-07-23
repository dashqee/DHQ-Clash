import 'package:flutter/material.dart';

/// The single DHQ Clash visual system shared by every platform.
class AppTheme {
  const AppTheme._();

  static const background = Color(0xFF08091F);
  static const surface = Color(0xFF10112D);
  static const surfaceLow = Color(0xFF0D0E28);
  static const surfaceHigh = Color(0xFF151735);
  static const surfaceHover = Color(0xFF1B1E42);
  static const text = Color(0xFFF7F8FF);
  static const muted = Color(0xFFAEB5D3);
  static const violet = Color(0xFF7437F5);
  static const blue = Color(0xFF4877F4);
  static const cyan = Color(0xFF42E5E8);
  static const lime = Color(0xFFC7FF3D);
  static const danger = Color(0xFFFF8D9B);
  static const line = Color(0x387468F5);
  static const lineStrong = Color(0x6B42E5E8);

  static const brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [violet, blue, cyan],
    stops: [0, 0.54, 1],
  );

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
    side: const BorderSide(color: line),
  );

  static final ColorScheme colorScheme =
      ColorScheme.fromSeed(
        seedColor: blue,
        brightness: Brightness.dark,
        dynamicSchemeVariant: DynamicSchemeVariant.content,
      ).copyWith(
        primary: blue,
        onPrimary: Colors.white,
        primaryContainer: violet,
        onPrimaryContainer: Colors.white,
        secondary: violet,
        onSecondary: Colors.white,
        secondaryContainer: surfaceHover,
        onSecondaryContainer: text,
        tertiary: cyan,
        onTertiary: background,
        tertiaryContainer: const Color(0x1A42E5E8),
        onTertiaryContainer: cyan,
        error: danger,
        onError: background,
        errorContainer: const Color(0x1AFF8D9B),
        onErrorContainer: danger,
        surface: surface,
        onSurface: text,
        onSurfaceVariant: muted,
        outline: lineStrong,
        outlineVariant: line,
        shadow: Colors.black,
        scrim: const Color(0xD908091F),
        inverseSurface: text,
        onInverseSurface: background,
        inversePrimary: cyan,
        surfaceDim: background,
        surfaceBright: surfaceHover,
        surfaceContainerLowest: background,
        surfaceContainerLow: surfaceLow,
        surfaceContainer: surface,
        surfaceContainerHigh: surfaceHigh,
        surfaceContainerHighest: surfaceHover,
      );

  static ThemeData build({required PageTransitionsTheme pageTransitionsTheme}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
    );

    final tt = base.textTheme;
    final textTheme = tt.copyWith(
      headlineLarge: tt.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: tt.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      headlineSmall: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: tt.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
      ),
      titleMedium: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSm),
    );

    return base.copyWith(
      pageTransitionsTheme: pageTransitionsTheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: background,
      dividerColor: line,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: background.withValues(alpha: 0.88),
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: text),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: controlShape,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: controlShape,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: controlShape,
          textStyle: textTheme.labelLarge,
          side: const BorderSide(color: line),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(shape: controlShape),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXs),
          side: const BorderSide(color: line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: const BorderSide(color: line),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
          side: BorderSide(color: line),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        minWidth: 88,
        backgroundColor: surface,
        indicatorColor: cyan.withValues(alpha: 0.1),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        selectedIconTheme: const IconThemeData(color: cyan),
        unselectedIconTheme: const IconThemeData(color: muted),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: cyan,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(color: muted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cyan.withValues(alpha: 0.1),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? cyan : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected) ? text : muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? text : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? cyan.withValues(alpha: 0.72)
              : surfaceHover,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(line),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: cyan),
        ),
      ),
    );
  }
}

class BrandBackground extends StatelessWidget {
  final Widget child;

  const BrandBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.background,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.88, -1.05),
            radius: 1.25,
            colors: [Color(0x2442E5E8), Color(0x0008091F)],
            stops: [0, 0.72],
          ),
        ),
        child: child,
      ),
    );
  }
}
