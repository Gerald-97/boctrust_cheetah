import 'package:webview_flutter/webview_flutter.dart';

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
