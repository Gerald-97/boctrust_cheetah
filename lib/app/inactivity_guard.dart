import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../module/onboarding/provider/auth_session_provider.dart';
import 'auth_navigation_provider.dart';
import 'inactivity_policy.dart';
import 'navigators.dart';
import 'session_expiry_coordinator.dart';

const inactivitySignedOutMessage =
    'You were signed out after 3 minutes of inactivity.';

/// Signs a session out after [InactivityPolicy] limits without pointer or
/// keyboard activity, warning first. Background time counts as idle.
class InactivityGuard extends ConsumerStatefulWidget {
  const InactivityGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends ConsumerState<InactivityGuard>
    with WidgetsBindingObserver {
  /// Null while signed out, so login and onboarding are never tracked.
  DateTime? _lastActivity;
  Timer? _timer;
  Route<void>? _warning;
  bool _backgrounded = false;

  /// Hides the app from expiry until the login route replaces it.
  bool _expiring = false;

  DateTime _now() => ref.read(inactivityClockProvider)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    ref.listenManual(authSessionProvider, (previous, next) {
      if (next == null) {
        _stop();
      } else if (previous == null) {
        _lastActivity = _now();
        _schedule();
      }
    }, fireImmediately: true);
    ref.listenManual(authNavigationProvider, (_, next) {
      if (_expiring && next.isEmpty && ref.read(authSessionProvider) == null) {
        setState(() => _expiring = false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _backgrounded = true;
        _timer?.cancel();
      case AppLifecycleState.resumed when _backgrounded:
        // The old deadline decides first; resuming is not activity.
        _backgrounded = false;
        _check();
      default:
    }
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) _onActivity();
    return false;
  }

  void _onActivity() {
    final last = _lastActivity;
    // While the warning is open only its button counts.
    if (last == null || _warning != null || _expiring || _backgrounded) return;
    if (InactivityPolicy.evaluate(last, _now()) != InactivityStatus.active) {
      _check();
      return;
    }
    _lastActivity = _now();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final last = _lastActivity;
    if (last == null) return;
    final deadline = last.add(
      _warning == null
          ? InactivityPolicy.warningAfter
          : InactivityPolicy.expireAfter,
    );
    final wait = deadline.difference(_now());
    _timer = Timer(wait.isNegative ? Duration.zero : wait, _check);
  }

  /// Timers can fire late or early, so the clock decides, not the timer.
  void _check() {
    final last = _lastActivity;
    if (last == null || _expiring || !mounted) return;
    switch (InactivityPolicy.evaluate(last, _now())) {
      case InactivityStatus.active:
        _schedule();
      case InactivityStatus.warning:
        _showWarning();
        _schedule();
      case InactivityStatus.expired:
        _expire();
    }
  }

  void _showWarning() {
    final navigator = rootNavigatorKey.currentState;
    if (_warning != null || navigator == null) return;
    final route = DialogRoute<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Are you still there?'),
          content: const Text(
            'For your security, you will be signed out soon because of '
            'inactivity.',
          ),
          actions: [
            FilledButton(
              onPressed: _staySignedIn,
              child: const Text('Stay signed in'),
            ),
          ],
        ),
      ),
    );
    _warning = route;
    navigator.push(route).whenComplete(() {
      if (identical(_warning, route)) _warning = null;
    });
  }

  void _staySignedIn() {
    final last = _lastActivity;
    if (last == null || _expiring) return;
    if (InactivityPolicy.evaluate(last, _now()) == InactivityStatus.expired) {
      _expire();
      return;
    }
    _closeWarning();
    _lastActivity = _now();
    _schedule();
  }

  void _closeWarning() {
    final route = _warning;
    _warning = null;
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
  }

  void _expire() {
    _timer?.cancel();
    setState(() => _expiring = true);
    _closeWarning();
    unawaited(
      ref
          .read(sessionExpiryCoordinatorProvider)
          .expireOnce(message: inactivitySignedOutMessage),
    );
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _lastActivity = null;
    _closeWarning();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onActivity(),
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Offstage(offstage: _expiring, child: widget.child),
      ),
    );
  }
}
