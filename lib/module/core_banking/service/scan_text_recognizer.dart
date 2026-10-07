import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/scan_text_models.dart';

final scanTextRecognizerProvider = Provider<ScanTextRecognizer>(
  (ref) => const ChannelScanTextRecognizer(),
);

/// Reads the lines of text on a photo. Nothing leaves the phone.
abstract interface class ScanTextRecognizer {
  Future<List<RecognizedLine>> recognize(String imagePath);
}

/// A recognition failure whose message never contains the image path.
class ScanRecognitionFailure implements Exception {
  const ScanRecognitionFailure(this.message);
  final String message;

  @override
  String toString() => 'ScanRecognitionFailure: $message';
}

/// [ScanTextRecognizer] backed by ML Kit on Android and Vision on iOS through
/// the `boctrust/scan_text` channel. Each line comes back with a box in the
/// [ScanTextBox] contract; a line whose box falls outside the image is dropped.
class ChannelScanTextRecognizer implements ScanTextRecognizer {
  const ChannelScanTextRecognizer();

  static const _channel = MethodChannel('boctrust/scan_text');

  @override
  Future<List<RecognizedLine>> recognize(String imagePath) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw const ScanRecognitionFailure(
        'Scanning is not available on this device.',
      );
    }
    final List<Object?>? result;
    try {
      result = await _channel.invokeListMethod<Object?>('recognizeImage', {
        'path': imagePath,
      });
    } on PlatformException catch (e) {
      // The native message may name the file, so only the code is kept.
      throw ScanRecognitionFailure('Text recognition failed (${e.code}).');
    } on MissingPluginException {
      throw const ScanRecognitionFailure(
        'Scanning is not available on this device.',
      );
    }
    return [for (final item in result ?? const <Object?>[]) ?_decodeLine(item)];
  }
}

// Allows for rounding when native code divides pixel edges by image size.
const _edge = 1 + 1e-6;

RecognizedLine? _decodeLine(Object? item) {
  if (item is! Map) return null;
  final text = item['text'];
  final left = _unit(item['left']);
  final top = _unit(item['top']);
  final width = _unit(item['width']);
  final height = _unit(item['height']);
  if (text is! String ||
      left == null ||
      top == null ||
      width == null ||
      height == null ||
      left + width > _edge ||
      top + height > _edge) {
    return null;
  }
  return RecognizedLine(
    text,
    ScanTextBox(left: left, top: top, width: width, height: height),
  );
}

double? _unit(Object? value) {
  if (value is! num) return null;
  final v = value.toDouble();
  return v >= 0 && v <= 1 ? v : null;
}
