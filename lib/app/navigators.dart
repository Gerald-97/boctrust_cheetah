import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

BuildContext? get rootNavigatorContext => rootNavigatorKey.currentContext;

Future<T?> pushTo<T extends Object?>(
  String routeName, {
  Object? arguments,
}) async {
  final state = rootNavigatorKey.currentState;
  if (state == null) return null;
  return state.pushNamed<T>(routeName, arguments: arguments);
}

Future<T?> pushReplacementTo<T extends Object?, TO extends Object?>(
  String routeName, {
  Object? arguments,
  TO? result,
}) async {
  final state = rootNavigatorKey.currentState;
  if (state == null) return null;
  return state.pushReplacementNamed<T, TO>(
    routeName,
    arguments: arguments,
    result: result,
  );
}

Future<T?> pushToAndClearStack<T extends Object?>(
  String routeName, {
  Object? arguments,
}) async {
  final state = rootNavigatorKey.currentState;
  if (state == null) return null;
  return state.pushNamedAndRemoveUntil<T>(
    routeName,
    (route) => false,
    arguments: arguments,
  );
}

Future<T?> pushToAndClearUntil<T extends Object?>(
  String routeName,
  RoutePredicate predicate, {
  Object? arguments,
}) async {
  final state = rootNavigatorKey.currentState;
  if (state == null) return null;
  return state.pushNamedAndRemoveUntil<T>(
    routeName,
    predicate,
    arguments: arguments,
  );
}

void popContext<T extends Object?>([T? result]) {
  final state = rootNavigatorKey.currentState;
  if (state?.canPop() ?? false) {
    state!.pop<T>(result);
  }
}

Route<T> slideRoute<T>({
  required Widget page,
  RouteSettings? settings,
  Offset startOffset = const Offset(1, 0),
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(
        begin: startOffset,
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
