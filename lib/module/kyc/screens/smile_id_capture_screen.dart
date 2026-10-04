import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../service/smile_id_gateway.dart';

enum _Stage { initializing, capturing, initializationFailed }

/// Full-screen host for any Smile ID capture flow.
///
/// Both products need the same initialization, retry, cancellation, and iOS
/// failure handling, so they share one screen and dispatch on the job type.
///
/// Pops with a [SmileIdFlowOutcome]. Submitted means the job reached Smile, not
/// that the user is verified: only `GET /users/me/kyc/status` and the refreshed
/// aggregates may show verification.
class SmileIdCaptureScreen extends ConsumerStatefulWidget {
  const SmileIdCaptureScreen({required this.job, super.key});

  final SmileIdCaptureJob job;

  @override
  ConsumerState<SmileIdCaptureScreen> createState() =>
      _SmileIdCaptureScreenState();
}

class _SmileIdCaptureScreenState extends ConsumerState<SmileIdCaptureScreen> {
  /// An SDK error this soon after the capture view appears is treated as a
  /// failed initialization rather than a failed capture.
  ///
  /// On iOS `initializeWithConfig` cannot report failure through its Future, so
  /// a missing or malformed config only surfaces when the native view rejects
  /// its first frame. Without this window the screen would show a capture
  /// surface that can never submit.
  static const _initializationFailureWindow = Duration(seconds: 5);

  _Stage _stage = _Stage.initializing;

  /// False until [_initializationFailureWindow] has elapsed since the capture
  /// view was inserted.
  ///
  /// A [Timer] rather than a wall-clock comparison: it is driven by the test
  /// clock, so both `onError` branches are reachable from a widget test, and it
  /// is cancelled on dispose rather than left to fire against a dead State.
  bool _pastInitializationWindow = false;
  Timer? _initializationWindowTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _initializationWindowTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    _closeInitializationWindow();
    setState(() => _stage = _Stage.initializing);

    final gateway = ref.read(smileIdGatewayProvider);
    try {
      await gateway.ensureInitialized();
      // Global SDK state, so it is set once here rather than from build().
      gateway.applyCallbackUrl(widget.job.callbackUrl);
    } catch (_) {
      // The message is deliberately not rendered: it can carry config details.
      if (mounted) setState(() => _stage = _Stage.initializationFailed);
      return;
    }

    if (!mounted) return;
    _initializationWindowTimer = Timer(
      _initializationFailureWindow,
      () => _pastInitializationWindow = true,
    );
    setState(() => _stage = _Stage.capturing);
  }

  void _retry() {
    ref.read(smileIdGatewayProvider).resetInitialization();
    _initialize();
  }

  void _close(SmileIdFlowOutcome outcome) {
    if (!mounted) return;
    Navigator.of(context).pop(outcome);
  }

  void _handleSdkSuccess(String _) {
    // The result JSON is an opaque submission acknowledgement. It is never
    // parsed, stored, or logged.
    _close(SmileIdFlowOutcome.submitted);
  }

  void _closeInitializationWindow() {
    _initializationWindowTimer?.cancel();
    _initializationWindowTimer = null;
    _pastInitializationWindow = false;
  }

  void _handleSdkError(String _) {
    if (!_pastInitializationWindow) {
      // The native SDK rejected the very first frame. On iOS this is how a bad
      // config surfaces, because initializeWithConfig cannot report it.
      _closeInitializationWindow();
      ref.read(smileIdGatewayProvider).resetInitialization();
      if (mounted) setState(() => _stage = _Stage.initializationFailed);
      return;
    }

    _close(SmileIdFlowOutcome.failed);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<SmileIdFlowOutcome>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Back is a cancellation, never a failure: the job stays resumable.
        _close(SmileIdFlowOutcome.cancelled);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(switch (widget.job) {
            SmileIdBiometricJob() => 'Verify your identity',
            SmileIdDocumentJob() => 'Verify your document',
          }),
          leading: IconButton(
            icon: const Icon(IconsaxPlusLinear.arrow_left),
            onPressed: () => _close(SmileIdFlowOutcome.cancelled),
          ),
        ),
        body: switch (_stage) {
          _Stage.initializing => const Center(
            child: CircularProgressIndicator(),
          ),
          _Stage.initializationFailed => _InitializationFailure(
            // The screen hosts both products, so the message must name the one
            // the user actually started.
            what: switch (widget.job) {
              SmileIdBiometricJob() => 'identity verification',
              SmileIdDocumentJob() => 'document verification',
            },
            onRetry: _retry,
          ),
          // Exhaustive over the sealed job, so a new product cannot be added
          // without deciding how it is launched.
          _Stage.capturing => switch (widget.job) {
            final SmileIdBiometricJob job =>
              ref
                  .read(smileIdGatewayProvider)
                  .buildBiometricKyc(
                    job: job,
                    onSuccess: _handleSdkSuccess,
                    onError: _handleSdkError,
                  ),
            final SmileIdDocumentJob job =>
              ref
                  .read(smileIdGatewayProvider)
                  .buildEnhancedDocumentVerification(
                    job: job,
                    onSuccess: _handleSdkSuccess,
                    onError: _handleSdkError,
                  ),
          },
        },
      ),
    );
  }
}

class _InitializationFailure extends StatelessWidget {
  const _InitializationFailure({required this.what, required this.onRetry});

  final String what;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "We couldn't start $what. Please check your connection and "
                  'try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
