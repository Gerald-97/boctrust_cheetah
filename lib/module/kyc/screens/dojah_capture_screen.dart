import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/kyc_provider_models.dart';
import '../service/dojah_camera_permission.dart';
import '../service/dojah_gateway.dart';
import '../service/dojah_platform_route.dart';
import '../service/dojah_web_policy.dart';
import 'dojah_webview.dart';

class DojahCaptureScreen extends ConsumerStatefulWidget {
  const DojahCaptureScreen({
    required this.widgetId,
    required this.referenceId,
    required this.operation,
    this.bvn,
    this.email,
    super.key,
  });

  final String widgetId;
  final String referenceId;
  final KycOperation operation;

  /// The BVN the user entered, prefilled into Dojah. Null for NIN and
  /// government-ID capture.
  final String? bvn;

  /// The address the user signed up with, which satisfies the flow's Email
  /// step so Dojah does not ask for it again. Null when the profile has not
  /// loaded or holds none.
  final String? email;

  @override
  ConsumerState<DojahCaptureScreen> createState() => _DojahCaptureScreenState();
}

class _DojahCaptureScreenState extends ConsumerState<DojahCaptureScreen> {
  var _finished = false;

  /// Null until the camera request has answered, so the browser is never
  /// built before the page can actually use the camera.
  bool? _cameraGranted;

  /// The native SDK refused its configuration before opening.
  var _nativeUnavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestCamera());
  }

  DojahCaptureMode get _mode =>
      dojahCaptureMode(ref.read(dojahPlatformRouteProvider), widget.operation);

  Future<void> _requestCamera() async {
    switch (_mode) {
      case DojahCaptureMode.nativeSdk:
        await _launchNative();
      case DojahCaptureMode.webView:
        final granted = await ref.read(dojahCameraPermissionProvider)();
        if (mounted) setState(() => _cameraGranted = granted);
      case DojahCaptureMode.unsupported:
        return;
    }
  }

  /// Opens the native SDK, which asks for the camera itself, and closes this
  /// route with its result. A native failure is not a verdict: the backend
  /// still decides, so it is reported as unknown and reconciled.
  Future<void> _launchNative() async {
    KycCaptureOutcome outcome;
    try {
      outcome = await ref
          .read(dojahGatewayProvider)
          .launch(
            widgetId: widget.widgetId,
            referenceId: widget.referenceId,
            bvn: widget.bvn,
          );
    } on FormatException {
      if (mounted) setState(() => _nativeUnavailable = true);
      return;
    } on StateError {
      // Another capture is already open; it reports its own result.
      return;
    } catch (_) {
      outcome = KycCaptureOutcome.unknown;
    }
    _finish(outcome);
  }

  /// The only place this route closes, so duplicate or late provider events
  /// cannot pop a second route.
  void _finish(KycCaptureOutcome outcome) {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(outcome);
  }

  void _cancel() => _finish(KycCaptureOutcome.cancelled);

  @override
  Widget build(BuildContext context) {
    final title = widget.operation == KycOperation.identity
        ? 'Verify your identity'
        : 'Verify your document';
    return PopScope<KycCaptureOutcome>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _cancel,
          ),
        ),
        body: SafeArea(
          child: switch (dojahCaptureMode(
            ref.watch(dojahPlatformRouteProvider),
            widget.operation,
          )) {
            // The SDK opens its own screen above this one.
            DojahCaptureMode.nativeSdk =>
              _nativeUnavailable
                  ? _unavailable()
                  : const Center(child: CircularProgressIndicator()),
            DojahCaptureMode.webView => switch (_cameraGranted) {
              null => const Center(child: CircularProgressIndicator()),
              true => _browser(),
              false => _cameraRefused(),
            },
            DojahCaptureMode.unsupported => _unavailable(),
          },
        ),
      ),
    );
  }

  Widget _browser() {
    final Uri uri;
    try {
      uri = buildDojahIdentityUri(
        widgetId: widget.widgetId,
        referenceId: widget.referenceId,
        bvn: widget.bvn,
        email: widget.email,
      );
    } on FormatException {
      return _unavailable();
    }
    return ref.watch(dojahWebViewBuilderProvider)(
      uri: uri,
      onFinished: _finish,
    );
  }

  Widget _cameraRefused() => _message(
    'Camera access is needed to photograph your document. Allow it for '
    'Boctrust in your device settings, then try again.',
    action: 'Close',
    onPressed: _cancel,
  );

  Widget _unavailable() => _message(
    'Verification with this provider is not yet available on this device.',
    action: 'Close',
    onPressed: _cancel,
  );

  Widget _message(
    String text, {
    required String action,
    required VoidCallback onPressed,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onPressed, child: Text(action)),
        ],
      ),
    ),
  );
}
