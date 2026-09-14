import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/kyc_provider_models.dart';
import '../service/dojah_gateway.dart';

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
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _launch());
  }

  Future<void> _launch() async {
    if (_started || !mounted) return;
    setState(() {
      _started = true;
      _error = null;
    });
    try {
      final outcome = await ref
          .read(dojahGatewayProvider)
          .launch(widgetId: widget.widgetId, referenceId: widget.referenceId);
      if (mounted) Navigator.of(context).pop(outcome);
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

  void _cancel() {
    if (mounted) Navigator.of(context).pop(KycCaptureOutcome.cancelled);
  }

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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _error == null
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Finish verification in the Dojah window.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "We couldn't start verification. Check your "
                          'connection and try again.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _retry,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
