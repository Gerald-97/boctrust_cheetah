import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Each slide's character region (left, top, right, bottom), which must not
/// move: only the floating motifs around it animate.
const _characters = {
  'save': (185, 235, 425, 425),
  'goals': (175, 265, 445, 500),
  'pay': (220, 280, 370, 480),
};

int _difference(img.Image a, img.Image b) {
  var sum = 0;
  for (final p in a) {
    final q = b.getPixel(p.x, p.y);
    sum += ((p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs()).toInt();
  }
  return sum;
}

void main() {
  for (final MapEntry(key: slide, value: (l, t, r, b)) in _characters.entries) {
    test(
      '$slide onboarding art is a smooth 600x600 1920ms loop with a still',
      () {
        final gif = img.decodeGif(
          File('assets/img/onboarding/$slide.gif').readAsBytesSync(),
        )!;
        final frames = gif.frames;
        expect(frames.length, greaterThanOrEqualTo(40));
        expect(frames.every((f) => f.frameDuration <= 80), isTrue);
        expect(frames.fold<int>(0, (sum, f) => sum + f.frameDuration), 1920);
        expect([gif.width, gif.height], [600, 600]);

        img.Image character(img.Image f) =>
            img.copyCrop(f, x: l, y: t, width: r - l, height: b - t);
        final still = character(frames.first);
        for (final frame in frames) {
          expect(_difference(character(frame), still), 0);
        }

        final steps = [
          for (var i = 1; i < frames.length; i++)
            _difference(frames[i - 1], frames[i]),
        ];
        final wrap = _difference(frames.last, frames.first);
        expect(wrap, lessThanOrEqualTo(steps.reduce((a, b) => a > b ? a : b)));

        final png = img.decodePng(
          File('assets/img/onboarding/$slide-still.png').readAsBytesSync(),
        )!;
        expect([png.width, png.height], [600, 600]);
      },
    );
  }

  test('onboarding asset directory is declared in pubspec', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/img/onboarding/'),
    );
  });
}
