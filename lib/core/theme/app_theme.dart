import 'package:flutter/material.dart';

/// Material 3 theming for Voice Docs AI.
///
/// Both themes are seeded from the same brand indigo — sampled from the
/// app's mic+document logomark — so light/dark stay visually related, per
/// Material 3's dynamic color guidance, rather than hand-picking a separate
/// flat palette per mode.
class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF5B67F1);

  /// The logo's radiating sound-wave burst, cyan through orange — used for
  /// decorative accents (e.g. the mic button's pulse rings) that should echo
  /// the icon directly rather than derive from the single Material seed.
  static const List<Color> brandRays = [
    Color(0xFF3EC6F0),
    Color(0xFF6B8CF5),
    Color(0xFF9B6FE8),
    Color(0xFFE85B9B),
    Color(0xFFF0A860),
  ];

  /// Assigned round-robin to folders as they're created, so each one gets a
  /// distinct, consistent color for quick visual scanning in History —
  /// separate from [brandRays] since folders need more than 5 distinct
  /// values and don't need to match the logo specifically.
  static const List<Color> folderPalette = [
    Color(0xFF3EC6F0),
    Color(0xFF6B8CF5),
    Color(0xFF9B6FE8),
    Color(0xFFE85B9B),
    Color(0xFFF0A860),
    Color(0xFF4CAF8E),
    Color(0xFFE0574C),
    Color(0xFF54B0E8),
  ];

  /// Two-stop gradient (primary → tertiary) for hero surfaces that need to
  /// stay readable with text on top — the translated chat bubble, gradient
  /// buttons, etc. Bolder than a flat fill, calmer than the full rainbow.
  static LinearGradient heroGradient(
    ColorScheme scheme, {
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return LinearGradient(begin: begin, end: end, colors: [scheme.primary, scheme.tertiary]);
  }

  /// The full logo palette as a gradient, for smaller decorative accents
  /// (avatars, underlines) where a rainbow sweep reads as branding rather
  /// than fighting with foreground text.
  static LinearGradient rainbowGradient({
    Alignment begin = Alignment.centerLeft,
    Alignment end = Alignment.centerRight,
  }) {
    return LinearGradient(begin: begin, end: end, colors: brandRays);
  }

  static ThemeData light() => _base(
        ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light),
      );

  static ThemeData dark() => _base(
        ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
      );

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: scheme.surfaceTint,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
      ),
      textTheme: _textTheme(scheme),
      cardTheme: CardThemeData(
        elevation: 3,
        shadowColor: scheme.primary.withValues(alpha: 0.25),
        surfaceTintColor: Colors.transparent,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primary,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.primary.withValues(alpha: 0.3),
        elevation: 8,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurface,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 32),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    return const TextTheme(
      displaySmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontWeight: FontWeight.w400, height: 1.4),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400, height: 1.4),
      labelLarge: TextStyle(fontWeight: FontWeight.w700),
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }
}
