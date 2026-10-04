import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Material icons with no fitting Vuesax/Iconsax counterpart.
const _allowedMaterialIcons = {
  // A plain X; Iconsax only has circled or squared variants, and the Figma
  // close button is a plain X too.
  'Icons.close_rounded',
  // A bare tick inside an already-round badge; Iconsax ticks are circled.
  'Icons.check_rounded',
  // A small status dot, not a pictogram.
  'Icons.circle',
  // The universal accessibility symbol.
  'Icons.accessibility_new_rounded',
};

void main() {
  test('app icons use the Vuesax set the bottom nav uses', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final match in RegExp(
          r'\bIcons\.[a-z_0-9]+',
        ).allMatches(lines[i])) {
          if (!_allowedMaterialIcons.contains(match.group(0))) {
            offenders.add('${file.path}:${i + 1} ${match.group(0)}');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
