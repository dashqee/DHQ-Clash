import 'package:fl_clash/common/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppTheme exposes the fixed DHQ Clash dark palette', () {
    expect(AppTheme.colorScheme.brightness, Brightness.dark);
    expect(AppTheme.colorScheme.surface, AppTheme.surface);
    expect(AppTheme.colorScheme.primary, AppTheme.blue);
    expect(AppTheme.colorScheme.tertiary, AppTheme.cyan);
    expect(AppTheme.colorScheme.error, AppTheme.danger);
  });

  test('AppTheme applies shared brand component shapes', () {
    final theme = AppTheme.build(
      pageTransitionsTheme: const PageTransitionsTheme(),
    );

    expect(theme.brightness, Brightness.dark);
    expect(theme.cardTheme.shape, AppTheme.cardShape);
    expect(theme.navigationRailTheme.backgroundColor, AppTheme.surface);
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
  });
}
