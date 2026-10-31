import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../lyrics/source/lyrics_source_button.dart';
import '../lyrics/translation/lyrics_translation_button.dart';
import '../queue/queue_button.dart';
import 'now_playing_actions.dart';
import 'now_playing_compact_page.dart';
import 'now_playing_header.dart' show nowPlayingHeaderHeight;
import 'now_playing_tab_dot.dart';
import 'now_playing_tab_header_layout.dart';
import 'now_playing_title_bar.dart';

/// Pages of the narrow layout, left to right.
enum _Tab { queue, track, lyrics }

/// Narrow layout: dot tabs on top over horizontally swiped pages, the queue
/// on the left, the playing track (the start page) in the middle and the
/// lyrics on the right. Close and queue buttons
/// sit at the top left of the header.
class NowPlayingTabs extends StatefulWidget {
  const NowPlayingTabs({
    super.key,
    required this.wrapHeader,
    required this.excludeFromDrag,
    required this.queuePage,
    required this.onClose,
    required this.lyricsPage,
    required this.hasLyrics,
    required this.floatingOpen,
    this.sourceMenuOpener,
  });

  /// Adds the window drag area and buttons around the tab header.
  final Widget Function(Widget header) wrapHeader;

  /// Wraps the header buttons so pressing them leaves the window alone.
  final NowPlayingDragExclusion excludeFromDrag;

  /// The queue page: filled by the queue panel.
  final Widget queuePage;
  final VoidCallback onClose;

  /// The lyrics page, always there: a track without lyrics shows the empty
  /// state in it.
  final Widget lyricsPage;

  /// Whether the song has lyrics to translate; gates the translate button.
  final bool hasLyrics;

  /// Set to whether the translation or lyrics source menu is open; the
  /// screen reads it to leave its keys to the menu.
  final ValueNotifier<bool> floatingOpen;

  /// Receives the callback that opens the lyrics source menu while its button
  /// is in the header.
  final ValueNotifier<bool Function()?>? sourceMenuOpener;

  @override
  State<NowPlayingTabs> createState() => _NowPlayingTabsState();
}

class _NowPlayingTabsState extends State<NowPlayingTabs> {
  final _controller = PageController(initialPage: _Tab.track.index);
  int _page = _Tab.track.index;
  bool _translateOpen = false;
  bool _sourceOpen = false;

  void _report() => widget.floatingOpen.value = _translateOpen || _sourceOpen;

  @override
  void dispose() {
    // The menus leave with the header: give the pin back.
    _translateOpen = false;
    _sourceOpen = false;
    _report();
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
      duration: nowPlayingTabDuration,
      curve: Curves.easeOutQuart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const tabs = _Tab.values;
    final labels = {
      _Tab.queue: l10n.nowPlayingTabQueue,
      _Tab.track: l10n.nowPlayingTabTrack,
      _Tab.lyrics: l10n.lyricsTab,
    };
    return Column(
      children: [
        // The wrapper adds the window buttons beside the header, so the dots
        // center on the window (not on the header) through the layout
        // delegate, which also keeps a drag strip after the buttons. Both
        // groups are excluded from the window drag; the empty strip around
        // them still drags and maximizes. The header starts at the window's
        // left edge (the overlay covers the window), so the window's center
        // is half the window width.
        widget.wrapHeader(
          SizedBox(
            height: nowPlayingHeaderHeight,
            child: CustomMultiChildLayout(
              delegate: NowPlayingTabHeaderLayout(
                windowCenterX: MediaQuery.sizeOf(context).width / 2,
              ),
              children: [
                LayoutId(
                  id: NowPlayingTabHeaderSlot.left,
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
                        LyricsTranslationButton(
                          enabled: widget.hasLyrics,
                          onMenuChanged: (open) {
                            _translateOpen = open;
                            _report();
                          },
                        ),
                        LyricsSourceButton(
                          menuOpener: widget.sourceMenuOpener,
                          onMenuChanged: (open) {
                            _sourceOpen = open;
                            _report();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                LayoutId(
                  id: NowPlayingTabHeaderSlot.dots,
                  child: widget.excludeFromDrag(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final tab in tabs)
                          NowPlayingTabDot(
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
          ),
        ),
        Expanded(
          child: PageView(
            controller: _controller,
            onPageChanged: (page) => setState(() => _page = page),
            children: [
              widget.queuePage,
              const NowPlayingCompactPage(),
              widget.lyricsPage,
            ],
          ),
        ),
      ],
    );
  }
}
