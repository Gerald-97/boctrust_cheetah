// Renders the native splash's "Cheetah / by BocTrust" branding image with
// the app's own font, so the launch screen needs no image tools.
//
// Run from the repository root:
//   flutter test tool/branding/render_splash_branding.dart
// then regenerate the native splash:
//   dart run flutter_native_splash:create --path flutter_native_splash.yaml
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// flutter_native_splash treats branding as a 4x image: 200 x 80 dp.
const _width = 800.0;
const _height = 320.0;

Future<void> _loadFont(String family, Map<int, String> files) async {
  final loader = FontLoader(family);
  for (final file in files.values) {
    final bytes = File(file).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

ui.Paragraph _line(String text, double size, ui.FontWeight weight, int alpha) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: TextAlign.left,
            fontFamily: 'PlusJakartaSans',
          ),
        )
        ..pushStyle(
          ui.TextStyle(
            color: Color.fromARGB(alpha, 255, 255, 255),
            fontSize: size,
            fontWeight: weight,
            fontFamily: 'PlusJakartaSans',
          ),
        )
        ..addText(text);
  return builder.build()..layout(const ui.ParagraphConstraints(width: _width));
}

void main() {
  test('render splash branding', () async {
    await _loadFont('PlusJakartaSans', {
      800: 'assets/font/PlusJakartaSans-ExtraBold.ttf',
      500: 'assets/font/PlusJakartaSans-Medium.ttf',
    });
    final name = _line('Cheetah', 136, ui.FontWeight.w800, 255);
    final tagline = _line('by BocTrust', 60, ui.FontWeight.w500, 190);
    const gap = 12.0;
    final top = (_height - name.height - gap - tagline.height) / 2;

    // --dart-define=PREVIEW=path draws the splash colour behind the text
    // and writes there instead, to check it by eye.
    const preview = String.fromEnvironment('PREVIEW');
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    if (preview.isNotEmpty) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, _width, _height),
        ui.Paint()..color = const Color(0xFF101E30),
      );
    }
    // The name is centred; the tagline sits under it, flush with its right
    // edge.
    final nameLeft = (_width - name.longestLine) / 2;
    final nameRight = nameLeft + name.longestLine;
    canvas
      ..drawParagraph(name, Offset(nameLeft, top))
      ..drawParagraph(
        tagline,
        Offset(nameRight - tagline.longestLine, top + name.height + gap),
      );
    final image = await recorder.endRecording().toImage(
      _width.toInt(),
      _height.toInt(),
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      preview.isNotEmpty
          ? preview
          : 'assets/branding/generated/cheetah_splash_branding.png',
    ).writeAsBytesSync(png!.buffer.asUint8List());
  });
}
