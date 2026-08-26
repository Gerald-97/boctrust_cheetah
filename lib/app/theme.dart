import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

export 'colors.dart';

import 'colors.dart';

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

class CheetahTheme {
  const CheetahTheme._();

  static ThemeData get lightTheme => _theme(
    brightness: Brightness.light,
    scaffold: kScaffoldLight,
    card: kCardLight,
    border: kBorderLight,
    text: kPrimaryText,
    bodyText: kTextInk,
    bodySoft: kTextInkSoft,
    semanticColors: BocSemanticColors.light,
  );

  static ThemeData get darkTheme => _theme(
    brightness: Brightness.dark,
    scaffold: kScaffoldDark,
    card: kCardDark,
    border: kBorderDark,
    text: const Color(0xFFF5F2E8),
    bodyText: kDarkInk,
    bodySoft: kDarkSoft,
    semanticColors: BocSemanticColors.dark,
  );

  static ThemeData _theme({
    required Brightness brightness,
    required Color scaffold,
    required Color card,
    required Color border,
    required Color text,
    required Color bodyText,
    required Color bodySoft,
    required BocSemanticColors semanticColors,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brightness == Brightness.dark ? kBlueColor : kPrimaryColor,
      brightness: brightness,
      primary: kPrimaryColor,
      secondary: kGoldColor,
      error: kErrorColor,
      surface: card,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: kFontFamily,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      cardColor: card,
      dividerColor: border,
      extensions: <ThemeExtension<dynamic>>[semanticColors],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffold,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: brightness == Brightness.dark
            ? kOverlayDark(statusColor: scaffold, navColor: scaffold)
            : kOverlayLight(statusColor: scaffold, navColor: kCardLight),
      ),
      dividerTheme: DividerThemeData(color: border),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: bodySoft),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBlueColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kErrorColor),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: text,
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: text,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: text,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          height: 1.35,
          fontWeight: FontWeight.w800,
          color: text,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w800,
          color: text,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w400,
          color: bodyText,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w400,
          color: bodyText,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w400,
          color: bodySoft,
        ),
        labelLarge: const TextStyle(
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: kGoldColor,
        ),
      ),
    );
  }
}
