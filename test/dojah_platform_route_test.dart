import 'package:boctrust_savings_loan/module/kyc/service/dojah_platform_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS chooses the embedded browser', () {
    expect(
      chooseDojahPlatformRoute(isWeb: false, isAndroid: false, isIOS: true),
      DojahPlatformRoute.webView,
    );
  });

  test('Android chooses the embedded browser too', () {
    // The native Android SDK (sdk-kotlin v0.4.2) throws "No stepNumber" from
    // its own coroutine when the user navigates back on the document pages,
    // which kills the host process. The hosted flow cannot do that.
    expect(
      chooseDojahPlatformRoute(isWeb: false, isAndroid: true, isIOS: false),
      DojahPlatformRoute.webView,
    );
  });

  test('other platforms are unsupported', () {
    expect(
      chooseDojahPlatformRoute(isWeb: true, isAndroid: false, isIOS: false),
      DojahPlatformRoute.unsupported,
    );
  });
}
