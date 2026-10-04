import 'package:flutter/widgets.dart';

import 'response_handler.dart';
import 'route_arguments.dart';

/// Shows the message a route was opened with, such as "your session expired"
/// on Login, once the page has built.
class RouteMessageScope extends StatefulWidget {
  const RouteMessageScope({
    required this.arguments,
    required this.child,
    super.key,
  });

  final AppRouteArguments arguments;
  final Widget child;

  @override
  State<RouteMessageScope> createState() => _RouteMessageScopeState();
}

class _RouteMessageScopeState extends State<RouteMessageScope> {
  @override
  void initState() {
    super.initState();
    final message = widget.arguments.message;
    if (message == null || message.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (widget.arguments.messageTone) {
        case AppMessageTone.info:
          ResponseHandler.showInfo(message);
        case AppMessageTone.success:
          ResponseHandler.showSuccess(message);
        case AppMessageTone.error:
          ResponseHandler.showError(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
