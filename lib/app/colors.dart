import 'package:flutter/material.dart';

const kFontFamily = 'PlusJakartaSans';

/// Figures only: balances, amounts, limits and account numbers.
const kFigureFontFamily = 'FHOscar';

const Color kPrimaryBlue = Color(0xFF4F7EB4);
const Color kPrimaryBlueDeep = Color(0xFF3A6497);
const Color kPrimaryBluePale = Color(0xFFE6EDF6);
const Color kPrimaryBluePaleDark = Color(0xFF1D3348);

const Color kPrimaryGold = Color(0xFFBF910C);
const Color kPrimaryGoldLight = Color(0xFFE5C367);
const Color kPrimaryGoldPale = Color(0xFFF2E9CE);
const Color kPrimaryGoldPaleDark = Color(0xFF3A2E10);

const Color kPrimaryPurple = Color(0xFF6E5A96);
const Color kPrimaryPurplePale = Color(0xFFEFEAF5);
const Color kPrimaryPurplePaleDark = Color(0xFF2A2440);

const Color kPrimaryGreen = Color(0xFF2F8F5B);
const Color kPrimaryGreenPale = Color(0xFFE5F3EB);
const Color kPrimaryGreenPaleDark = Color(0xFF123424);

const Color kPrimaryRed = Color(0xFFC1443A);

const Color kPaperLight = Color(0xFFF6F4EE);
const Color kPrimaryLight = kPaperLight;
const Color kCardLight = Color(0xFFFFFFFF);
const Color kBorderLight = Color(0xFFE7E2D6);
const Color kScaffoldLight = kPaperLight;

const Color kPaperDark = Color(0xFF101E30);
const Color kCardDark = Color(0xFF17293D);
const Color kBorderDark = Color(0xFF2A3D52);
const Color kScaffoldDark = kPaperDark;

const Color kPrimaryText = Color(0xFF142B45);
const Color kTextMainLight = kPrimaryText;
const Color kTextMainDark = Color(0xFFF5F2E8);
const Color kTextLight = Color(0xFF1C3A5E);
const Color kTextInk = Color(0xFF16212B);
const Color kTextInkSoft = Color(0xFF5B6773);
const Color kDarkInk = Color(0xFFECEFF3);
const Color kDarkSoft = Color(0xFF93A2B4);

const Color kPrimaryGrey = Color(0xFFE7E2D6);
const Color kPrimaryGreyMedium = Color(0xFF9AA3AC);
const Color kPrimaryGreyLight = Color(0xFFEEEEEC);
const Color kPrimaryGreyPaleDark = Color(0xFF22303F);

const Color kPrimaryColor = kPrimaryBlue;
const Color kPrimaryDarkColor = kPrimaryBlueDeep;
const Color kBlueColor = kPrimaryBlue;
const Color kGoldColor = kPrimaryGold;
const Color kSuccessColor = kPrimaryGreen;
const Color kErrorColor = kPrimaryRed;
const Color kWarningColor = kPrimaryGold;
const Color kRed = kPrimaryRed;
const Color kGreyMedium = kPrimaryGreyMedium;
const Color kGreyLight = kPrimaryGreyLight;
const Color kGreyBg = kPrimaryGreyLight;
const Color kBlack40 = Color(0x66000000);
const Color kTextBlue = kPrimaryBlue;
const Color kTextOrange = kPrimaryGold;
const Color kIconGrey = kPrimaryGreyMedium;
const Color kYellowBorder = kPrimaryGoldLight;

const double kBoxRadius = 18;

/// Brand constants. Screens should prefer [BocSemanticColors] via
/// `context.bocColors`; these remain for brand surfaces (the navy card) and
/// existing call sites.
class BocColors {
  static const blue = Color(0xFF4F7EB4);
  static const blueDeep = Color(0xFF3A6497);
  static const bluePale = Color(0xFFE6EDF6);
  static const navy = Color(0xFF1A2A3C);
  static const navy2 = Color(0xFF22364D);
  static const gold = Color(0xFFBF910C);

