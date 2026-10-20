import 'package:material_ui/material_ui.dart';

/// Page transition for every pushed screen (album, artist, …): the new page
/// slides up a little while fading in, and slides back down while fading out
/// when popped. The page below stays still.
///
/// While it moves, the page is painted on an opaque surface so the one below
/// never shows through. Once settled the surface goes away, so ink drawn by
/// the shell's [Material] stays visible. With reduced motion on, it only
/// fades.
class SlideUpPageTransitionsBuilder extends PageTransitionsBuilder {
  const SlideUpPageTransitionsBuilder();

  /// How far below its place the page starts, as a share of its height.
  static const _startOffset = Offset(0, 0.08);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _SlideUpPageTransition(animation: animation, child: child);
  }
}

class _SlideUpPageTransition extends StatefulWidget {
  const _SlideUpPageTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_SlideUpPageTransition> createState() => _SlideUpPageTransitionState();
}

class _SlideUpPageTransitionState extends State<_SlideUpPageTransition> {
  late CurvedAnimation _curved = _curve(widget.animation);

  CurvedAnimation _curve(Animation<double> parent) => CurvedAnimation(
    parent: parent,
    curve: Easing.emphasizedDecelerate,
    // Flipped so a closing page starts slowly and speeds up as it leaves.
    reverseCurve: Easing.emphasizedAccelerate.flipped,
  )..addStatusListener(_onStatus);

  /// The status listener lives on the parent animation, which outlives the
  /// curve, so it is removed by hand.
  void _release() => _curved
    ..removeStatusListener(_onStatus)
    ..dispose();

  /// Rebuilds when the page starts or stops moving, to show or drop the
  /// surface behind it.
  void _onStatus(AnimationStatus status) => setState(() {});

  @override
  void didUpdateWidget(_SlideUpPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animation != oldWidget.animation) {
      _release();
      _curved = _curve(widget.animation);
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = ColoredBox(
      // Kept transparent rather than removed, so the page is not reparented.
      color: _curved.isCompleted
          ? Colors.transparent
          : Theme.of(context).colorScheme.surface,
      child: widget.child,
    );

    return FadeTransition(
      opacity: _curved,
      child: MediaQuery.disableAnimationsOf(context)
          ? page
          : SlideTransition(
              position: Tween(
                begin: SlideUpPageTransitionsBuilder._startOffset,
                end: Offset.zero,
              ).animate(_curved),
              child: page,
            ),
    );
  }
}
