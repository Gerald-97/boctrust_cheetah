import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../app/core_api_endpoints.dart';
import '../../../app/core_network.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/core_json.dart';

/// Core's documented upload limit for a snap-to-pay photo.
const kSnapImageMaxBytes = 8 * 1024 * 1024;

/// A photo cut down for snap-to-pay: upright, grayscale, at most 1000 px
/// wide, JPEG quality 75. With [cropToFrame] (a viewfinder capture) only the
/// centre band around the on-screen frame is kept: 92% of the width, 35% of
/// the height. A photo from elsewhere has no frame and is kept whole.
///
/// Staging slows sharply with upload size: a 38 KB photo answered in 2.4 s,
/// a 645 KB one timed out after 30 s and 1.5 MB was rejected with 413. Run it
/// off the UI thread (`compute`). Unreadable bytes are returned unchanged.
Uint8List shrinkForSnap(Uint8List photo, {bool cropToFrame = true}) {
  final decoded = img.decodeImage(photo);
  if (decoded == null) return photo;
  final upright = img.bakeOrientation(decoded);
  final width = (upright.width * 0.92).round();
  final height = (upright.height * 0.35).round();
  var band = cropToFrame
      ? img.copyCrop(
          upright,
          x: (upright.width - width) ~/ 2,
          y: (upright.height - height) ~/ 2,
          width: width,
          height: height,
        )
      : upright;
  band = img.grayscale(band);
  if (band.width > 1000) band = img.copyResize(band, width: 1000);
  return img.encodeJpg(band, quality: 75);
}

/// [shrinkForSnap] for a photo without a frame, in a form `compute` takes.
Uint8List shrinkWholeForSnap(Uint8List photo) =>
    shrinkForSnap(photo, cropToFrame: false);

final coreOcrServiceProvider = Provider<CoreOcrService>(
  (ref) => CoreOcrService(ref.watch(coreApiServiceProvider)),
);

/// Reads a number from a photo through `POST /me/snap-to-pay`. The result is
/// only a suggestion for a field; it never starts a payment.
class CoreOcrService {
  const CoreOcrService(this._api);
  final ApiService? _api;

  Future<NotifierState<String>> readNumber(Uint8List image) async {
    final api = _api;
    if (api == null) {
      return const NotifierState.blocked(
        'Scanning is not available right now.',
      );
    }
    if (image.length > kSnapImageMaxBytes) {
      return const NotifierState.error(
        'This photo is too large. Try again closer to the number.',
      );
    }
    final result = NotifierState.fromResponse(
      await api.postData<String>(
        CoreApiEndpoints.snapToPay,
        data: {'image': base64Encode(image)},
        parser: (json) =>
            (json is Map ? coreText(json['number']) : null) ??
            (throw const FormatException('Missing number.')),
      ),
    );
    return switch (result.statusCode) {
      400 => const NotifierState.error(
        "We couldn't find a number in that photo.",
      ),
      413 => const NotifierState.error(
        'This photo is too large. Try again closer to the number.',
      ),
      _ => result,
    };
  }
}
