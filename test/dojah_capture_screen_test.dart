import 'dart:async';

import 'package:boctrust_savings_loan/module/kyc/model/kyc_provider_models.dart';
import 'package:boctrust_savings_loan/module/kyc/screens/dojah_capture_screen.dart';
import 'package:boctrust_savings_loan/module/kyc/service/dojah_gateway.dart';
import 'package:boctrust_savings_loan/module/kyc/screens/dojah_webview.dart';
import 'package:boctrust_savings_loan/module/kyc/service/dojah_platform_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gateway implements DojahGateway {
  final result = Completer<KycCaptureOutcome>();
  var calls = 0;

  @override
  Future<KycCaptureOutcome> launch({
    required String widgetId,
    required String referenceId,
  }) {
    calls++;
    return result.future;
  }
}

void main() {
  testWidgets('launches once and returns the normalized outcome', (
    tester,
  ) async {
    final gateway = _Gateway();
    KycCaptureOutcome? outcome;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dojahGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                outcome = await Navigator.of(context).push<KycCaptureOutcome>(
                  MaterialPageRoute(
                    builder: (_) => const DojahCaptureScreen(
                      widgetId: 'selfie-widget',
                      referenceId: 'boc-attempt-000001',
                      operation: KycOperation.identity,
                    ),
                  ),
                );
              },
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump();
    expect(gateway.calls, 1);

    await tester.pump();
    expect(gateway.calls, 1);

    gateway.result.complete(KycCaptureOutcome.unknown);
    await tester.pumpAndSettle();
    expect(outcome, KycCaptureOutcome.unknown);
  });

  testWidgets('back is a cancellation while native capture is pending', (
    tester,
  ) async {
    final gateway = _Gateway();
    KycCaptureOutcome? outcome;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dojahGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                outcome = await Navigator.of(context).push<KycCaptureOutcome>(
                  MaterialPageRoute(
                    builder: (_) => const DojahCaptureScreen(
                      widgetId: 'government-widget',
                      referenceId: 'boc-attempt-000002',
                      operation: KycOperation.governmentId,
                    ),
                  ),
                );
              },
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(outcome, KycCaptureOutcome.cancelled);
  });

  testWidgets('iOS opens the identity URL in the browser, never native', (
    tester,
  ) async {
    final gateway = _Gateway();
    final browser = _Browser();
    final outcomes = <KycCaptureOutcome?>[];
    await tester.pumpWidget(
      _app(
        gateway: gateway,
        route: DojahPlatformRoute.iosWebView,
        browser: browser,
        onOutcome: outcomes.add,
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(gateway.calls, 0);
    expect(browser.uri?.host, 'identity.dojah.io');
    expect(browser.uri?.queryParameters, {
      'widget_id': 'selfie-widget',
      'metadata[reference]': 'boc-attempt-000003',
      'loading': 'async',
    });

    browser.onFinished!(KycCaptureOutcome.unknown);
    browser.onFinished!(KycCaptureOutcome.submitted);
    await tester.pumpAndSettle();

    expect(outcomes, [KycCaptureOutcome.unknown]);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('iOS back closes the browser as a cancellation', (tester) async {
    final outcomes = <KycCaptureOutcome?>[];
    await tester.pumpWidget(
      _app(
        gateway: _Gateway(),
        route: DojahPlatformRoute.iosWebView,
        browser: _Browser(),
        onOutcome: outcomes.add,
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(outcomes, [KycCaptureOutcome.cancelled]);
  });

  testWidgets('unsupported platforms never launch capture', (tester) async {
    final gateway = _Gateway();
    final browser = _Browser();
    final outcomes = <KycCaptureOutcome?>[];
    await tester.pumpWidget(
      _app(
        gateway: gateway,
        route: DojahPlatformRoute.unsupported,
        browser: browser,
        onOutcome: outcomes.add,
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(gateway.calls, 0);
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
  required _Gateway gateway,
  required DojahPlatformRoute route,
  required _Browser browser,
  required void Function(KycCaptureOutcome?) onOutcome,
}) {
  return ProviderScope(
    overrides: [
      dojahGatewayProvider.overrideWithValue(gateway),
      dojahPlatformRouteProvider.overrideWithValue(route),
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
