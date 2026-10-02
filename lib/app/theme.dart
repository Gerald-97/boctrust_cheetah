import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

export 'colors.dart';
export 'tokens.dart';

import 'colors.dart';
import 'tokens.dart';

SystemUiOverlayStyle kOverlayLight({Color? statusColor, Color? navColor}) =>
    SystemUiOverlayStyle(
      statusBarColor: statusColor ?? kPrimaryLight,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: navColor ?? kPrimaryLight,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: true,
    );

SystemUiOverlayStyle kOverlayDark({Color? statusColor, Color? navColor}) =>
    SystemUiOverlayStyle(
      statusBarColor: statusColor ?? kPrimaryBlue,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: navColor ?? kPrimaryBlue,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: true,
    );

/// FH Oscar with fixed-width digits, so amounts line up and do not shift
/// width as they change. Use for figures only; labels stay in [kFontFamily].
const kFigureFeatures = [FontFeature.tabularFigures()];

/// FH Oscar has no naira sign (₦); glyphs it lacks come from the text font.
const kFigureFontFallback = [kFontFamily];

extension BocFigureTextStyle on TextStyle {
  TextStyle get figures => copyWith(
    fontFamily: kFigureFontFamily,
    fontFamilyFallback: kFigureFontFallback,
    fontFeatures: kFigureFeatures,
  );
}

class CheetahTheme {
  const CheetahTheme._();

  static ThemeData get lightTheme =>
      _theme(Brightness.light, BocSemanticColors.light);

  static ThemeData get darkTheme =>
      _theme(Brightness.dark, BocSemanticColors.dark);

  /// Themes for the High contrast accessibility preference.
  static ThemeData theme(Brightness brightness, {bool highContrast = false}) {
    final base = brightness == Brightness.dark
        ? BocSemanticColors.dark
        : BocSemanticColors.light;
    return _theme(
      brightness,
      highContrast ? base.highContrast() : base,
      highContrast: highContrast,
    );
  }

  /// Effective text scale: the system setting times the in-app Accessibility
  /// preference, kept within bounds every screen is laid out for.
  static TextScaler clampTextScaler(
    TextScaler system, {
    double preferenceMultiplier = 1.0,
  }) {
    final scale = (system.scale(14) / 14) * preferenceMultiplier;
    return TextScaler.linear(scale.clamp(0.9, 2.0));
  }

  static ThemeData _theme(
    Brightness brightness,
    BocSemanticColors c, {
    bool highContrast = false,
  }) {
    // High contrast doubles every hairline so edges read without relying on
    // colour alone.
    final line = highContrast ? 2.0 : 1.0;
    final dark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: BocColors.navy,
      brightness: brightness,
      primary: dark ? BocColors.goldLight : BocColors.navy,
      onPrimary: dark ? BocColors.navy : BocColors.goldLight,
      secondary: BocColors.goldLight,
      onSecondary: BocColors.navy,
      error: c.errorText,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textTertiary,
      outline: c.border,
      outlineVariant: c.border,
    );
    final text = _textTheme(c);
    final radiusSm = BorderRadius.circular(BocRadius.sm);
    OutlineInputBorder fieldBorder(Color color, [double? width]) =>
        OutlineInputBorder(
          borderRadius: radiusSm,
          borderSide: BorderSide(color: color, width: width ?? line),
        );
    final buttonShape = RoundedRectangleBorder(borderRadius: radiusSm);
    final buttonText = text.labelLarge;

