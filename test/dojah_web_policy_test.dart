import 'package:boctrust_savings_loan/module/kyc/service/dojah_web_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  group('buildDojahIdentityUri', () {
    test('opens the hosted identity flow with the reference as metadata', () {
      final uri = buildDojahIdentityUri(
        widgetId: ' selfie-widget ',
        referenceId: 'boc attempt&1+',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'identity.dojah.io');
      // `reference_id` would resume an existing Dojah session rather than
      // start one for this attempt.
      expect(uri.queryParametersAll, {
        'widget_id': ['selfie-widget'],
        'metadata[reference]': ['boc attempt&1+'],
        'loading': ['async'],
      });
      expect(uri.toString(), isNot(contains('null')));
    });

    test('rejects a blank widget or reference', () {
      expect(
        () => buildDojahIdentityUri(widgetId: ' ', referenceId: 'ref'),
        throwsFormatException,
      );
      expect(
        () => buildDojahIdentityUri(widgetId: 'widget', referenceId: ''),
        throwsFormatException,
      );
    });
  });

  group('decideDojahNavigation', () {
    test('stays inside Dojah over HTTPS', () {
      expect(
        decideDojahNavigation('https://identity.dojah.io/liveness'),
        DojahWebNavigation.allow,
      );
      expect(
        decideDojahNavigation('https://widget.dojah.io/x'),
        DojahWebNavigation.allow,
      );
      expect(decideDojahNavigation('about:blank'), DojahWebNavigation.allow);
    });

    test('leaving Dojah ends capture for backend reconciliation', () {
      expect(
        decideDojahNavigation('https://boctrust.example/done?status=success'),
        DojahWebNavigation.finish,
      );
      expect(
        decideDojahNavigation('https://identity.dojah.io.evil.test/'),
        DojahWebNavigation.finish,
      );
      expect(
        decideDojahNavigation('https://evildojah.io/'),
        DojahWebNavigation.finish,
      );
      expect(
        decideDojahNavigation('http://identity.dojah.io/'),
        DojahWebNavigation.finish,
      );
    });

    test('blocks other schemes, user-info, and malformed URLs', () {
      expect(decideDojahNavigation('tel:0800'), DojahWebNavigation.block);
      expect(
        decideDojahNavigation('https://user@identity.dojah.io/'),
        DojahWebNavigation.block,
      );
      expect(decideDojahNavigation('https://[bad'), DojahWebNavigation.block);
    });
  });

  group('shouldGrantDojahMedia', () {
    const camera = WebViewPermissionResourceType.camera;
    const microphone = WebViewPermissionResourceType.microphone;

    test('grants camera and microphone to the Dojah page', () {
      expect(
        shouldGrantDojahMedia(
          pageUrl: 'https://identity.dojah.io/selfie',
          types: {camera, microphone},
        ),
        isTrue,
      );
    });

    test('denies an untrusted or unknown page', () {
      expect(
        shouldGrantDojahMedia(pageUrl: 'https://evil.test/', types: {camera}),
        isFalse,
      );
      expect(shouldGrantDojahMedia(pageUrl: null, types: {camera}), isFalse);
    });

    test('denies an empty request', () {
      expect(
        shouldGrantDojahMedia(
          pageUrl: 'https://identity.dojah.io/',
          types: const {},
        ),
        isFalse,
      );
    });
  });
}
