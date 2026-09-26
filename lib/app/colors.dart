import 'package:flutter/material.dart';

const kFontFamily = 'PlusJakartaSans';

/// Figures only: balances, amounts, limits and account numbers.
const kFigureFontFamily = 'FHOscar';

const Color kPrimaryBlue = Color(0xFF4F7EB4);
const Color kPrimaryBlueDeep = Color(0xFF3A6497);
const Color kPrimaryBluePale = Color(0xFFE9F0F7);
const Color kPrimaryBluePaleDark = Color(0xFF1D3348);

const Color kPrimaryGold = Color(0xFFBF910C);
const Color kPrimaryGoldLight = Color(0xFFE7C567);
const Color kPrimaryGoldPale = Color(0xFFF3E6BE);
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

class BocColors {
  static const blue = Color(0xFF4F7EB4);
  static const blueDeep = Color(0xFF3A6497);
  static const bluePale = Color(0xFFE9F0F7);
  static const navy = Color(0xFF142B45);
  static const navy2 = Color(0xFF1C3A5E);
  static const gold = Color(0xFFBF910C);
  static const goldLight = Color(0xFFE7C567);
  static const goldPale = Color(0xFFF3E6BE);
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
  });

  static const light = BocSemanticColors(
    textMain: kTextMainLight,
    goldPale: kPrimaryGoldPale,
    bluePale: kPrimaryBluePale,
    purplePale: kPrimaryPurplePale,
    greenPale: kPrimaryGreenPale,
    greyPale: kPrimaryGreyLight,
  );

  static const dark = BocSemanticColors(
    textMain: kTextMainDark,
    goldPale: kPrimaryGoldPaleDark,
    bluePale: kPrimaryBluePaleDark,
    purplePale: kPrimaryPurplePaleDark,
    greenPale: kPrimaryGreenPaleDark,
    greyPale: kPrimaryGreyPaleDark,
  );

  final Color textMain;
  final Color goldPale;
  final Color bluePale;
  final Color purplePale;
  final Color greenPale;
  final Color greyPale;

  @override
  BocSemanticColors copyWith({
    Color? textMain,
    Color? goldPale,
    Color? bluePale,
    Color? purplePale,
    Color? greenPale,
    Color? greyPale,
  }) {
    return BocSemanticColors(
      textMain: textMain ?? this.textMain,
      goldPale: goldPale ?? this.goldPale,
      bluePale: bluePale ?? this.bluePale,
      purplePale: purplePale ?? this.purplePale,
      greenPale: greenPale ?? this.greenPale,
      greyPale: greyPale ?? this.greyPale,
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
    );
  }
}

extension BocThemeContext on BuildContext {
  BocSemanticColors get bocColors =>
      Theme.of(this).extension<BocSemanticColors>()!;
}
