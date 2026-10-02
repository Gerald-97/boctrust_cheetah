import 'package:boctrust_savings_loan/module/kyc/model/kyc_provider_models.dart';
import 'package:boctrust_savings_loan/module/kyc/service/dojah_platform_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS chooses the embedded browser', () {
    expect(
      chooseDojahPlatformRoute(isWeb: false, isAndroid: false, isIOS: true),
      DojahPlatformRoute.webView,
    );
  });

  test('Android runs BVN liveness natively and documents in the browser', () {
    // The native Android SDK (sdk-kotlin v0.4.2) throws "No stepNumber" from
    // its own coroutine when the user navigates back on the document pages,
    // which kills the host process, so only the document flow stays hosted.
    final route = chooseDojahPlatformRoute(
      isWeb: false,
      isAndroid: true,
      isIOS: false,
    );
    expect(
      dojahCaptureMode(route, KycOperation.identity),
      DojahCaptureMode.nativeSdk,
    );
    expect(
      dojahCaptureMode(route, KycOperation.governmentId),
      DojahCaptureMode.webView,
    );
  });

  test('other platforms are unsupported', () {
    expect(
      chooseDojahPlatformRoute(isWeb: true, isAndroid: false, isIOS: false),
      DojahPlatformRoute.unsupported,
    );
  });
}
