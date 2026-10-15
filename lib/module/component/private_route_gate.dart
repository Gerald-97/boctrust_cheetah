part of '../app_flow/app_ui.dart';

/// Guards a deep link to a signed-in route. The decision uses the route the
/// link named, so later in-flow navigation cannot change what was checked.
/// Nothing under [child] is built until the checks pass.
///
/// Every private route, including Home, requires the signed-in profile to
/// confirm that the transaction PIN has been created.
class PrivateRouteGate extends StatelessWidget {
  const PrivateRouteGate({
    required this.routeName,
    required this.child,
    super.key,
  });

  final String routeName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    void redirect(String route) =>
        // Leave no private route beneath login or PIN setup.
        Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    return SavingsAccessGate(
      onSignedOut: () => redirect(AppRoutes.login),
      onCreatePin: () => redirect(AppRoutes.createFirstPin),
      builder: (_) => child,
    );
  }
}
