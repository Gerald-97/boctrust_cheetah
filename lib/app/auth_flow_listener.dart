import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helper/fcm_service.dart';
import '../helper/local_notification_service.dart';
import '../helper/notification_navigator.dart';
import '../module/onboarding/provider/auth_session_provider.dart';
import '../module/onboarding/provider/fcm_token_provider.dart';
import 'app_router.dart';
import 'auth_navigation_provider.dart';
import 'navigators.dart';
import 'route_arguments.dart';

class AuthFlowListener extends ConsumerStatefulWidget {
  const AuthFlowListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuthFlowListener> createState() => _AuthFlowListenerState();
}

class _AuthFlowListenerState extends ConsumerState<AuthFlowListener>
    with WidgetsBindingObserver {
  bool _scheduled = false;
  int? _handlingId;
  bool _checkedInitialNotification = false;
  bool _authenticatedDestinationReady = false;
  Map<String, dynamic>? _pendingNotification;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(authSessionProvider) != null) {
      ref.read(fcmTokenProvider.notifier).registerAfterBootstrap();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<AuthNavigationIntent>>(authNavigationProvider, (_, next) {
      if (next.isNotEmpty) _scheduleDrain();
    });
    ref.listen<AsyncValue<String>>(fcmTokenRefreshProvider, (_, next) {
      next.whenData((token) {
        if (ref.read(authSessionProvider) != null) {
          ref.read(fcmTokenProvider.notifier).registerRefreshedToken(token);
        }
      });
    });
    ref.listen(fcmNotificationOpenedProvider, (_, next) {
      next.whenData((message) => _dispatchNotification(message.data));
    });
    ref.listen(localNotificationTapProvider, (_, next) {
      next.whenData(_dispatchNotification);
    });
    ref.listen(authSessionProvider, (previous, next) {
      if (previous != null && next == null) {
        _authenticatedDestinationReady = false;
        _pendingNotification = null;
      }
    });
    if (!_checkedInitialNotification) {
      _checkedInitialNotification = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _checkInitialNotifications(),
      );
    }
    if (ref.read(authNavigationProvider).isNotEmpty) _scheduleDrain();
    return widget.child;
  }

  /// Dispatches the notification that launched the app, from either the
  /// local plugin (single-use per process) or Firebase.
  Future<void> _checkInitialNotifications() async {
    if (!mounted) return;
    try {
      final local = await ref
          .read(localNotificationServiceProvider)
          ?.getInitialTapPayload();
      if (local != null && mounted) _dispatchNotification(local);
    } catch (_) {
      // Notification-open failures never affect auth or app bootstrap.
    }
    if (!mounted || !ref.read(firebaseReadyProvider)) return;
    try {
      final message = await ref.read(fcmServiceProvider).getInitialMessage();
      if (message == null || !mounted) return;
      _dispatchNotification(message.data);
    } catch (_) {
      // Notification-open failures never affect auth or app bootstrap.
    }
  }

  void _dispatchNotification(Map<String, dynamic> payload) {
    if (ref.read(authSessionProvider) == null ||
        !_authenticatedDestinationReady) {
      _pendingNotification = Map<String, dynamic>.from(payload);
      return;
    }
    unawaited(NotificationNavigator.dispatch(payload));
  }

  void _markAuthenticatedDestinationReady() {
    if (ref.read(authSessionProvider) == null) return;
    _authenticatedDestinationReady = true;
    final payload = _pendingNotification;
    if (payload == null) return;
    _pendingNotification = null;
    unawaited(NotificationNavigator.dispatch(payload));
  }

  void _scheduleDrain() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _drain();
    });
  }

  void _drain() {
    final queue = ref.read(authNavigationProvider);
    if (queue.isEmpty) return;
    final intent = queue.first;
    if (_handlingId == intent.id) return;

    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      _scheduleDrain();
      return;
    }

    _handlingId = intent.id;
    final route = _routeFor(intent.destination);
    final arguments = AppRouteArguments(
      message: intent.message,
      messageTone: intent.messageTone,
    );
    switch (intent.mode) {
      case AuthNavigationMode.push:
        navigator.pushNamed(route, arguments: arguments);
      case AuthNavigationMode.replace:
        navigator.pushReplacementNamed(route, arguments: arguments);
      case AuthNavigationMode.clearStack:
        navigator.pushNamedAndRemoveUntil(
          route,
          (route) => false,
          arguments: arguments,
        );
    }
    ref.read(authNavigationProvider.notifier).acknowledge(intent.id);
    _handlingId = null;
    final remaining = ref.read(authNavigationProvider);
    if (intent.destination == AuthDestination.home && remaining.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markAuthenticatedDestinationReady();
      });
    }
    if (remaining.isNotEmpty) _scheduleDrain();
  }

  String _routeFor(AuthDestination destination) => switch (destination) {
    AuthDestination.bootstrap => AppRoutes.bootstrap,
    AuthDestination.onboarding => AppRoutes.onboarding,
    AuthDestination.verificationMethod => AppRoutes.verificationMethod,
    AuthDestination.signupOtp => AppRoutes.otp,
    AuthDestination.createPassword => AppRoutes.createPassword,
    AuthDestination.login => AppRoutes.login,
    AuthDestination.passwordReset => AppRoutes.passwordReset,
    AuthDestination.newDeviceOtp => AppRoutes.newDeviceOtp,
    AuthDestination.createFirstPin => AppRoutes.createFirstPin,
    AuthDestination.home => AppRoutes.home,
  };
}
