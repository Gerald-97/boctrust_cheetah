import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core_api_endpoints.dart';
import '../../../app/core_network.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/core_json.dart';

/// Core's documented upload limit for a snap-to-pay photo.
const kSnapImageMaxBytes = 8 * 1024 * 1024;

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
    return result.statusCode == 400
        ? const NotifierState.error("We couldn't find a number in that photo.")
        : result;
  }
}
