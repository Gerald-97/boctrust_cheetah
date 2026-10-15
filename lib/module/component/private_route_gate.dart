part of '../app_flow/app_ui.dart';

/// Guards a deep link to a signed-in route. The decision uses the route the
/// link named, so later in-flow navigation cannot change what was checked.
/// Nothing under [child] is built until the checks pass.
///
/// Home is the landing route after sign-in, which already enforces PIN
/// creation, so it only needs a valid session: a slow or failed profile
/// request then shows Home's own error state instead of blocking it. Every
/// other private route also requires the profile and a created PIN.
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
    if (routeName == AppRoutes.home) {
      return _SessionGate(
        onSignedOut: () => redirect(AppRoutes.login),
        child: child,
      );
    }
    return SavingsAccessGate(
      onSignedOut: () => redirect(AppRoutes.login),
      onCreatePin: () => redirect(AppRoutes.createFirstPin),
      builder: (_) => child,
    );
  }
}

/// Builds [child] only for an unexpired session signed in by this process.
class _SessionGate extends ConsumerStatefulWidget {
  const _SessionGate({required this.onSignedOut, required this.child});

  final VoidCallback onSignedOut;
  final Widget child;

  @override
  ConsumerState<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends ConsumerState<_SessionGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final session = ref.read(authSessionProvider);
    if (session == null || session.isExpired) {
      if (session != null) await ref.read(authSessionProvider.notifier).clear();
      if (mounted) widget.onSignedOut();
      return;
    }
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) => _ready
      ? widget.child
      : const Scaffold(body: Center(child: CircularProgressIndicator()));
}
