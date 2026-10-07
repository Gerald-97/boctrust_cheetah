import 'package:boctrust_savings_loan/module/core_banking/model/scan_text_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/scan_text_recognizer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('boctrust/scan_text');
const _path = '/private/photos/slip.jpg';

void _answer(Future<Object?> Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'lines decode with their boxes; out-of-range boxes are dropped',
    () async {
      MethodCall? received;
      _answer((call) async {
        received = call;
        return [
          {
            'text': 'Access Bank',
            'left': 0.1,
            'top': 0.2,
            'width': 0.5,
            'height': 0.05,
          },
          {
            'text': '0123456789',
            'left': 0.1,
            'top': 0.3,
            'width': 0.4,
            'height': 0.05,
          },
          {
            'text': 'Off image',
            'left': 0.8,
            'top': 0.4,
            'width': 0.3,
            'height': 0.05,
          },
        ];
      });

      final lines = await const ChannelScanTextRecognizer().recognize(_path);

      expect(received?.method, 'recognizeImage');
      expect(received?.arguments, {'path': _path});
      expect(lines, const [
        RecognizedLine(
          'Access Bank',
          ScanTextBox(left: 0.1, top: 0.2, width: 0.5, height: 0.05),
        ),
        RecognizedLine(
          '0123456789',
          ScanTextBox(left: 0.1, top: 0.3, width: 0.4, height: 0.05),
        ),
      ]);
    },
  );

  test('a native error becomes a failure without the image path', () async {
    _answer(
      (_) async => throw PlatformException(
        code: 'recognition_failed',
        message: 'Could not read $_path',
      ),
    );

    final failure = await const ChannelScanTextRecognizer()
        .recognize(_path)
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect(failure, isA<ScanRecognitionFailure>());
    expect(failure.toString(), isNot(contains(_path)));
  });
}
