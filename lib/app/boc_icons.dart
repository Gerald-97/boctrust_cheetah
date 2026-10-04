import 'package:flutter/widgets.dart';

/// App icons with no Vuesax counterpart, packed into `assets/font/BocIcons.ttf`
/// by `tool/icons/build_boc_icons.py`. Codepoints match that script.
abstract final class BocIcons {
  /// The bottom nav's Save piggy, outlined.
  static const savings = IconData(0xE000, fontFamily: 'BocIcons');

  /// The bottom nav's Save piggy, filled.
  static const savingsBold = IconData(0xE001, fontFamily: 'BocIcons');
}
