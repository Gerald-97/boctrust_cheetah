import 'dart:async';

import 'package:boctrust_savings_loan/module/kyc/model/kyc_models.dart';
import 'package:boctrust_savings_loan/module/kyc/screens/smile_id_enhanced_document_screen.dart';
import 'package:boctrust_savings_loan/module/kyc/service/smile_id_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stand-in for the native SDK view.
///
/// Exposes the callbacks the real platform view would invoke as buttons, so
/// success, failure, and the iOS initialization-failure path can all be driven
/// from a widget test without a platform channel.
class _FakeGateway implements SmileIdGateway {
  Object? initializationError;
  int ensureInitializedCalls = 0;
  int resetCalls = 0;
  int applyCallbackUrlCalls = 0;
  Uri? lastCallbackUrl;

  ValueChanged<String>? _onSuccess;
  ValueChanged<String>? _onError;

  void emitSuccess() => _onSuccess!('{"opaque":"result"}');
  void emitError() => _onError!('raw sdk error detail');

  @override
  Future<void> ensureInitialized() async {
    ensureInitializedCalls++;
    final error = initializationError;
    if (error != null) throw error;
  }

  @override
  void resetInitialization() => resetCalls++;

  @override
  void applyCallbackUrl(Uri callbackUrl) {
    applyCallbackUrlCalls++;
    lastCallbackUrl = callbackUrl;
  }

  @override
  Widget buildEnhancedDocumentVerification({
    required SmileIdDocumentJob job,
    required ValueChanged<String> onSuccess,
    required ValueChanged<String> onError,
  }) {
    _onSuccess = onSuccess;
    _onError = onError;
    return const Center(child: Text('capture-surface'));
  }
}

SmileIdDocumentJob _job() => SmileIdDocumentJob.fromInitiation(
  KycInitiationData.fromJson({
    'verificationId': 'verification-1',
    'product': 'enhanced_document_verification',
    'sdkJobType': 'enhancedDocumentVerification',
    'environment': 'sandbox',
    'country': 'NG',
    'documentType': 'voter_id',
    'smileUserId': 'smile-user-1',
    'smileJobId': 'smile-job-1',
    'callbackUrl': 'https://user.example.test/document-webhook',
    'partnerParams': {'job_type': 11},
  }),
  useSandbox: true,
);

void main() {
  late _FakeGateway gateway;
  late SmileIdFlowOutcome? outcome;

  setUp(() {
    gateway = _FakeGateway();
    outcome = null;
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [smileIdGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                outcome = await Navigator.of(context).push<SmileIdFlowOutcome>(
                  MaterialPageRoute(
                    builder: (_) => SmileIdEnhancedDocumentScreen(job: _job()),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows progress while initializing, then the capture surface', (
    tester,
  ) async {
    final gate = Completer<void>();
    gateway = _FakeGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [smileIdGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          home: FutureBuilder<void>(
            future: gate.future,
            builder: (_, _) => SmileIdEnhancedDocumentScreen(job: _job()),
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('capture-surface'), findsOneWidget);
    expect(gateway.applyCallbackUrlCalls, 1);
    expect(
      gateway.lastCallbackUrl.toString(),
      'https://user.example.test/document-webhook',
    );
  });

  testWidgets('initialization failure offers Retry and resets the SDK', (
    tester,
  ) async {
    gateway.initializationError = StateError('config missing');
    await pumpScreen(tester);

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('capture-surface'), findsNothing);
    // The underlying error text must never reach the UI.
    expect(find.textContaining('config missing'), findsNothing);

    gateway.initializationError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(gateway.resetCalls, 1);
    expect(gateway.ensureInitializedCalls, 2);
    expect(find.text('capture-surface'), findsOneWidget);
  });

  testWidgets('SDK success pops with submitted and discards the result JSON', (
    tester,
  ) async {
    await pumpScreen(tester);
    gateway.emitSuccess();
    await tester.pumpAndSettle();

    expect(outcome, SmileIdFlowOutcome.submitted);
    expect(find.textContaining('opaque'), findsNothing);
  });

  testWidgets('an immediate SDK error is treated as initialization failure', (
    tester,
  ) async {
    // This is the iOS bad-config path: ensureInitialized() reported success
    // because initializeWithConfig cannot fail there, and the native view
    // rejected its first frame instead.
    await pumpScreen(tester);
    gateway.emitError();
    await tester.pumpAndSettle();

    expect(outcome, isNull, reason: 'must not pop; it offers Retry instead');
    expect(find.text('Retry'), findsOneWidget);
    expect(gateway.resetCalls, 1);
    expect(find.textContaining('raw sdk error'), findsNothing);
  });

  testWidgets('a later SDK error pops with failed', (tester) async {
    await pumpScreen(tester);
    // Past the initialization window, an error is a genuine capture failure.
    await tester.pump(const Duration(seconds: 6));
    gateway.emitError();
    await tester.pumpAndSettle();

    expect(outcome, SmileIdFlowOutcome.failed);
    expect(find.textContaining('raw sdk error'), findsNothing);
  });

  testWidgets('back returns cancelled so the job stays resumable', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(outcome, SmileIdFlowOutcome.cancelled);
  });
}
