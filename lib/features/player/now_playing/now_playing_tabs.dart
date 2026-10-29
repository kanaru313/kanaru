import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../lyrics/translation/lyrics_translation_button.dart';
import '../queue/queue_button.dart';
import 'now_playing_actions.dart';
import 'now_playing_compact_page.dart';
import 'now_playing_header.dart' show nowPlayingHeaderHeight;
import 'now_playing_title_bar.dart';

/// Pages of the narrow layout, left to right. Lyrics only when the track has
/// them.
enum _Tab { queue, track, lyrics }

const _pageDuration = Duration(milliseconds: 300);

/// Narrow layout: dot tabs on top over horizontally swiped pages, the queue
/// on the left, the playing track (the start page) in the middle and, when
/// the track has lyrics, the lyrics on the right. Close and queue buttons
/// sit at the top left of the header.
class NowPlayingTabs extends StatefulWidget {
  const NowPlayingTabs({
    super.key,
    required this.wrapHeader,
    required this.excludeFromDrag,
    required this.queuePage,
    required this.onClose,
    this.lyricsPage,
  });

  /// Adds the window drag area and buttons around the tab header.
  final Widget Function(Widget header) wrapHeader;

  /// Wraps the header buttons so pressing them leaves the window alone.
  final NowPlayingDragExclusion excludeFromDrag;

  /// The queue page: filled by the queue panel.
  final Widget queuePage;
  final VoidCallback onClose;

  /// The lyrics page; `null` when the track has none, and then no tab.
  final Widget? lyricsPage;

  @override
  State<NowPlayingTabs> createState() => _NowPlayingTabsState();
}

class _NowPlayingTabsState extends State<NowPlayingTabs> {
  final _controller = PageController(initialPage: _Tab.track.index);
  int _page = _Tab.track.index;

  @override
  void didUpdateWidget(NowPlayingTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The lyrics page went away while shown: land on the track, not on a
    // page that no longer exists.
    if (widget.lyricsPage == null && _page == _Tab.lyrics.index) {
      _page = _Tab.track.index;
      if (_controller.hasClients) _controller.jumpToPage(_page);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(_Tab tab) {
    // animateToPage refuses a zero duration.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(tab.index);
      return;
    }
    _controller.animateToPage(
      tab.index,
      duration: _pageDuration,
      curve: Curves.easeOutQuart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lyricsPage = widget.lyricsPage;
    final tabs = [_Tab.queue, _Tab.track, if (lyricsPage != null) _Tab.lyrics];
    final labels = {
      _Tab.queue: l10n.nowPlayingTabQueue,
      _Tab.track: l10n.nowPlayingTabTrack,
      _Tab.lyrics: l10n.lyricsTab,
    };
    return Column(
      children: [
        // The wrapper adds the window buttons beside the header, so the dots
        // are laid over the whole row instead of inside it: they then center
        // on the window. The dots' Center only hit-tests the dots themselves,
        // so the rest of the strip still drags the window.
        Stack(
          children: [
            widget.wrapHeader(
              SizedBox(
                height: nowPlayingHeaderHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: widget.excludeFromDrag(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NowPlayingCloseButton(onPressed: widget.onClose),
                          // On the queue page the same spot leads back.
                          if (_page == _Tab.queue.index)
                            IconButton(
                              icon: const Icon(AppIcons.back),
                              tooltip: l10n.nowPlayingBackToTrack,
                              onPressed: () => _select(_Tab.track),
                            )
                          else
                            QueueButton(onPressed: () => _select(_Tab.queue)),
                          if (lyricsPage != null)
                            const LyricsTranslationButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final tab in tabs)
                      _Dot(
                        label: labels[tab]!,
                        selected: _page == tab.index,
                        onTap: () => _select(tab),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: PageView(
            controller: _controller,
            onPageChanged: (page) => setState(() => _page = page),
            children: [
              widget.queuePage,
              const NowPlayingCompactPage(),
              ?lyricsPage,
            ],
          ),
        ),
      ],
    );
  }
}

/// One tab: a 6 px dot, or a 16 × 6 bar when selected. Hovering enlarges it
/// a little and shows the tab name.
class _Dot extends StatefulWidget {
  const _Dot({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _pageDuration;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            // A roomy hit area around the tiny indicator.
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: AnimatedScale(
                scale: _hovered ? 1.3 : 1,
                duration: duration,
                curve: Curves.easeOutQuart,
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutQuart,
                  width: widget.selected ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? colors.primary
                        : colors.onSurfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(
                      widget.selected ? 4 : 3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
