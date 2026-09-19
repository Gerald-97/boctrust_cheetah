import 'package:boctrust_savings_loan/module/kyc/service/dojah_camera_permission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android must hold the camera permission itself', () {
    // Android's WebView can only satisfy getUserMedia while the host app
    // holds runtime CAMERA; granting the page's request is not enough.
    expect(dojahNeedsCameraPermission(isAndroid: true), isTrue);
  });

  test('iOS leaves the prompt to WKWebView', () {
    // WKWebView prompts on its own behalf from the Info.plist usage
    // descriptions, so requesting again would ask twice.
    expect(dojahNeedsCameraPermission(isAndroid: false), isFalse);
  });

  test('a platform that needs nothing proceeds without asking', () async {
    expect(await requestDojahCameraPermission(isAndroid: false), isTrue);
  });
}
