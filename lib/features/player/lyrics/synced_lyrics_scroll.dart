import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Where the current line sits in the view: 40% down from the top.
const lyricsAnchor = 0.4;

/// How long auto-scroll waits after the user last scrolled by hand.
const lyricsManualScrollPause = Duration(seconds: 3);

/// How long the glide to a new current line takes. It matches the line's own
/// style change, so the view stops drawing frames when both are done.
const _scrollDuration = Duration(milliseconds: 200);

/// The scrolling of the synced lyrics view: keeping the current line at
/// [lyricsAnchor] and telling the user's scrolling from the view's own. The
/// state that mixes it in sets [lineKeys] and [lineIndex].
mixin SyncedLyricsScroll<T extends StatefulWidget> on State<T> {
  final scroll = ScrollController();

  /// One key per line, to find its render object.
  late List<GlobalKey> lineKeys;

  /// The current line, -1 before the first.
  int lineIndex = -1;

  /// Set while this view moves its own scroll position, so that move is not
  /// taken for the user's.
  bool scrollingItself = false;

  /// Counts this view's own scrolls: an animation replaced by a newer one
  /// completes early and must not clear [scrollingItself] for the newer.
  int _scrollGeneration = 0;

  /// Running while auto-scroll is paused after a manual scroll.
  Timer? resume;
  double? _viewportHeight;

  /// Cancels the timer and the controller; call from `dispose`.
  void disposeScroll() {
    resume?.cancel();
    scroll.dispose();
  }

  /// Scrolls so the current line (the first before any) sits at the anchor.
  void reveal({required bool animate}) {
    if (!scroll.hasClients || lineKeys.isEmpty) return;
    final object = lineKeys[lineIndex < 0 ? 0 : lineIndex].currentContext
        ?.findRenderObject();
    if (object == null || !object.attached) return;
    final position = scroll.position;
    final target = RenderAbstractViewport.of(object)
        .getOffsetToReveal(object, lyricsAnchor)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 0.5) return;
    scrollingItself = true;
    final generation = ++_scrollGeneration;
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      scroll.jumpTo(target);
      scrollingItself = false;
      return;
    }
    scroll
        .animateTo(
          target,
          duration: _scrollDuration,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (generation != _scrollGeneration) return;
          scrollingItself = false;
        });
  }

  /// Puts the current line back at the anchor after this frame, unless the
  /// user scrolled by hand a moment ago.
  void revealAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && resume == null) reveal(animate: false);
    });
  }

  /// Scroll listener: a scroll the view did not start itself pauses
  /// auto-scroll for [lyricsManualScrollPause].
  bool onScrollUpdate(ScrollUpdateNotification notification) {
    final byUser = notification.dragDetails != null || !scrollingItself;
    if (notification.depth == 0 && byUser) {
      resume?.cancel();
      resume = Timer(lyricsManualScrollPause, () {
        resume = null;
        if (mounted) reveal(animate: true);
      });
    }
    return false;
  }

  /// First layout and window resizes: put the line back without animation.
  void onViewportHeight(double height) {
    if (height == _viewportHeight) return;
    _viewportHeight = height;
    revealAfterLayout();
  }
}
