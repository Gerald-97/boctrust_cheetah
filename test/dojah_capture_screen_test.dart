import 'package:boctrust_savings_loan/module/kyc/model/kyc_provider_models.dart';
import 'package:boctrust_savings_loan/module/kyc/screens/dojah_capture_screen.dart';
import 'package:boctrust_savings_loan/module/kyc/screens/dojah_webview.dart';
import 'package:boctrust_savings_loan/module/kyc/service/dojah_camera_permission.dart';
import 'package:boctrust_savings_loan/module/kyc/service/dojah_platform_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('capture opens the identity URL in the browser', (tester) async {
    final browser = _Browser();
    final outcomes = <KycCaptureOutcome?>[];
    await tester.pumpWidget(
      _app(
        route: DojahPlatformRoute.webView,
        browser: browser,
        onOutcome: outcomes.add,
        cameraGranted: true,
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(browser.uri?.host, 'identity.dojah.io');
    expect(browser.uri?.queryParameters, {
      'widget_id': 'selfie-widget',
      'metadata[reference]': 'boc-attempt-000003',
      'user_data[residence_country]': 'NG',
      'user_data[email]': 'person@example.test',
      'gov_data[bvn]': '00000000006',
      'loading': 'async',
    });

    browser.onFinished!(KycCaptureOutcome.unknown);
    browser.onFinished!(KycCaptureOutcome.submitted);
    await tester.pumpAndSettle();

    expect(outcomes, [KycCaptureOutcome.unknown]);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('back closes the browser as a cancellation', (tester) async {
    final outcomes = <KycCaptureOutcome?>[];
    await tester.pumpWidget(
      _app(
        route: DojahPlatformRoute.webView,
        browser: _Browser(),
        onOutcome: outcomes.add,
        cameraGranted: true,
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(outcomes, [KycCaptureOutcome.cancelled]);
  });

  testWidgets('unsupported platforms never launch capture', (tester) async {
    final browser = _Browser();
    final outcomes = <KycCaptureOutcome?>[];
    await tester.pumpWidget(
      _app(
        route: DojahPlatformRoute.unsupported,
        browser: browser,
        onOutcome: outcomes.add,
        cameraGranted: true,
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(browser.uri, isNull);
    expect(
      find.text(
        'Verification with this provider is not yet available on this device.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(outcomes, [KycCaptureOutcome.cancelled]);
  });

  testWidgets('a refused camera never opens the browser', (tester) async {
    // The hosted flow photographs the document, so without camera access
    // there is nothing to show. The native SDK used to ask for this itself.
    final browser = _Browser();
    final outcomes = <KycCaptureOutcome?>[];
    await tester.pumpWidget(
      _app(
        route: DojahPlatformRoute.webView,
        browser: browser,
        onOutcome: outcomes.add,
        cameraGranted: false,
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(browser.uri, isNull);
    expect(find.textContaining('Camera access'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(outcomes, [KycCaptureOutcome.cancelled]);
  });

  testWidgets('a granted camera opens the browser', (tester) async {
    final browser = _Browser();
    await tester.pumpWidget(
      _app(
        route: DojahPlatformRoute.webView,
        browser: browser,
        onOutcome: (_) {},
        cameraGranted: true,
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(browser.uri, isNotNull);
  });
}

class _Browser {
  Uri? uri;
  ValueChanged<KycCaptureOutcome>? onFinished;

  Widget build({
    required Uri uri,
    required ValueChanged<KycCaptureOutcome> onFinished,
  }) {
    this.uri = uri;
    this.onFinished = onFinished;
    return const Text('Dojah browser');
  }
}

Widget _app({
  required DojahPlatformRoute route,
  required _Browser browser,
  required void Function(KycCaptureOutcome?) onOutcome,
  bool cameraGranted = true,
}) {
  return ProviderScope(
    overrides: [
      dojahPlatformRouteProvider.overrideWithValue(route),
      dojahCameraPermissionProvider.overrideWithValue(
        () async => cameraGranted,
      ),
      dojahWebViewBuilderProvider.overrideWithValue(browser.build),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            onOutcome(
              await Navigator.of(context).push<KycCaptureOutcome>(
                MaterialPageRoute(
                  builder: (_) => const DojahCaptureScreen(
                    widgetId: 'selfie-widget',
                    referenceId: 'boc-attempt-000003',
                    operation: KycOperation.identity,
                    bvn: '00000000006',
                    email: 'person@example.test',
                  ),
                ),
              ),
            );
          },
          child: const Text('Start'),
        ),
      ),
    ),
  );
}
