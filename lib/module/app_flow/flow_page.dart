import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_router.dart';
import '../../app/feature_capability.dart';
import '../../app/response_handler.dart';
import '../../app/route_arguments.dart';
import '../../app/route_message_scope.dart';
import 'app_ui.dart';

/// A route registered with [AppRouteDefinition.unavailable].
class UnavailableRouteScreen extends ConsumerStatefulWidget {
  const UnavailableRouteScreen({required this.destination, super.key});

  final UnavailableDestination destination;

  @override
  ConsumerState<UnavailableRouteScreen> createState() =>
      _UnavailableRouteScreenState();
}

class _UnavailableRouteScreenState
    extends FlowPageState<UnavailableRouteScreen> {
  /// An unavailable savings page with nothing beneath returns to the hub.
  @override
  void onNothingToPop() {
    if (widget.destination.section == AppSection.save) {
      goReplacing(AppRoutes.savingsHub);
    }
  }

  @override
  Widget build(BuildContext context) =>
      popScope(unavailablePage(widget.destination));
}

/// Navigation and messages shared by the routed screens of the signed-in
/// app. Every move between screens is a named route on the root navigator.
abstract class FlowPageState<W extends ConsumerStatefulWidget>
    extends ConsumerState<W> {
  /// What this page was opened with.
  AppRouteArguments get routeArguments =>
      RouteMessageScope.argumentsOf(context);

  /// Opens [route] on top of this page. A hub route switches to its tab.
  void go(String route, {AppRouteArguments? arguments}) {
    if (sectionForRoute(route) case final section? when arguments == null) {
      goSection(section);
      return;
    }
    Navigator.of(context).pushNamed(route, arguments: arguments);
  }

  /// Replaces this page, so Back skips it.
  void goReplacing(String route, {AppRouteArguments? arguments}) =>
      Navigator.of(context).pushReplacementNamed(route, arguments: arguments);

  /// Returns to the nearest page named [route] beneath this one, dropping
  /// the pages above it. With none beneath, [route] takes this page's place,
  /// and any earlier pages stay under it.
  void returnTo(String route) {
    if (sectionForRoute(route) case final section?) {
      goSection(section);
      return;
    }
    final navigator = Navigator.of(context);
    final self = ModalRoute.of(context);
    var found = false;
    navigator.popUntil((candidate) {
      found = candidate.settings.name == route;
      return found || candidate.isFirst;
    });
    if (found) return;
    if (self?.isCurrent ?? false) {
      navigator.pushReplacementNamed(route);
    } else {
      navigator.pushNamed(route);
    }
  }

  /// Switches to a bottom-navigation tab; see [replaceWithSection].
  void goSection(AppSection section) => replaceWithSection(context, section);

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
  /// runs [onNothingToPop] rather than closing the app. A hub inside a
  /// [SectionShell] leaves Back to the shell.
  Widget popScope(Widget child) {
    if (isInSectionShell(context)) return child;
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: child,
    );
  }

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
              onPressed: () => returnTo(AppRoutes.savingsHub),
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
