import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_router.dart';
import '../../app/feature_capability.dart';
import '../../app/response_handler.dart';
import '../../app/route_arguments.dart';
import '../../app/route_message_scope.dart';
import 'app_flow_navigator.dart';

/// Navigation and messages shared by the routed screens of the signed-in
/// app. Every move between screens is a named route on the root navigator.
abstract class FlowPageState<W extends ConsumerStatefulWidget>
    extends ConsumerState<W> {
  /// What this page was opened with.
  AppRouteArguments get routeArguments =>
      RouteMessageScope.argumentsOf(context);

  void go(String route, {AppRouteArguments? arguments}) =>
      Navigator.of(context).pushNamed(route, arguments: arguments);

  /// Replaces this page, so Back skips it.
  void goReplacing(String route) =>
      Navigator.of(context).pushReplacementNamed(route);

  /// A tab replaces this page with the section hub, so Back from the hub
  /// returns to whatever opened this page.
  void goSection(AppSection section) =>
      goReplacing(appRouteForSection(section));

  /// Pops this page. A page with nothing beneath it runs
  /// [onNothingToPop] instead.
  void back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      onNothingToPop();
    }
  }

  /// Where Back goes when this page is the only one; by default nowhere.
  void onNothingToPop() {}

  /// System Back for this page: pops when there is a page beneath, otherwise
  /// runs [onNothingToPop] rather than closing the app. Only Home, with
  /// [exitsApp], lets Back leave the app.
  Widget popScope(Widget child, {bool exitsApp = false}) => PopScope(
    canPop: Navigator.of(context).canPop() || exitsApp,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) back();
    },
    child: child,
  );

  /// The honest page for a destination that is not built yet. Savings pages
  /// keep a way back to the Savings hub.
  Widget unavailablePage(UnavailableDestination destination) {
    final capability = destination.capability;
    if (capability != null) {
      assertPlaceholderFor(capability, FeatureAvailability.unavailable);
    }
    return UnavailableFeatureScreen(
      destination: destination,
      onBack: back,
      onSectionSelected: goSection,
      action: destination.section == AppSection.save
          ? OutlinedButton(
              onPressed: () => go(AppRoutes.savingsHub),
              child: const Text('Back to Savings'),
            )
          : null,
    );
  }

  void showMessage(String message) => ResponseHandler.showInfo(message);
  void showSuccessMessage(String message) =>
      ResponseHandler.showSuccess(message);
  void showErrorMessage(String message) => ResponseHandler.showError(message);

  /// A placeholder may only stand in for a capability the registry still
  /// reports in [expected]; switching one on without building its real
  /// screen fails fast in debug builds.
  void assertPlaceholderFor(
    FeatureCapability capability,
    FeatureAvailability expected,
  ) {
    assert(
      ref.read(featureAvailabilityProvider(capability)) == expected,
      '$capability is no longer $expected but still shows a placeholder.',
    );
  }
}