  /// Figma "Brand 2": gold on navy and gold fills. Never text on light.
  static const goldLight = Color(0xFFE5C367);
  static const goldStrong = Color(0xFF8A6A12);
  static const goldPale = Color(0xFFF2E9CE);
  static const purple = Color(0xFF6E5A96);
  static const purplePale = Color(0xFFEFEAF5);
  static const paper = Color(0xFFF6F4EE);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF16212B);
  static const inkSoft = Color(0xFF5B6773);
  static const line = Color(0xFFE7E2D6);
  static const green = Color(0xFF2F8F5B);
  static const greenPale = Color(0xFFE5F3EB);
  static const red = Color(0xFFC1443A);
  static const grey = Color(0xFF9AA3AC);
  static const greyPale = Color(0xFFEEEEEC);

  static const darkPaper = Color(0xFF101E30);
  static const darkCard = Color(0xFF17293D);
  static const darkLine = Color(0xFF2A3D52);
  static const darkInk = Color(0xFFECEFF3);
  static const darkSoft = Color(0xFF93A2B4);
}

@immutable
class BocSemanticColors extends ThemeExtension<BocSemanticColors> {
  const BocSemanticColors({
    required this.textMain,
    required this.goldPale,
    required this.bluePale,
    required this.purplePale,
    required this.greenPale,
    required this.greyPale,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textHint,
    required this.textDisabled,
    required this.onNavy,
    required this.onNavyMuted,
    required this.goldStrong,
    required this.blueStrong,
    required this.success,
    required this.successText,
    required this.successContainer,
    required this.error,
    required this.errorText,
    required this.errorContainer,
    required this.warning,
    required this.warningText,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    required this.flexAccent,
    required this.flexContainer,
    required this.smartSaveAccent,
    required this.smartSaveContainer,
    required this.fixedAccent,
    required this.fixedContainer,
    required this.padiAccent,
    required this.padiContainer,
  });

