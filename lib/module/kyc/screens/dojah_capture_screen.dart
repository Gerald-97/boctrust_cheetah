import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/kyc_provider_models.dart';
import '../service/dojah_gateway.dart';
import '../service/dojah_platform_route.dart';
import '../service/dojah_web_policy.dart';
import 'dojah_webview.dart';

class DojahCaptureScreen extends ConsumerStatefulWidget {
  const DojahCaptureScreen({
    required this.widgetId,
    required this.referenceId,
    required this.operation,
    super.key,
  });

  final String widgetId;
  final String referenceId;
  final KycOperation operation;

  @override
  ConsumerState<DojahCaptureScreen> createState() => _DojahCaptureScreenState();
}

class _DojahCaptureScreenState extends ConsumerState<DojahCaptureScreen> {
  var _started = false;
  var _finished = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _launch());
  }

  Future<void> _launch() async {
    if (_started || !mounted) return;
    // The plugin is registered for Android only; never reach its channel
    // from iOS or another platform.
    if (ref.read(dojahPlatformRouteProvider) !=
        DojahPlatformRoute.nativeAndroid) {
      return;
    }
    setState(() {
      _started = true;
      _error = null;
    });
    try {
      final outcome = await ref
          .read(dojahGatewayProvider)
          .launch(widgetId: widget.widgetId, referenceId: widget.referenceId);
      _finish(outcome);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _retry() {
    setState(() {
      _started = false;
      _error = null;
    });
    _launch();
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
          child: switch (ref.watch(dojahPlatformRouteProvider)) {
            DojahPlatformRoute.nativeAndroid => _nativeStatus(),
            DojahPlatformRoute.iosWebView => _browser(),
            DojahPlatformRoute.unsupported => _unavailable(),
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
      );
    } on FormatException {
      return _unavailable();
    }
    return ref.watch(dojahWebViewBuilderProvider)(
      uri: uri,
      onFinished: _finish,
    );
  }

  Widget _unavailable() => _message(
    'Verification with this provider is not yet available on this device.',
    action: 'Close',
    onPressed: _cancel,
  );

  Widget _nativeStatus() => _error == null
      ? const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Finish verification in the Dojah window.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        )
      : _message(
          "We couldn't start verification. Check your connection and try "
          'again.',
          action: 'Retry',
          onPressed: _retry,
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
