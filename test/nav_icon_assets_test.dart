import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _tabs = ['home', 'save', 'send', 'pay', 'account'];
const _states = ['linear', 'bold'];

void main() {
  group('bottom nav icons', () {
    for (final tab in _tabs) {
      for (final state in _states) {
        final path = 'assets/svg/nav/${tab}_$state.svg';

        test('$path is a 24px single-colour SVG', () {
          final file = File(path);
          expect(file.existsSync(), isTrue, reason: '$path must exist');
          final svg = file.readAsStringSync();
          expect(svg, contains('viewBox="0 0 24 24"'));
          // The nav tints icons with BlendMode.srcIn, which is only lossless
          // when the artwork uses a single colour.
          final colours = RegExp(
            r'#[0-9A-Fa-f]{6}',
          ).allMatches(svg).map((m) => m.group(0)!.toUpperCase()).toSet();
          expect(colours, hasLength(1), reason: '$path colours: $colours');
        });
      }
    }

    test('the nav icon folder is a declared asset', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/svg/nav/'),
      );
    });

    test('save_bold is fitted to the save_linear footprint', () {
      // The tdesign filled pot is drawn edge to edge; unscaled it looks bigger
      // than, and offset from, the outline when the tab becomes active.
      expect(
        File('assets/svg/nav/save_bold.svg').readAsStringSync(),
        contains('transform="translate(1.4 1.3) scale(0.883)"'),
      );
    });
  });
}