  static const light = BocSemanticColors(
    textMain: kTextMainLight,
    goldPale: kPrimaryGoldPale,
    bluePale: kPrimaryBluePale,
    purplePale: kPrimaryPurplePale,
    greenPale: kPrimaryGreenPale,
    greyPale: kPrimaryGreyLight,
    background: Color(0xFFF6F4EE),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFFBFAF6),
    border: Color(0xFFE7E2D6),
    textPrimary: Color(0xFF101924),
    textSecondary: Color(0xFF333C47),
    textTertiary: Color(0xFF5C636C),
    textHint: Color(0xFF8995A2),
    textDisabled: Color(0xFFA9B1BA),
    onNavy: Color(0xFFFFFFFF),
    onNavyMuted: Color(0xFFDCE5F0),
    goldStrong: Color(0xFF8A6A12),
    blueStrong: Color(0xFF3A6497),
    success: Color(0xFF30BE83),
    successText: Color(0xFF1E7F57),
    successContainer: Color(0xFFEAFBEF),
    error: Color(0xFFD85D57),
    errorText: Color(0xFFB3403A),
    errorContainer: Color(0xFFFDECEB),
    warning: Color(0xFFE59A1F),
    warningText: Color(0xFF8A5A00),
    warningContainer: Color(0xFFFFF7EC),
    info: Color(0xFF2F5FD0),
    infoContainer: Color(0xFFEAF0FF),
    flexAccent: Color(0xFFE5C367),
    flexContainer: Color(0xFFF2E9CE),
    smartSaveAccent: Color(0xFF4F7EB4),
    smartSaveContainer: Color(0xFFE6EDF6),
    fixedAccent: Color(0xFF6E5A96),
    fixedContainer: Color(0xFFEFEAF5),
    padiAccent: Color(0xFF30BE83),
    padiContainer: Color(0xFFEAFBEF),
  );

  static const dark = BocSemanticColors(
    textMain: kTextMainDark,
    goldPale: kPrimaryGoldPaleDark,
    bluePale: kPrimaryBluePaleDark,
    purplePale: kPrimaryPurplePaleDark,
    greenPale: kPrimaryGreenPaleDark,
    greyPale: kPrimaryGreyPaleDark,
    background: Color(0xFF101E30),
    surface: Color(0xFF17293D),
    surfaceMuted: Color(0xFF1D3348),
    border: Color(0xFF2A3D52),
    textPrimary: Color(0xFFECEFF3),
    textSecondary: Color(0xFFC3CCD6),
    textTertiary: Color(0xFF93A2B4),
    textHint: Color(0xFF6F8196),
    textDisabled: Color(0xFF4A5B6E),
    onNavy: Color(0xFFFFFFFF),
    onNavyMuted: Color(0xFFDCE5F0),
    goldStrong: Color(0xFFE5C367),
    blueStrong: Color(0xFFA9C6E8),
    success: Color(0xFF4FD39D),
    successText: Color(0xFF4FD39D),
    successContainer: Color(0xFF123424),
    error: Color(0xFFF08A84),
    errorText: Color(0xFFF08A84),
    errorContainer: Color(0xFF3A1A1A),
    warning: Color(0xFFFFC874),
    warningText: Color(0xFFFFC874),
    warningContainer: Color(0xFF3A2A10),
    info: Color(0xFF8AA8FF),
    infoContainer: Color(0xFF1A2548),
    flexAccent: Color(0xFFE5C367),
    flexContainer: Color(0xFF3A2E10),
    smartSaveAccent: Color(0xFF8FB3DD),
    smartSaveContainer: Color(0xFF1D3348),
    fixedAccent: Color(0xFFB9A8DC),
    fixedContainer: Color(0xFF2A2440),
    padiAccent: Color(0xFF4FD39D),
    padiContainer: Color(0xFF123424),
  );

  /// Raises faint text to [textSecondary] and darkens hairlines for the High
  /// contrast preference.
  BocSemanticColors highContrast() => copyWith(
    textTertiary: textSecondary,
    textHint: textSecondary,
    border: textTertiary,
  );

  final Color textMain;
  final Color goldPale;
  final Color bluePale;
  final Color purplePale;
  final Color greenPale;
  final Color greyPale;

  /// Scaffold.
  final Color background;

  /// Cards, grouped lists, fields and sheets.
  final Color surface;

  /// Secondary buttons, keypad keys, unselected chips.
  final Color surfaceMuted;

  /// Hairlines, dividers and idle field borders.
  final Color border;
  final Color textPrimary;

  /// Body copy.
  final Color textSecondary;

  /// Helper text, subtitles and inactive labels.
  final Color textTertiary;

  /// Placeholders only; too faint for helper or error text.
  final Color textHint;
  final Color textDisabled;

  /// Text on the navy wallet card.
  final Color onNavy;
  final Color onNavyMuted;

  /// The only gold allowed as text or icons on light surfaces.
  final Color goldStrong;

  /// Small link text.
  final Color blueStrong;

  /// Success icons and badges.
  final Color success;

  /// Credit amounts and success copy.
  final Color successText;
  final Color successContainer;

  /// Error icons and borders.
  final Color error;

  /// Field errors and destructive labels.
  final Color errorText;
  final Color errorContainer;
  final Color warning;

  /// Pending and weak-password labels.
  final Color warningText;
  final Color warningContainer;
  final Color info;
  final Color infoContainer;

  /// Boc Flex Savings.
  final Color flexAccent;
  final Color flexContainer;

  /// Boc SmartSave.
  final Color smartSaveAccent;
  final Color smartSaveContainer;

  /// Boc Fixed Deposit.
  final Color fixedAccent;
  final Color fixedContainer;

  /// Boc Padi.
  final Color padiAccent;
  final Color padiContainer;

  @override
  BocSemanticColors copyWith({
    Color? textMain,
    Color? goldPale,
    Color? bluePale,
    Color? purplePale,
    Color? greenPale,
    Color? greyPale,
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textHint,
    Color? textDisabled,
    Color? onNavy,
    Color? onNavyMuted,
    Color? goldStrong,
    Color? blueStrong,
    Color? success,
    Color? successText,
    Color? successContainer,
    Color? error,
    Color? errorText,
    Color? errorContainer,
    Color? warning,
    Color? warningText,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
    Color? flexAccent,
    Color? flexContainer,
    Color? smartSaveAccent,
    Color? smartSaveContainer,
    Color? fixedAccent,
    Color? fixedContainer,
    Color? padiAccent,
    Color? padiContainer,
  }) {
    return BocSemanticColors(
      textMain: textMain ?? this.textMain,
      goldPale: goldPale ?? this.goldPale,
      bluePale: bluePale ?? this.bluePale,
      purplePale: purplePale ?? this.purplePale,
      greenPale: greenPale ?? this.greenPale,
      greyPale: greyPale ?? this.greyPale,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textHint: textHint ?? this.textHint,
      textDisabled: textDisabled ?? this.textDisabled,
      onNavy: onNavy ?? this.onNavy,
      onNavyMuted: onNavyMuted ?? this.onNavyMuted,
      goldStrong: goldStrong ?? this.goldStrong,
      blueStrong: blueStrong ?? this.blueStrong,
      success: success ?? this.success,
      successText: successText ?? this.successText,
      successContainer: successContainer ?? this.successContainer,
      error: error ?? this.error,
      errorText: errorText ?? this.errorText,
      errorContainer: errorContainer ?? this.errorContainer,
      warning: warning ?? this.warning,
      warningText: warningText ?? this.warningText,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      flexAccent: flexAccent ?? this.flexAccent,
      flexContainer: flexContainer ?? this.flexContainer,
      smartSaveAccent: smartSaveAccent ?? this.smartSaveAccent,
      smartSaveContainer: smartSaveContainer ?? this.smartSaveContainer,
      fixedAccent: fixedAccent ?? this.fixedAccent,
      fixedContainer: fixedContainer ?? this.fixedContainer,
      padiAccent: padiAccent ?? this.padiAccent,
      padiContainer: padiContainer ?? this.padiContainer,
    );
  }

  @override
  BocSemanticColors lerp(covariant BocSemanticColors? other, double t) {
    if (other == null) return this;
    return BocSemanticColors(
      textMain: Color.lerp(textMain, other.textMain, t)!,
      goldPale: Color.lerp(goldPale, other.goldPale, t)!,
      bluePale: Color.lerp(bluePale, other.bluePale, t)!,
      purplePale: Color.lerp(purplePale, other.purplePale, t)!,
      greenPale: Color.lerp(greenPale, other.greenPale, t)!,
      greyPale: Color.lerp(greyPale, other.greyPale, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      onNavy: Color.lerp(onNavy, other.onNavy, t)!,
      onNavyMuted: Color.lerp(onNavyMuted, other.onNavyMuted, t)!,
      goldStrong: Color.lerp(goldStrong, other.goldStrong, t)!,
      blueStrong: Color.lerp(blueStrong, other.blueStrong, t)!,
      success: Color.lerp(success, other.success, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      error: Color.lerp(error, other.error, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      flexAccent: Color.lerp(flexAccent, other.flexAccent, t)!,
      flexContainer: Color.lerp(flexContainer, other.flexContainer, t)!,
      smartSaveAccent: Color.lerp(smartSaveAccent, other.smartSaveAccent, t)!,
      smartSaveContainer: Color.lerp(
        smartSaveContainer,
        other.smartSaveContainer,
        t,
      )!,
      fixedAccent: Color.lerp(fixedAccent, other.fixedAccent, t)!,
      fixedContainer: Color.lerp(fixedContainer, other.fixedContainer, t)!,
      padiAccent: Color.lerp(padiAccent, other.padiAccent, t)!,
      padiContainer: Color.lerp(padiContainer, other.padiContainer, t)!,
    );
  }
}

extension BocThemeContext on BuildContext {
  /// The app's semantic colours; falls back to the default palette for the
  /// current brightness when a widget is hosted outside the Boc theme.
  BocSemanticColors get bocColors {
    final theme = Theme.of(this);
    return theme.extension<BocSemanticColors>() ??
        (theme.brightness == Brightness.dark
            ? BocSemanticColors.dark
            : BocSemanticColors.light);
  }
}
