import 'app_router.dart';
import 'navigators.dart';

typedef ExpiredSessionCallback = Future<void> Function(String message);

class ResponseHandler {
  const ResponseHandler._();

  static Future<void> routeToLogin({
    String message = 'Your session has expired. Please sign in again.',
  }) async {
    await pushToAndClearStack(AppRoutes.login, arguments: message);
  }
}
