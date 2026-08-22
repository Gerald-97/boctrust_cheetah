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

class BOCTrustApp extends StatelessWidget {
  const BOCTrustApp({
    super.key,
    required this.preferences,
    this.firebaseReady = false,
    this.overrides = const [],
    this.initialRoute = AppRoutes.initial,
  });

  final SharedPreferences preferences;
  final bool firebaseReady;
  final List<dynamic> overrides;
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        firebaseReadyProvider.overrideWithValue(firebaseReady),
        ...overrides,
      ],
      child: AuthFlowListener(
        child: _BOCTrustMaterialApp(initialRoute: initialRoute),
      ),
    );
  }
}

class BOCTrustTestApp extends StatelessWidget {
  const BOCTrustTestApp({
    super.key,
    required this.preferences,
    this.overrides = const [],
    this.initialRoute = AppRoutes.initial,
  });

  final SharedPreferences preferences;
  final List<dynamic> overrides;
  final String initialRoute;

  @override
  Widget build(BuildContext context) => BOCTrustApp(
    preferences: preferences,
    overrides: overrides,
    initialRoute: initialRoute,
  );
}

class _BOCTrustMaterialApp extends ConsumerWidget {
  const _BOCTrustMaterialApp({required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider).themeMode;
    return MaterialApp(
      title: 'BOCTrust',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: BOCTrustTheme.lightTheme,
      darkTheme: BOCTrustTheme.darkTheme,
      themeMode: themeMode,
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
    );
  }
}
