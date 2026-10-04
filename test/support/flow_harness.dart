import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/bootstrap_provider.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/preferences.dart';
import 'package:boctrust_savings_loan/app/route_arguments.dart';
import 'package:boctrust_savings_loan/app/route_message_scope.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kyc_configuration_fixtures.dart';
import 'responsive_fixtures.dart';

/// Overrides that let an app page mount without a network or device
/// storage: every request resolves as a 503.
Future<List<Override>> flowTestOverrides() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final dio = Dio(BaseOptions(baseUrl: 'https://flow-test.invalid'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 503,
          data: {'message': 'Unavailable in flow test'},
        ),
      ),
    ),
  );
  addTearDown(dio.close);
  return [
    sharedPreferencesProvider.overrideWithValue(preferences),
    dioProvider.overrideWithValue(dio),
    startupGateProvider.overrideWith(LayoutStartup.new),
    stagingBuildOverride,
  ];
}

Widget flowApp({
  required String route,
  AppRouteArguments arguments = const AppRouteArguments(),
}) {
  return MaterialApp(
    theme: CheetahTheme.lightTheme,
    onGenerateRoute: AppRouter.onGenerateRoute,
    home: appHome(route: route, arguments: arguments),
  );
}

/// What [route] opens, without its access gate.
Widget appHome({
  required String route,
  AppRouteArguments arguments = const AppRouteArguments(),
}) => RouteMessageScope(
  arguments: arguments,
  child: appRouteDefinitions[route]!.pageBuilder(),
);

/// Mounts the app at [route] and settles the transition.
Future<void> pumpFlow(
  WidgetTester tester, {
  required String route,
  AppRouteArguments arguments = const AppRouteArguments(),
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...await flowTestOverrides(), ...overrides],
      child: flowApp(route: route, arguments: arguments),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}
