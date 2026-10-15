part of '../../app_flow/app_ui.dart';

/// No Savings widget is built until this process's session and its profile
/// agree.
class SavingsAccessGate extends ConsumerStatefulWidget {
  const SavingsAccessGate({
    required this.builder,
    required this.onSignedOut,
    required this.onCreatePin,
    super.key,
  });
  final WidgetBuilder builder;
  final VoidCallback onSignedOut;
  final VoidCallback onCreatePin;

  @override
  ConsumerState<SavingsAccessGate> createState() => _SavingsAccessGateState();
}

class _SavingsAccessGateState extends ConsumerState<SavingsAccessGate> {
  bool _busy = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prepare();
    });
  }

  Future<void> _prepare() async {
    final generation = ++_generation;
    setState(() => _busy = true);
    final session = ref.read(authSessionProvider);
    if (session == null || session.isExpired) {
      if (session != null) {
        await ref.read(authSessionProvider.notifier).clear();
      }
      if (mounted && generation == _generation) widget.onSignedOut();
      return;
    }
    final owner = session.accessToken;
    final profile = ref.read(userProfileProvider);
    if (!profile.isDone || profile.data?.userId != session.userId) {
      await ref.read(userProfileProvider.notifier).load();
    }
    if (!mounted || generation != _generation) return;
    final current = ref.read(authSessionProvider);
    if (current == null || current.isExpired || current.accessToken != owner) {
      return;
    }
    final loaded = ref.read(userProfileProvider);
    if (loaded.isDone &&
        loaded.data?.userId == current.userId &&
        loaded.data?.isCreatedPin == false) {
      widget.onCreatePin();
      return;
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider, (previous, next) {
      if (previous == next) return;
      // Invalidate in-flight preparation immediately, before the next frame.
      _generation++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prepare();
      });
    });
    final session = ref.watch(authSessionProvider);
    final profile = ref.watch(userProfileProvider);
    if (!_busy &&
        session != null &&
        !session.isExpired &&
        profile.data?.userId == session.userId &&
        profile.data?.isCreatedPin == true) {
      return widget.builder(context);
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _busy || profile.isLoading
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Unable to load your account. Please try again.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _prepare,
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: widget.onSignedOut,
                        child: const Text('Back to login'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
