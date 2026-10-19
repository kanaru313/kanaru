import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import 'now_playing_compact_page.dart';
import 'now_playing_footer.dart' show nowPlayingHeaderHeight;

/// Pages of the narrow layout, left to right. Lyrics will join on the right.
enum _Tab { queue, track }

const _pageDuration = Duration(milliseconds: 300);

/// Narrow layout: dot tabs on top over horizontally swiped pages, the queue
/// on the left and the playing track (the start page) on the right.
class NowPlayingTabs extends StatefulWidget {
  const NowPlayingTabs({
    super.key,
    required this.wrapHeader,
    required this.queuePage,
    required this.onClose,
  });

  /// Adds the window drag area and buttons around the tab header.
  final Widget Function(Widget header) wrapHeader;

  /// The queue page: filled by the queue panel.
  final Widget queuePage;
  final VoidCallback onClose;

  @override
  State<NowPlayingTabs> createState() => _NowPlayingTabsState();
}

class _NowPlayingTabsState extends State<NowPlayingTabs> {
  final _controller = PageController(initialPage: _Tab.track.index);
  int _page = _Tab.track.index;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(_Tab tab) => _controller.animateToPage(
    tab.index,
    duration: _pageDuration,
    curve: Curves.easeOutQuart,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      _Tab.queue: l10n.nowPlayingTabQueue,
      _Tab.track: l10n.nowPlayingTabTrack,
    };
    return Column(
      children: [
        widget.wrapHeader(
          SizedBox(
            height: nowPlayingHeaderHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final tab in _Tab.values)
                  _Dot(
                    label: labels[tab]!,
                    selected: _page == tab.index,
                    onTap: () => _select(tab),
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
              NowPlayingCompactPage(
                onClose: widget.onClose,
                onShowQueue: () => _select(_Tab.queue),
              ),
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
                duration: _pageDuration,
                curve: Curves.easeOutQuart,
                child: AnimatedContainer(
                  duration: _pageDuration,
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
