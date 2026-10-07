import 'package:flutter/foundation.dart';

enum AppMessageTone { info, success, error }

@immutable
class AppRouteArguments {
  const AppRouteArguments({
    this.message,
    this.messageTone = AppMessageTone.info,
    this.entityId,
    this.bankCode,
  });

  final String? message;
  final AppMessageTone messageTone;
  final String? entityId;
  final String? bankCode;
}
