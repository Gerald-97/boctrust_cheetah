import 'package:webview_flutter/webview_flutter.dart';

import '../model/kyc_provider_models.dart';
import 'dojah_gateway.dart';

const _dojahDomain = 'dojah.io';

/// Boctrust verifies Nigerian residents only.
const _residenceCountry = 'NG';

/// The hosted Dojah identity flow for [widgetId], carrying the same attempt
/// metadata as the Android SDK so both platforms tie the session to one
/// backend attempt. `reference_id` is deliberately absent: like the SDK's
/// `referenceId`, it resumes an existing Dojah session. Nigeria is preset as
/// the residence country, and [bvn], when entered, prefills Dojah's BVN step.
///
/// [email] satisfies the flow's Email step. The selfie widget is configured
/// with one, and Dojah skips it outright when the address arrives as
/// `user_data[email]`: checked against the staging widget, where the flow
/// went from its instructions straight to the BVN page. The user gave us the
/// address and has consented to their contact information reaching the
/// provider, so asking a second time is only friction.
Uri buildDojahIdentityUri({
  required String widgetId,
  required String referenceId,
  String? bvn,
  String? email,
}) {
  final widget = widgetId.trim();
  final reference = referenceId.trim();
  if (widget.isEmpty || reference.isEmpty) {
    throw const FormatException('Invalid capture configuration.');
  }
  final prefilledBvn = dojahBvnPrefill(bvn);
  final knownEmail = dojahEmailPrefill(email);
  return Uri.https('identity.$_dojahDomain', '/', {
    'widget_id': widget,
    for (final MapEntry(:key, :value) in dojahAttemptMetadata(
      reference,
    ).entries)
      'metadata[$key]': '$value',
    'user_data[residence_country]': _residenceCountry,
    'user_data[email]': ?knownEmail,
    'gov_data[bvn]': ?prefilledBvn,
    'loading': 'async',
  });
}

/// How the hosted flow reports its own ending.
///
/// The page posts these to `window.parent` when it finishes. Inside the
/// WebView it is the top frame, so `window.parent` is its own window and the
/// message arrives there. Read from the published bundle: Dojah documents the
/// equivalent callbacks only for its JavaScript widget.
const _successEvent = 'connect.account.success';
const _errorEvent = 'connect.account.error';
const _closeEvent = 'connect.widget.close';

/// The name of the channel the listener reports through.
const dojahWebOutcomeChannel = 'BoctrustDojahOutcome';

/// What a posted message means, or null when it is not Dojah reporting.
///
/// Any cross-origin frame may post to the top window, so [origin] is the only
/// thing separating Dojah's own report from an attacker's, and it is checked
/// the way a navigation is. An event this build does not know is ignored
/// rather than guessed at: the backend decides verification, and a wrong
/// guess would close capture on a page still being used.
KycCaptureOutcome? dojahWebOutcomeFor({
  required String type,
  required String origin,
}) {
  final uri = Uri.tryParse(origin);
  if (uri == null || uri.userInfo.isNotEmpty || !_isTrustedDojahPage(uri)) {
    return null;
  }
  return switch (type.trim()) {
    _successEvent => KycCaptureOutcome.submitted,
    _errorEvent => KycCaptureOutcome.failed,
    _closeEvent => KycCaptureOutcome.cancelled,
    _ => null,
  };
}

/// Script that forwards the hosted flow's completion messages to Dart.
///
/// Installed on every page load; the guard keeps a redirect or a re-entered
/// page from stacking listeners that would report one ending twice. The
/// origin travels with the message because only the browser can set it.
const dojahWebOutcomeListener =
    '(function(){'
    'if(window.__boctrustDojahListener)return;'
    'window.__boctrustDojahListener=true;'
    "window.addEventListener('message',function(event){"
    'var data=event&&event.data;'
    "if(!data||typeof data.type!=='string')return;"
    '$dojahWebOutcomeChannel.postMessage(JSON.stringify({'
    'type:data.type,origin:String(event.origin)'
    '}));'
    '});'
    '})();';

enum DojahWebNavigation {
  /// A Dojah page; load it.
  allow,

  /// The flow left Dojah, typically for its configured confirmation page. The
  /// capture is over, but the redirect proves nothing: reconcile the backend.
  finish,

  /// Not a web page this flow may open.
  block,
}

DojahWebNavigation decideDojahNavigation(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.userInfo.isNotEmpty) return DojahWebNavigation.block;
  if (url == 'about:blank') return DojahWebNavigation.allow;
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return DojahWebNavigation.block;
  }
  return _isTrustedDojahPage(uri)
      ? DojahWebNavigation.allow
      : DojahWebNavigation.finish;
}

/// WebKit does not tell Dart which origin asked for capture, so media is only
/// granted while the main frame is a trusted Dojah page.
bool shouldGrantDojahMedia({
  required String? pageUrl,
  required Set<WebViewPermissionResourceType> types,
}) {
  final uri = pageUrl == null ? null : Uri.tryParse(pageUrl);
  if (uri == null || uri.userInfo.isNotEmpty || !_isTrustedDojahPage(uri)) {
    return false;
  }
  const allowed = {
    WebViewPermissionResourceType.camera,
    WebViewPermissionResourceType.microphone,
  };
  return types.isNotEmpty && allowed.containsAll(types);
}

bool _isTrustedDojahPage(Uri uri) {
  final host = uri.host.toLowerCase();
  return uri.scheme == 'https' &&
      (!uri.hasPort || uri.port == 443) &&
      (host == _dojahDomain || host.endsWith('.$_dojahDomain'));
}
