part of 'app_ui.dart';

/// The five bottom-navigation hubs on one route, under one nav pill.
///
/// A tab tap selects a hub in place: only the body cross-fades, the pill
/// stays put, and a hub keeps its state while another is shown. Every hub
/// route opens this shell on its own section.
class SectionShell extends ConsumerStatefulWidget {
  const SectionShell({required this.initial, super.key});
  const SectionShell.home({super.key}) : initial = AppSection.home;
  const SectionShell.save({super.key}) : initial = AppSection.save;
  const SectionShell.send({super.key}) : initial = AppSection.send;
  const SectionShell.payments({super.key}) : initial = AppSection.payments;
  const SectionShell.account({super.key}) : initial = AppSection.account;

  final AppSection initial;

  @override
  ConsumerState<SectionShell> createState() => _SectionShellState();
}

class _SectionShellState extends ConsumerState<SectionShell> {
  /// Shells on the navigator, oldest first, so a tab tapped on a page above
  /// one can return to it.
  static final _open = <_SectionShellState>[];

  late AppSection _current = widget.initial;

  /// Hubs are built on first visit, so launch loads only the one shown.
  late final _visited = <AppSection>{widget.initial};

  ModalRoute<Object?>? _route;

  @override
  void initState() {
    super.initState();
    _open.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _open.remove(this);
    super.dispose();
  }

  void _select(AppSection section) {
    if (section == _current) return;
    setState(() {
      _current = section;
      _visited.add(section);
    });
  }

  Widget _hub(AppSection section) => switch (section) {
    AppSection.home => const HomeScreen(),
    AppSection.save => const SaveHubScreen(),
    AppSection.send => const SendScreen.hub(),
    AppSection.payments => const PaymentsScreen.hub(),
    AppSection.account => const AccountScreen.account(),
  };

  @override
  Widget build(BuildContext context) {
    // Hubs lay out as they did on their own routes: the shell's Scaffold
    // would otherwise add the pill to their bottom padding, which
    // [FloatingNavClearance.clearOfNav] already accounts for.
    final media = MediaQuery.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return PopScope(
      // A shell above other pages pops like any page. The bottom one shows
      // Home on Back, and only Home lets Back leave the app.
      canPop: Navigator.of(context).canPop() || _current == AppSection.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(AppSection.home);
      },
      child: Scaffold(
        extendBody: true,
        body: MediaQuery(
          data: media,
          child: _SectionShellScope(
            current: _current,
            select: _select,
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (final section in AppSection.values)
                  if (_visited.contains(section))
                    _SectionLayer(
                      key: ValueKey(section),
                      active: section == _current,
                      duration: duration,
                      child: _hub(section),
                    ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: AppBottomNavigation(
          selected: _current,
          onSelected: _select,
        ),
      ),
    );
  }
}

/// One hub in the shell: shown and interactive only while selected. A hub
/// that has faded out goes offstage, keeping its state without layout.
class _SectionLayer extends StatefulWidget {
  const _SectionLayer({
    required this.active,
    required this.duration,
    required this.child,
    super.key,
  });

  final bool active;
  final Duration duration;
  final Widget child;

  @override
  State<_SectionLayer> createState() => _SectionLayerState();
}

class _SectionLayerState extends State<_SectionLayer> {
  /// True once an inactive hub has finished fading out.
  late bool _faded = !widget.active;

  @override
  void didUpdateWidget(_SectionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Without an animation, no fade ever ends to hide the hub.
    if (widget.active || widget.duration == Duration.zero) {
      _faded = !widget.active;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return Offstage(
      offstage: !active && _faded,
      child: IgnorePointer(
        ignoring: !active,
        child: ExcludeFocus(
          excluding: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: widget.duration,
              curve: Curves.easeOut,
              onEnd: () {
                if (mounted && !widget.active) setState(() => _faded = true);
              },
              child: TickerMode(enabled: active, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// What a hub inside a [SectionShell] sees of it.
class _SectionShellScope extends InheritedWidget {
  const _SectionShellScope({
    required this.current,
    required this.select,
    required super.child,
  });

  final AppSection current;
  final ValueChanged<AppSection> select;

  static _SectionShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SectionShellScope>();

  @override
  bool updateShouldNotify(_SectionShellScope oldWidget) =>
      current != oldWidget.current;
}

/// True when [context] sits on a hub inside a [SectionShell], which owns the
/// nav pill and Back.
bool isInSectionShell(BuildContext context) =>
    context.getInheritedWidgetOfExactType<_SectionShellScope>() != null;
