import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _pngPath = 'assets/branding/cheetah_app_icon.png';
const _svgPath = 'assets/branding/cheetah_app_icon.svg';
const _opaquePath = 'assets/branding/generated/cheetah_app_icon_opaque.png';
const _adaptivePath =
    'assets/branding/generated/cheetah_adaptive_foreground.png';
const _splashPath = 'assets/branding/generated/cheetah_splash.png';
const _splash12Path = 'assets/branding/generated/cheetah_splash_android12.png';

const _pngSha256 =
    '3d1d6b7f77b86b7229172712379ce4d6c52940d6e419d978b9aa5dcb13893031';
const _svgSha256 =
    '218adb469c70704715f6e26ff8c62a0c187e6ddd58129f8af1cb8921f8948773';

img.Image _decode(String path) {
  final image = img.decodePng(File(path).readAsBytesSync());
  expect(image, isNotNull, reason: '$path must be a valid PNG');
  return image!;
}

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

bool _isBlue(img.Pixel p) =>
    p.a > 0 && p.b > p.r + 40 && p.b > 140 && p.r < 200;

void main() {
  group('approved sources', () {
    test('PNG is the approved byte-identical 2032x2032 RGBA master', () {
      expect(_sha256(_pngPath), _pngSha256);
      final png = _decode(_pngPath);
      expect(png.width, 2032);
      expect(png.height, 2032);
      expect(png.numChannels, 4);
      // Rounded corners are transparent; the field is the approved blue.
      expect(png.getPixel(0, 0).a, 0);
      final field = png.getPixel(100, 100);
      expect([field.r, field.g, field.b, field.a], [0x4F, 0x7E, 0xB4, 255]);
    });

    test('SVG is the approved byte-identical 508x508 artwork', () {
      expect(_sha256(_svgPath), _svgSha256);
      final svg = File(_svgPath).readAsStringSync();
      expect(svg, contains('viewBox="0 0 508 508"'));
      expect(svg, contains('fill="#4F7EB4"'));
      expect(svg, contains('fill="white"'));
      expect(svg, isNot(contains('<text')));
    });
  });

  group('generated derivatives', () {
    test('opaque launcher master has no transparency and blue corners', () {
      final opaque = _decode(_opaquePath);
      expect(opaque.width, 2032);
      expect(opaque.height, 2032);
      expect(opaque.numChannels, 3, reason: 'iOS icons must have no alpha');
      final corner = opaque.getPixel(0, 0);
      expect([corner.r, corner.g, corner.b], [0x4F, 0x7E, 0xB4]);
      // The diagonal crosses the anti-aliased corner ring (radius 320 px);
      // compositing leaves it the solid field colour, with no halo.
      for (var i = 0; i < 200; i++) {
        final p = opaque.getPixel(i, i);
        expect((p.r - 0x4F).abs(), lessThanOrEqualTo(2), reason: 'at $i,$i');
        expect((p.g - 0x7E).abs(), lessThanOrEqualTo(2), reason: 'at $i,$i');
        expect((p.b - 0xB4).abs(), lessThanOrEqualTo(2), reason: 'at $i,$i');
      }
    });

    test('adaptive foreground maps the frame onto the 72dp viewport', () {
      final fg = _decode(_adaptivePath);
      expect(fg.width, 1024);
      expect(fg.height, 1024);
      expect(fg.numChannels, 4);
      const viewport = 1024 * 2 / 3;
      const start = (1024 - viewport) / 2;
      const end = start + viewport;
      var whiteAtLeftEdge = 0;
      for (final p in fg) {
        if (p.a == 0) continue;
        expect(_isBlue(p), isFalse, reason: 'no blue field at ${p.x},${p.y}');
        expect(
          p.r > 240 && p.g > 240 && p.b > 240,
          isTrue,
          reason: 'only white silhouette pixels at ${p.x},${p.y}',
        );
        expect(
          p.x >= start.floor() && p.x <= end.ceil(),
          isTrue,
          reason: 'pixel outside viewport at ${p.x},${p.y}',
        );
        expect(
          p.y >= start.floor() && p.y <= end.ceil(),
          isTrue,
          reason: 'pixel outside viewport at ${p.x},${p.y}',
        );
        if (p.x <= start.ceil() && p.a > 200) whiteAtLeftEdge++;
      }
      // The bleed meets the mask edge rather than being padded inward.
      expect(whiteAtLeftEdge, greaterThan(20));
    });

    test('splash raster is the complete icon centered with padding', () {
      final splash = _decode(_splashPath);
      expect(splash.width, splash.height);
      expect(splash.numChannels, 4);
      final bounds = _opaqueBounds(splash);
      final size = splash.width;
      expect(bounds.left, greaterThan(size * .1));
      expect(bounds.top, greaterThan(size * .1));
      expect(size - 1 - bounds.right, closeTo(bounds.left, 2));
      expect(size - 1 - bounds.bottom, closeTo(bounds.top, 2));
      final centre = splash.getPixel(size ~/ 2, bounds.top + 40);
      expect(_isBlue(centre), isTrue, reason: 'blue field preserved');
    });

    test('Android 12 splash icon fits inside the circular splash mask', () {
      final splash = _decode(_splash12Path);
      expect(splash.width, 1152);
      expect(splash.height, 1152);
      expect(splash.numChannels, 4);
      const radius = 768 / 2;
      const centre = 1152 / 2;
      var visible = 0;
      for (final p in splash) {
        if (p.a == 0) continue;
        visible++;
        final dx = p.x + .5 - centre;
        final dy = p.y + .5 - centre;
        expect(
          math.sqrt(dx * dx + dy * dy),
          lessThanOrEqualTo(radius),
          reason: 'pixel outside splash circle at ${p.x},${p.y}',
        );
      }
      expect(visible, greaterThan(200000));
    });
  });

  test('only the SVG brand mark is bundled from assets/branding', () {
    final assets = File('pubspec.yaml')
        .readAsLinesSync()
        .map((line) => line.trim())
        .where((line) => line.startsWith('- assets/branding'))
        .toList();
    expect(assets, ['- assets/branding/cheetah_app_icon.svg']);
  });
}

({int left, int top, int right, int bottom}) _opaqueBounds(img.Image image) {
  var left = image.width, top = image.height, right = -1, bottom = -1;
  for (final p in image) {
    if (p.a == 0) continue;
    left = math.min(left, p.x);
    right = math.max(right, p.x);
    top = math.min(top, p.y);
    bottom = math.max(bottom, p.y);
  }
  return (left: left, top: top, right: right, bottom: bottom);
}
