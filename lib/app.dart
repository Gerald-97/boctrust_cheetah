import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_router.dart';
import 'app/auth_flow_listener.dart';
import 'app/navigators.dart';
import 'app/preferences.dart';
import 'app/theme.dart';
import 'app/theme_controller.dart';
import 'helper/fcm_service.dart';
import 'helper/local_notification_service.dart';
import 'module/account/provider/account_preferences_provider.dart';

class CheetahApp extends StatelessWidget {
  const CheetahApp({
    super.key,
    required this.preferences,
    this.firebaseReady = false,
    this.notifications,
    this.overrides = const [],
    this.initialRoute = AppRoutes.initial,
  });

  final SharedPreferences preferences;
  final bool firebaseReady;
  final LocalNotificationService? notifications;
  final List<dynamic> overrides;
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        firebaseReadyProvider.overrideWithValue(firebaseReady),
        localNotificationServiceProvider.overrideWithValue(notifications),
        ...overrides,
      ],
      child: AuthFlowListener(
        child: _CheetahMaterialApp(initialRoute: initialRoute),
      ),
    );
  }
}

class CheetahTestApp extends StatelessWidget {
  const CheetahTestApp({
    super.key,
    required this.preferences,
    this.overrides = const [],
    this.initialRoute = AppRoutes.initial,
  });

  final SharedPreferences preferences;
  final List<dynamic> overrides;
  final String initialRoute;

  @override
  Widget build(BuildContext context) => CheetahApp(
    preferences: preferences,
    overrides: overrides,
    initialRoute: initialRoute,
  );
}

class _CheetahMaterialApp extends ConsumerWidget {
  const _CheetahMaterialApp({required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider).themeMode;
    final accessibility = ref.watch(accessibilityPreferencesProvider);
    return MaterialApp(
      title: 'BOCTRUST',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: CheetahTheme.theme(
        Brightness.light,
        highContrast: accessibility.highContrast,
      ),
      darkTheme: CheetahTheme.theme(
        Brightness.dark,
        highContrast: accessibility.highContrast,
      ),
      themeMode: themeMode,
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: CheetahTheme.clampTextScaler(
              media.textScaler,
              preferenceMultiplier: accessibility.textSize.multiplier,
            ),
            boldText: media.boldText || accessibility.boldText,
          ),
          child: child!,
        );
      },
    );
  }
}
