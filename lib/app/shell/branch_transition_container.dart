import 'package:material_ui/material_ui.dart';

import 'app_destination.dart';

/// How far a branch travels while [BranchTransitionContainer] animates
/// between two of them (M3 shared axis Y, see the directional-branch-
/// transition plan, decision Q3a).
const _slideDistance = 30.0;

/// How long [BranchTransitionContainer] takes to settle on the new branch.
const _transitionDuration = Duration(milliseconds: 300);

/// Share of [_transitionDuration] the old page spends fading out (and, by
/// symmetry, the new page spends still invisible before it starts fading
/// in): `0.35` of the clip at the front for the old page, the other `0.65`
/// at the back for the new one.
const _crossfadeSplit = 0.35;

/// Container for the branch Navigators of the app's top-level
/// `StatefulShellRoute`, used in place of go_router's own
/// `StatefulShellRoute.indexedStack` (`navigatorContainerBuilder`).
///
/// Behaves like go_router's default container — every branch stays mounted;
/// the one that is not [currentIndex] is `Offstage` with its `TickerMode`
/// off, which also pauses the Riverpod providers of its page — but animates
/// the switch instead of swapping instantly: the old and new branch are both
/// drawn for 300 ms, sliding past each other along the y axis in the
/// direction [branchDirection] gives for the destinations at the old and new
/// index (M3 shared axis Y, 30 px, see the directional-branch-transition
/// plan). The first build, and switching to the branch already showing
/// (tapping the current sidebar entry again, changing Search's `?q=`), never
/// animates.
///
/// With reduced motion ([MediaQuery.disableAnimationsOf]) the switch only
/// cross-fades, over the same duration, with no slide.
///
/// Switching again before the running transition settles restarts it from
/// the branch currently onstage as the new "old" page; the one before that
/// drops offstage at once. At most two branches are ever onstage.
class BranchTransitionContainer extends StatefulWidget {
  const BranchTransitionContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  /// Index of the branch to show, matching [AppDestination.values].
  final int currentIndex;

  /// One Navigator per branch, in [AppDestination] order. The list itself,
  /// and each child's identity, stay the same across rebuilds; only
  /// [currentIndex] changes.
  final List<Widget> children;

  @override
  State<BranchTransitionContainer> createState() =>
      _BranchTransitionContainerState();
}

class _BranchTransitionContainerState extends State<BranchTransitionContainer>
    with SingleTickerProviderStateMixin {
  // Starts settled (as if a transition had just completed) so the very
  // first build shows the initial branch at rest, with no animation.
  late final AnimationController _controller =
      AnimationController(duration: _transitionDuration, vsync: this, value: 1)
        ..addStatusListener(_onStatus);

  /// The branch being left while [_controller] runs; `null` once it settles,
  /// or before the first switch.
  int? _previousIndex;

  /// Direction of the branch now running (or that last ran). Meaningless
  /// once [_controller] is at `1`, since every offset collapses to zero
  /// then regardless of sign.
  BranchDirection _direction = BranchDirection.none;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _previousIndex != null) {
      setState(() => _previousIndex = null);
    }
  }

  @override
  void didUpdateWidget(BranchTransitionContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex == oldWidget.currentIndex) return;
    // A transition already running (A → B) gets cut short: B (the old
    // widget's current index) becomes the outgoing page for the new leg (B
    // → C), and A — tracked only as the previous previous index — is simply
    // no longer current or previous, so it drops offstage next frame.
    setState(() {
      _previousIndex = oldWidget.currentIndex;
      _direction = branchDirection(
        AppDestination.values[oldWidget.currentIndex],
        AppDestination.values[widget.currentIndex],
      );
    });
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Vertical offset and opacity for the branch at [index] at the current
  /// animation position, given its role ([isCurrent]/[isPrevious]).
  ({double dy, double opacity}) _frame({
    required bool isCurrent,
    required bool isPrevious,
    required bool reducedMotion,
  }) {
    if (!isCurrent && !isPrevious) return (dy: 0, opacity: 1);
    final t = _controller.value;
    final sign = _direction == BranchDirection.towardsBelow ? 1.0 : -1.0;
    if (isCurrent) {
      // Arrives from below (+distance) or above (-distance) down to 0, and
      // fades in over the back part of the animation.
      final eased = Easing.emphasizedDecelerate.transform(t);
      return (
        dy: reducedMotion ? 0 : sign * _slideDistance * (1 - eased),
        opacity: reducedMotion
            ? t
            : const Interval(_crossfadeSplit, 1).transform(t),
      );
    }
    // isPrevious: leaves towards the opposite side, fading out over the
    // front part of the animation.
    final eased = Easing.emphasizedDecelerate.transform(t);
    return (
      dy: reducedMotion ? 0 : -sign * _slideDistance * eased,
      opacity: reducedMotion
          ? 1 - t
          : 1 - const Interval(0, _crossfadeSplit).transform(t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final previousIndex = _previousIndex;
    return ClipRect(
      child: Stack(
        // Fixed order (by index, not by role), so no branch is ever
        // reparented when its role changes between current/previous/idle.
        children: [
          for (var index = 0; index < widget.children.length; index++)
            _branch(
              index: index,
              isCurrent: index == widget.currentIndex,
              isPrevious: index == previousIndex,
              reducedMotion: reducedMotion,
            ),
        ],
      ),
    );
  }

  Widget _branch({
    required int index,
    required bool isCurrent,
    required bool isPrevious,
    required bool reducedMotion,
  }) {
    final onstage = isCurrent || isPrevious;
    // The outgoing page stays paintable (so it can be seen sliding away) but
    // must not take input, focus or be announced; the incoming one keeps
    // ticking from the start, the outgoing one does not.
    final content = TickerMode(
      enabled: isCurrent,
      child: IgnorePointer(
        ignoring: isPrevious,
        child: ExcludeFocus(
          excluding: isPrevious,
          child: ExcludeSemantics(
            excluding: isPrevious,
            child: RepaintBoundary(child: widget.children[index]),
          ),
        ),
      ),
    );
    return KeyedSubtree(
      key: ValueKey(index),
      child: Offstage(
        // A branch that is neither current nor previous is fully paused,
        // same as go_router's own default container.
        offstage: !onstage,
        child: AnimatedBuilder(
          animation: _controller,
          // Rebuilt every tick, but only this small wrapper — [content]
          // (the actual branch, passed as `child`) is built once per frame
          // of the outer widget, not once per animation tick.
          builder: (context, child) {
            final frame = _frame(
              isCurrent: isCurrent,
              isPrevious: isPrevious,
              reducedMotion: reducedMotion,
            );
            return Opacity(
              // `Opacity` itself skips compositing a layer once this is 1,
              // so a settled branch costs nothing extra to paint.
              opacity: frame.opacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, frame.dy),
                child: child,
              ),
            );
          },
          child: content,
        ),
      ),
    );
  }
}
