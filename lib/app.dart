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
  });

  final SharedPreferences preferences;
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        firebaseReadyProvider.overrideWithValue(firebaseReady),
      ],
      child: const AuthFlowListener(child: _BOCTrustMaterialApp()),
    );
  }
}

class BOCTrustTestApp extends StatelessWidget {
  const BOCTrustTestApp({super.key, required this.preferences});

  final SharedPreferences preferences;

  @override
  Widget build(BuildContext context) => BOCTrustApp(preferences: preferences);
}

class _BOCTrustMaterialApp extends ConsumerWidget {
  const _BOCTrustMaterialApp();

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
      initialRoute: AppRoutes.initial,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
    );
  }
}
