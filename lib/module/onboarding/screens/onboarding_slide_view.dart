import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';

/// One onboarding slide's art: the animated GIF and the still shown until it
/// decodes, if it fails, or under reduced motion.
typedef OnboardingArt = ({String gif, String still});

/// The onboarding carousel: swipeable animated art on paper above a white
/// panel holding the current slide's copy, progress and actions.
///
/// [index] is the current slide. Swiping the art reports the new slide
/// through [onSelect]; changing [index] (Next or a dot) slides the art there.
///
/// Stays light in a dark system theme: the GIFs carry a baked-in paper
/// background, so the view pins the light theme and uses explicit colours.
class OnboardingSlideView extends StatefulWidget {
  const OnboardingSlideView({
    required this.art,
    required this.title,
    required this.description,
    required this.index,
    required this.onNext,
    required this.onLogin,
    required this.onSelect,
    super.key,
  });

  @visibleForTesting
  static const arcsKey = ValueKey('onboarding-arcs');

  final List<OnboardingArt> art;
  final String title;
  final String description;
  final int index;
  final VoidCallback onNext;
  final VoidCallback onLogin;
  final ValueChanged<int> onSelect;

  @override
  State<OnboardingSlideView> createState() => _OnboardingSlideViewState();
}

class _OnboardingSlideViewState extends State<OnboardingSlideView> {
  late final _pages = PageController(initialPage: widget.index);

  // The slide the art is showing or sliding to.
  late int _page = widget.index;

  @override
  void didUpdateWidget(OnboardingSlideView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == _page || !_pages.hasClients) return;
    _page = widget.index;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(_page);
    } else {
      _pages.animateToPage(
        _page,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  // Reports a swipe once the art settles, so the copy changes with the art
  // it describes and a slide's own animation never reports itself back.
  bool _onScrollEnd(ScrollEndNotification notification) {
    final page = _pages.page?.round();
    if (notification.depth == 0 && page != null && page != _page) {
      _page = page;
      widget.onSelect(page);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = CheetahTheme.lightTheme;
    final text = theme.textTheme;
    final slideCount = widget.art.length;
    return Theme(
      data: theme,
      child: Material(
        color: BocColors.paper,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Expanded(
                child: NotificationListener<ScrollEndNotification>(
                  onNotification: _onScrollEnd,
                  child: _Illustrations(art: widget.art, controller: _pages),
                ),
              ),
              // Sized to its copy; on short screens or large text it stops at
              // 60% of the height and scrolls, keeping the actions reachable.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.6,
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: BocColors.card,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      child: ResponsiveContent(
                        maxWidth: 560,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                          child: Column(
                            children: [
                              Text(
                                widget.title,
                                textAlign: TextAlign.center,
                                style: text.headlineSmall?.copyWith(
                                  fontSize: 23,
                                  color: BocColors.navy,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.description,
                                textAlign: TextAlign.center,
                                style: text.bodyMedium?.copyWith(
                                  color: BocColors.inkSoft,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _ProgressDots(
                                index: widget.index,
                                count: slideCount,
                                onSelect: widget.onSelect,
                              ),
                              const SizedBox(height: 16),
                              PrimaryButton(
                                label: widget.index == slideCount - 1
                                    ? 'Get started'
                                    : 'Next',
                                onPressed: widget.onNext,
                              ),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: widget.onLogin,
                                child: const Text('I already have an account'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The slides' art in a pager over fixed arcs. Off-screen pages are disposed,
/// so a slide's GIF starts afresh each time it slides back in.
class _Illustrations extends StatelessWidget {
  const _Illustrations({required this.art, required this.controller});

  final List<OnboardingArt> art;
  final PageController controller;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(key: OnboardingSlideView.arcsKey, painter: _Arcs()),
          SafeArea(
            bottom: false,
            child: PageView.builder(
              controller: controller,
              itemCount: art.length,
              itemBuilder: (context, index) {
                final still = Image.asset(
                  art[index].still,
                  fit: BoxFit.contain,
                );
                return LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox.square(
                      dimension: constraints.biggest.shortestSide,
                      child: reduceMotion
                          ? still
                          : _SlideGif(asset: art[index].gif, still: still),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Plays [asset] from its first frame for as long as this state lives.
///
/// [ImageCache] keeps a GIF's decoder, so a plain [AssetImage] would resume
/// mid-loop when its slide returns. Each visit resolves under its own cache
/// key instead, and evicts that key when it ends so visits don't accumulate.
class _SlideGif extends StatefulWidget {
  const _SlideGif({required this.asset, required this.still});

  final String asset;
  final Widget still;

  @override
  State<_SlideGif> createState() => _SlideGifState();
}

class _SlideGifState extends State<_SlideGif> {
  static var _visits = 0;
  late _VisitImage _image = _VisitImage(widget.asset, _visits++);

  @override
  void didUpdateWidget(_SlideGif oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _image.evict();
      _image = _VisitImage(widget.asset, _visits++);
    }
  }

  @override
  void dispose() {
    _image.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Image(
    image: _image,
    fit: BoxFit.contain,
    frameBuilder: (context, child, frame, _) =>
        frame == null ? widget.still : child,
    errorBuilder: (context, error, stackTrace) => widget.still,
  );
}

/// An asset image cached under a per-visit key. Keys resolve synchronously,
/// so [evict] takes effect immediately.
class _VisitImage extends ImageProvider<_VisitKey> {
  _VisitImage(String asset, this.visit) : _asset = ExactAssetImage(asset);

  final ExactAssetImage _asset;
  final int visit;

  @override
  Future<_VisitKey> obtainKey(ImageConfiguration configuration) =>
      _asset.obtainKey(configuration).then((key) => _VisitKey(key, visit));

  @override
  ImageStreamCompleter loadImage(_VisitKey key, ImageDecoderCallback decode) =>
      _asset.loadImage(key.asset, decode);
}

@immutable
class _VisitKey {
  const _VisitKey(this.asset, this.visit);

  final AssetBundleImageKey asset;
  final int visit;

  @override
  bool operator ==(Object other) =>
      other is _VisitKey && other.asset == asset && other.visit == visit;

  @override
  int get hashCode => Object.hash(asset, visit);
}

/// Two thin pale-gold circles, mostly off-canvas, behind the art.
class _Arcs extends CustomPainter {
  const _Arcs();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = BocColors.goldLight.withValues(alpha: 0.45);
    final w = size.width;
    final h = size.height;
    canvas
      ..drawCircle(Offset(w * 0.22, h * 0.42), w * 0.62, paint)
      ..drawCircle(Offset(-w * 0.12, h * 1.02), w * 0.5, paint);
  }

  @override
  bool shouldRepaint(_Arcs oldDelegate) => false;
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.index,
    required this.count,
    required this.onSelect,
  });

  final int index;
  final int count;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Semantics(
            container: true,
            button: true,
            selected: i == index,
            label: 'Slide ${i + 1} of $count',
            onTap: () => onSelect(i),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: () => onSelect(i),
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: AnimatedContainer(
                    duration: duration,
                    width: i == index ? 28 : 10,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == index
                          ? BocColors.navy
                          : BocColors.grey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