    return ThemeData(
      useMaterial3: true,
      fontFamily: kFontFamily,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.background,
      cardColor: c.surface,
      dividerColor: c.border,
      extensions: <ThemeExtension<dynamic>>[c],
      textTheme: text,
      // Every button gets a 48px hit area without growing visually;
      // full-width PrimaryButton sets its own 56px height.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleMedium,
        systemOverlayStyle: dark
            ? kOverlayDark(statusColor: c.background, navColor: c.background)
            : kOverlayLight(statusColor: c.background, navColor: c.surface),
      ),
      dividerTheme: DividerThemeData(
        color: c.border,
        space: line,
        thickness: line,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: buttonShape,
          textStyle: buttonText,
          // Navy on light; gold on dark, where navy would vanish into the
          // navy background.
          backgroundColor: dark ? BocColors.goldLight : BocColors.navy,
          foregroundColor: dark ? BocColors.navy : BocColors.goldLight,
          // Solid disabled colors keep text legible regardless of the surface
          // behind the button while preserving a visibly inactive state.
          disabledBackgroundColor: dark ? BocColors.navy2 : BocColors.grey,
          disabledForegroundColor: dark ? c.textSecondary : BocColors.navy,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: buttonShape,
          textStyle: buttonText,
          backgroundColor: c.surfaceMuted,
          foregroundColor: dark ? c.textPrimary : BocColors.navy,
          side: BorderSide(color: c.border, width: line),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.blueStrong,
          textStyle: text.titleSmall,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        isDense: false,
        constraints: const BoxConstraints(minHeight: 56),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BocSpace.md,
          vertical: 14,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: c.textHint),
        labelStyle: text.labelMedium?.copyWith(color: c.textTertiary),
        floatingLabelStyle: text.labelMedium?.copyWith(color: c.textPrimary),
        helperStyle: text.bodySmall?.copyWith(color: c.textTertiary),
        errorStyle: text.bodySmall?.copyWith(color: c.errorText),
        border: fieldBorder(c.border),
        enabledBorder: fieldBorder(c.border),
        disabledBorder: fieldBorder(c.border.withValues(alpha: 0.5)),
        focusedBorder: fieldBorder(
          dark ? BocColors.goldLight : BocColors.navy,
          line + 0.5,
        ),
        errorBorder: fieldBorder(c.error),
        focusedErrorBorder: fieldBorder(c.error, line + 0.5),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.success : c.border,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceMuted,
        // Selected chips need a fill that stands out from the surface in
        // both themes: navy on light, gold on dark.
        selectedColor: dark ? BocColors.goldLight : BocColors.navy,
        side: BorderSide(color: c.border, width: line),
        shape: const StadiumBorder(),
        labelStyle: text.titleSmall,
        secondaryLabelStyle: text.titleSmall?.copyWith(
          color: dark ? BocColors.navy : BocColors.goldLight,
        ),
        checkmarkColor: dark ? BocColors.navy : BocColors.goldLight,
        padding: const EdgeInsets.symmetric(
          horizontal: BocSpace.sm,
          vertical: BocSpace.xs,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        // Dialogs are the tightest surface at large text; one step smaller.
        titleTextStyle: text.titleLarge?.copyWith(fontSize: 18),
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BocRadius.md),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.border,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BocRadius.lg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: BocColors.navy,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.onNavy),
        shape: RoundedRectangleBorder(borderRadius: radiusSm),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? (dark ? c.textPrimary : BocColors.navy)
                : c.textTertiary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? (dark ? c.textPrimary : BocColors.navy)
                : c.textTertiary,
          ),
        ),
      ),
    );
  }

  /// Plus Jakarta Sans for text; the display styles are FH Oscar figures.
  static TextTheme _textTheme(BocSemanticColors c) {
    TextStyle figure(double size, double height) => TextStyle(
      fontFamily: kFigureFontFamily,
      fontFamilyFallback: kFigureFontFallback,
      fontFeatures: kFigureFeatures,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w600,
      color: c.textPrimary,
    );
    TextStyle style(
      double size,
      FontWeight weight,
      double height,
      Color color, {
      double letterSpacing = 0,
    }) => TextStyle(
      // Explicit, because component themes take these styles directly and
      // would otherwise fall back to the platform font.
      fontFamily: kFontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
    );
    return TextTheme(
      // Display styles are reserved for figures (balances and amounts).
      displayLarge: figure(32, 1.15),
      displayMedium: figure(28, 1.15),
      displaySmall: figure(24, 1.2),
      headlineSmall: style(24, FontWeight.w700, 1.2, c.textPrimary),
      titleLarge: style(20, FontWeight.w700, 1.25, c.textPrimary),
      titleMedium: style(16, FontWeight.w700, 1.3, c.textPrimary),
      titleSmall: style(14, FontWeight.w600, 1.35, c.textPrimary),
      bodyLarge: style(16, FontWeight.w500, 1.45, c.textSecondary),
      bodyMedium: style(14, FontWeight.w500, 1.45, c.textSecondary),
      bodySmall: style(12, FontWeight.w500, 1.4, c.textTertiary),
      labelLarge: style(16, FontWeight.w700, 1.2, BocColors.goldLight),
      labelMedium: style(
        12,
        FontWeight.w600,
        1.3,
        c.textTertiary,
        letterSpacing: 0.24,
      ),
    );
  }
}
