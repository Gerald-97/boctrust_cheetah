import 'package:flutter/foundation.dart';

enum AppMessageTone { info, success, error }

enum AppRouteTransition { standard, section }

@immutable
class AppRouteArguments {
  const AppRouteArguments({
    this.message,
    this.messageTone = AppMessageTone.info,
    this.entityId,
    this.transition = AppRouteTransition.standard,
  });

  final String? message;
  final AppMessageTone messageTone;
  final String? entityId;
  final AppRouteTransition transition;
}
