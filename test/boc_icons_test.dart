import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:boctrust_savings_loan/app/boc_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 240.0;

/// Renders [child] in a [_size] square and returns which pixels are inked.
Future<List<bool>> _mask(WidgetTester tester, Widget child) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox.square(dimension: _size, child: child),
        ),
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
  late ByteData bytes;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  return [
    for (var i = 3; i < bytes.lengthInBytes; i += 4) bytes.getUint8(i) > 127,
  ];
}

double _overlap(List<bool> a, List<bool> b) {
  var both = 0, either = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] && b[i]) both++;
    if (a[i] || b[i]) either++;
  }
  return both / either;
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('BocIcons')
      ..addFont(
        Future.value(
          File(
            'assets/font/BocIcons.ttf',
          ).readAsBytesSync().buffer.asByteData(),
        ),
      );
    await loader.load();
  });

  for (final (name, icon, asset) in [
    ('savings', BocIcons.savings, 'save_linear'),
    ('savingsBold', BocIcons.savingsBold, 'save_bold'),
  ]) {
    testWidgets('BocIcons.$name draws the nav $asset piggy', (tester) async {
      const black = Color(0xFF000000);
      final glyph = await _mask(tester, Icon(icon, size: _size, color: black));
      final svg = await _mask(
        tester,
        SvgPicture.asset(
          'assets/svg/nav/$asset.svg',
          colorFilter: const ColorFilter.mode(black, BlendMode.srcIn),
        ),
      );
      expect(svg.where((p) => p).length, greaterThan(1000));
      expect(_overlap(glyph, svg), greaterThan(0.9));
    });
  }

  test('the BocIcons font is declared and savings use the nav piggy', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: BocIcons'));
    expect(pubspec, contains('asset: assets/font/BocIcons.ttf'));
    final strongbox = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            file.readAsStringSync().contains('strongbox'))
          file.path,
    ];
    expect(strongbox, isEmpty);
  });
}
