import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../model/kyc_provider_models.dart';
import '../service/dojah_web_policy.dart';

typedef DojahWebViewBuilder =
    Widget Function({
      required Uri uri,
      required ValueChanged<KycCaptureOutcome> onFinished,
    });

final dojahWebViewBuilderProvider = Provider<DojahWebViewBuilder>(
  (ref) =>
      ({required uri, required onFinished}) =>
          DojahWebView(uri: uri, onFinished: onFinished),
);

/// The hosted Dojah flow in an embedded browser. It reports at most one
/// outcome and never navigates the app itself; its owner closes the route.
class DojahWebView extends StatefulWidget {
  const DojahWebView({required this.uri, required this.onFinished, super.key});

  final Uri uri;
  final ValueChanged<KycCaptureOutcome> onFinished;

  @override
  State<DojahWebView> createState() => _DojahWebViewState();
}

/// How long the first load may take before the screen offers a way out.
/// A stalled load reports no error, so nothing else would end the wait.
const _initialLoadTimeout = Duration(seconds: 25);

class _DojahWebViewState extends State<DojahWebView> {
  late final WebViewController _controller;
  String? _pageUrl;
  var _progress = 0;
  var _failed = false;
  var _loaded = false;
  var _reported = false;
  Timer? _stallTimer;

  @override
  void initState() {
    super.initState();
    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    _controller =
        WebViewController.fromPlatformCreationParams(
            params,
            onPermissionRequest: (request) {
              if (shouldGrantDojahMedia(
                pageUrl: _pageUrl,
                types: request.types,
              )) {
                unawaited(request.grant());
              } else {
                unawaited(request.deny());
              }
            },
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..addJavaScriptChannel(
            dojahWebOutcomeChannel,
            onMessageReceived: _onOutcomeMessage,
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: _onNavigationRequest,
              onPageStarted: (url) => _pageUrl = url,
              onPageFinished: (url) {
                _pageUrl = url;
                _loaded = true;
                _stallTimer?.cancel();
                // Reinstalled per load: a redirect drops the listener with
                // the old document.
                unawaited(
                  _controller
                      .runJavaScript(dojahWebOutcomeListener)
                      .catchError((_) {}),
                );
              },
              onUrlChange: (change) => _pageUrl = change.url ?? _pageUrl,
              onProgress: (progress) {
                if (mounted) setState(() => _progress = progress);
              },
              onWebResourceError: (error) {
                if ((error.isForMainFrame ?? false) && mounted) {
                  setState(() => _failed = true);
                }
              },
            ),
          )
          ..loadRequest(widget.uri);
    _stallTimer = Timer(_initialLoadTimeout, () {
      if (!_loaded && mounted) setState(() => _failed = true);
    });
  }

  /// The hosted flow reporting how it ended, so capture closes itself
  /// instead of waiting for the user to back out of a finished page.
  void _onOutcomeMessage(JavaScriptMessage message) {
    if (_reported) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(message.message);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    final type = decoded['type'];
    final origin = decoded['origin'];
    if (type is! String || origin is! String) return;
    final outcome = dojahWebOutcomeFor(type: type, origin: origin);
    if (outcome == null || !mounted) return;
    _reported = true;
    widget.onFinished(outcome);
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    // Subframes cannot move the page; media is gated on the main frame.
    if (!request.isMainFrame) return NavigationDecision.navigate;
    switch (decideDojahNavigation(request.url)) {
      case DojahWebNavigation.allow:
        return NavigationDecision.navigate;
      case DojahWebNavigation.finish:
        // A redirect out of Dojah ends capture but is not a verdict. Dojah
        // navigates away before it posts its result when the flow has a
        // confirmation URL, so this is the ending the backend reconciles.
        if (!_reported) {
          _reported = true;
          widget.onFinished(KycCaptureOutcome.unknown);
        }
        return NavigationDecision.prevent;
      case DojahWebNavigation.block:
        return NavigationDecision.prevent;
    }
  }

  @override
  void dispose() {
    _stallTimer?.cancel();
    // Keep one user's provider session from reaching the next attempt.
    unawaited(_clearBrowsingData());
    super.dispose();
  }

  Future<void> _clearBrowsingData() async {
    try {
      await WebViewCookieManager().clearCookies();
      await _controller.clearLocalStorage();
      await _controller.clearCache();
    } catch (_) {
      // Best effort: the platform view may already be gone.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "We couldn't load verification. Close this screen and check "
                'your verification status before trying again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                // The session may already have been submitted: reconcile.
                onPressed: () => widget.onFinished(KycCaptureOutcome.unknown),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
        Expanded(child: WebViewWidget(controller: _controller)),
      ],
    );
  }
}
