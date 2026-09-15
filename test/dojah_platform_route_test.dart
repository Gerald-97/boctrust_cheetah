import 'package:boctrust_savings_loan/module/kyc/service/dojah_platform_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS chooses the embedded browser', () {
    expect(
      chooseDojahPlatformRoute(isWeb: false, isAndroid: false, isIOS: true),
      DojahPlatformRoute.iosWebView,
    );
  });

  test('Android keeps the native SDK', () {
    expect(
      chooseDojahPlatformRoute(isWeb: false, isAndroid: true, isIOS: false),
      DojahPlatformRoute.nativeAndroid,
    );
  });

  test('other platforms are unsupported', () {
    expect(
      chooseDojahPlatformRoute(isWeb: true, isAndroid: false, isIOS: false),
      DojahPlatformRoute.unsupported,
    );
  });
}
