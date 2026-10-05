import '../app/app_router.dart';
import '../app/navigators.dart';
import '../app/route_arguments.dart';
import '../module/app_flow/app_ui.dart';
import 'notification_payload.dart';

class NotificationIntent {
  const NotificationIntent({required this.routeName, this.entityId});
  final String routeName;
  final String? entityId;
}

class NotificationNavigator {
  const NotificationNavigator._();

  static NotificationIntent parse(Map<String, dynamic> payload) {
    final route = _bounded(payload['route']);
    if (route == null || !AppRoutes.allRoutes.contains(route)) {
      return const NotificationIntent(routeName: AppRoutes.notifications);
    }
    return NotificationIntent(
      routeName: route,
      entityId: _bounded(payload['id']),
    );
  }

  static String? _bounded(Object? value) =>
      value is String && value.length <= NotificationPayload.maxFieldLength
      ? value
      : null;

  static Future<void> dispatch(Map<String, dynamic> payload) async {
    final intent = parse(payload);
    // A hub is a tab of the open shell, not a page to stack on it.
    final section = sectionForRoute(intent.routeName);
    if (section != null && selectOpenSection(section)) return;
    await pushTo(
      intent.routeName,
      arguments: AppRouteArguments(entityId: intent.entityId),
    );
  }
}
