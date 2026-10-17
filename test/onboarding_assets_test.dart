import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  for (final slide in ['save', 'goals', 'pay']) {
    test('$slide onboarding art is a 600x600 1920ms loop with a still', () {
      final gif = img.decodeGif(
        File('assets/img/onboarding/$slide.gif').readAsBytesSync(),
      )!;
      expect(gif.frames.length, greaterThan(1));
      expect(
        gif.frames.fold<int>(0, (sum, f) => sum + f.frameDuration),
        1920,
      );
      expect([gif.width, gif.height], [600, 600]);

      final still = img.decodePng(
        File('assets/img/onboarding/$slide-still.png').readAsBytesSync(),
      )!;
      expect([still.width, still.height], [600, 600]);
    });
  }

  test('onboarding asset directory is declared in pubspec', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/img/onboarding/'),
    );
  });
}
