import 'package:flutter/material.dart';

/// Central place for MindSpark's look and feel.
class AppTheme {
  AppTheme._();

  /// Change this one colour to re-theme the whole app.
  static const Color seedColor = Color(0xFF4F46E5);

  /// Generic family name; resolved by the device. Replaced by a bundled font later.
  static const String quoteFontFamily = 'serif';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final t = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: t.copyWith(
        headlineMedium: t.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: t.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: t.bodyMedium?.copyWith(height: 1.45),
        labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: scheme.secondaryContainer,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  /// Text style used for quote text everywhere in the app.
  static TextStyle quoteStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.headlineSmall ?? const TextStyle();
    return base.copyWith(
      fontFamily: quoteFontFamily,
      fontWeight: FontWeight.w500,
      height: 1.45,
    );
  }
}
