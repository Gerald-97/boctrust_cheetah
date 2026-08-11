import '../app/app_router.dart';
import '../app/navigators.dart';

class NotificationIntent {
  const NotificationIntent({required this.routeName, this.entityId});
  final String routeName;
  final String? entityId;
}

class NotificationNavigator {
  const NotificationNavigator._();

  static NotificationIntent parse(Map<String, dynamic> payload) {
    final route = payload['route'] as String?;
    if (route == null || !AppRoutes.allRoutes.contains(route)) {
      return const NotificationIntent(routeName: AppRoutes.notifications);
    }
    return NotificationIntent(
      routeName: route,
      entityId: payload['id'] as String?,
    );
  }

  static Future<void> dispatch(Map<String, dynamic> payload) async {
    final intent = parse(payload);
    await pushTo(intent.routeName, arguments: intent.entityId);
  }
}
