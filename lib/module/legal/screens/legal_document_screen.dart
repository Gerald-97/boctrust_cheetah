import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/services.dart';

/// Displays a legal page from the configured BOCTRUST website.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen.privacy({super.key})
    : title = 'Privacy Policy',
      page = 'privacy';

  const LegalDocumentScreen.terms({super.key})
    : title = 'Terms & Conditions',
      page = 'terms';

  final String title;
  final String page;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late final _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..loadRequest(sitePageUri(widget.page));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(top: false, child: WebViewWidget(controller: _controller)),
  );
}
