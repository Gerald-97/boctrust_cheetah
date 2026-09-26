import 'package:flutter/animation.dart';

/// 4-pt spacing scale. Screens use these instead of raw paddings.
abstract final class BocSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  /// Page side padding.
  static const gutter = md;

  /// Gap between page sections.
  static const sectionGap = lg;
  static const cardPadding = md;

  /// Minimum tappable size on every control.
  static const minTouch = 48.0;
}

abstract final class BocRadius {
  /// OTP and PIN cells, small tags.
  static const xs = 8.0;

  /// Buttons, fields, keypad keys, segmented controls.
  static const sm = 12.0;

  /// Cards, the wallet card and grouped lists.
  static const md = 16.0;

  /// Bottom-sheet top corners.
  static const lg = 24.0;
  static const pill = 999.0;
}

abstract final class BocMotion {
  /// Toggles and chips.
  static const fast = Duration(milliseconds: 150);

  /// Pages and sheets.
  static const normal = Duration(milliseconds: 250);
  static const curve = Curves.easeOutCubic;
}
