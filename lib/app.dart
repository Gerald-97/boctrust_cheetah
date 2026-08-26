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

class CheetahApp extends StatelessWidget {
  const CheetahApp({
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
    return MaterialApp(
      title: 'Cheetah',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: CheetahTheme.lightTheme,
      darkTheme: CheetahTheme.darkTheme,
      themeMode: themeMode,
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
    );
  }
}
