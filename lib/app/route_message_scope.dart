import 'package:flutter/widgets.dart';

import 'response_handler.dart';
import 'route_arguments.dart';

/// Hands a standalone page the arguments its route was opened with, and
/// shows the message they carry, such as "your session expired" on Login,
/// once the page has built.
class RouteMessageScope extends StatefulWidget {
  const RouteMessageScope({
    required this.arguments,
    required this.child,
    super.key,
  });

  final AppRouteArguments arguments;
  final Widget child;

  /// The arguments of the nearest routed page; empty outside one.
  static AppRouteArguments argumentsOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_RouteArguments>()
          ?.arguments ??
      const AppRouteArguments();

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
  Widget build(BuildContext context) =>
      _RouteArguments(arguments: widget.arguments, child: widget.child);
}

class _RouteArguments extends InheritedWidget {
  const _RouteArguments({required this.arguments, required super.child});

  final AppRouteArguments arguments;

  @override
  bool updateShouldNotify(_RouteArguments oldWidget) =>
      oldWidget.arguments != arguments;
}
