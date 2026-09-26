part of '../app_flow/app_flow_navigator.dart';

/// Guards a deep link to a signed-in route. The decision uses the route the
/// link named, so later in-flow navigation cannot change what was checked.
/// Nothing under [child] is built until the session, its profile and a
/// created PIN all check out.
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
    return SavingsAccessGate(
      onSignedOut: () => _redirect(context, AppRoutes.login),
      onCreatePin: () => _redirect(context, AppRoutes.createFirstPin),
      builder: (_) => child,
    );
  }

  void _redirect(BuildContext context, String route) {
    // Leave no private route beneath login or PIN setup.
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }
}
