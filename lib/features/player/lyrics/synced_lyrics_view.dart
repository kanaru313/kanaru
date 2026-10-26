import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/lyrics.dart';
import '../../../core/player/player_service.dart';
import 'lyrics_line.dart';
import 'lyrics_text_style.dart';

/// Where the current line sits in the view: 40% down from the top.
const lyricsAnchor = 0.4;

/// How long auto-scroll waits after the user last scrolled by hand.
const lyricsManualScrollPause = Duration(seconds: 3);

/// How long the glide to a new current line takes. It matches the line's own
/// style change, so the view stops drawing frames when both are done.
const _scrollDuration = Duration(milliseconds: 200);

/// Synced lyrics that follow playback, centered: the current line is
/// highlighted and kept at [lyricsAnchor]; scrolling by hand pauses that
/// for [lyricsManualScrollPause]; pressing a line seeks to it.
///
/// Position ticks cost one binary search: only a change of the current line
/// flips two per-line notifiers, so two lines rebuild and nothing else.
/// Every line is built (a column, lyrics are short and capped), so any line
/// can be scrolled to. Only this view's own scroll position moves, never an
/// enclosing one such as the narrow layout's page view.
class SyncedLyricsView extends ConsumerStatefulWidget {
  const SyncedLyricsView({super.key, required this.lyrics});

  final Lyrics lyrics;

  @override
  ConsumerState<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends ConsumerState<SyncedLyricsView> {
  final _scroll = ScrollController();
  late final List<GlobalKey> _keys;
  late final List<ValueNotifier<bool>> _current;
  int _index = -1;

  /// Set while this view moves its own scroll position, so that move is not
  /// taken for the user's.
  bool _scrollingItself = false;

  /// Counts this view's own scrolls: an animation replaced by a newer one
  /// completes early and must not clear [_scrollingItself] for the newer.
  int _scrollGeneration = 0;

  /// Running while auto-scroll is paused after a manual scroll.
  Timer? _resume;
  double? _viewportHeight;

  @override
  void initState() {
    super.initState();
    final count = widget.lyrics.lines.length;
    _keys = List.generate(count, (_) => GlobalKey());
    _current = List.generate(count, (_) => ValueNotifier(false));
    _setIndex(widget.lyrics.lineAt(ref.read(playerServiceProvider).position));
  }

  @override
  void dispose() {
    _resume?.cancel();
    _scroll.dispose();
    for (final notifier in _current) {
      notifier.dispose();
    }
    super.dispose();
  }

  void _setIndex(int index) {
    if (_index >= 0) _current[_index].value = false;
    _index = index;
    if (index >= 0) _current[index].value = true;
  }

  void _onLineChanged(int index) {
    if (index == _index) return;
    _setIndex(index);
    if (_resume == null) _reveal(animate: true);
  }

  /// Scrolls so the current line (the first before any) sits at the anchor.
  void _reveal({required bool animate}) {
    if (!_scroll.hasClients || _keys.isEmpty) return;
    final object = _keys[_index < 0 ? 0 : _index].currentContext
        ?.findRenderObject();
    if (object == null || !object.attached) return;
    final position = _scroll.position;
    final target = RenderAbstractViewport.of(object)
        .getOffsetToReveal(object, lyricsAnchor)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 0.5) return;
    _scrollingItself = true;
    final generation = ++_scrollGeneration;
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
      _scrollingItself = false;
      return;
    }
    _scroll
        .animateTo(
          target,
          duration: _scrollDuration,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (generation == _scrollGeneration) _scrollingItself = false;
        });
  }

  bool _onScroll(ScrollUpdateNotification notification) {
    final byUser = notification.dragDetails != null || !_scrollingItself;
    if (notification.depth == 0 && byUser) {
      _resume?.cancel();
      _resume = Timer(lyricsManualScrollPause, () {
        _resume = null;
        if (mounted) _reveal(animate: true);
      });
    }
    return false;
  }

  void _seek(int index) {
    _resume?.cancel();
    _resume = null;
    final before = _index;
    ref
        .read(playerServiceProvider.notifier)
        .seek(widget.lyrics.lines[index].time);
    // Seeking moves the position at once, which moves the current line and
    // scrolls; a press on the current line only brings it back.
    if (_index == before) _reveal(animate: true);
  }

  void _onViewportHeight(double height) {
    if (height == _viewportHeight) return;
    _viewportHeight = height;
    // First layout and window resizes: put the line back without animation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _resume == null) _reveal(animate: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = widget.lyrics;
    ref.listen(
      playerServiceProvider.select((s) => lyrics.lineAt(s.position)),
      (_, index) => _onLineChanged(index),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        _onViewportHeight(height);
        return NotificationListener<ScrollUpdateNotification>(
          onNotification: _onScroll,
          // Desktop platforms give every scrollable a scrollbar that fades in
          // and out on each scroll. Auto-scroll would flash it at every line
          // change: about 20 more frames each, more than the glide itself. So
          // the view has its own, which ignores the view's own scrolling.
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(scrollbars: false),
            child: Scrollbar(
              controller: _scroll,
              notificationPredicate: (notification) =>
                  notification.depth == 0 && !_scrollingItself,
              child: SingleChildScrollView(
                controller: _scroll,
                // Room above and below so the first and last lines can reach
                // the anchor.
                padding: EdgeInsets.fromLTRB(
                  lyricsSidePadding - 12,
                  height * lyricsAnchor,
                  lyricsSidePadding - 12,
                  height * (1 - lyricsAnchor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < lyrics.lines.length; i++)
                      LyricsLine(
                        key: _keys[i],
                        line: lyrics.lines[i],
                        current: _current[i],
                        onTap: () => _seek(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
