import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/motion_tab_controller.dart';
import '../queue/queue_panel.dart';
import '../queue/queue_panel_header.dart'
    show queueHeaderActionsWidth, queueHeaderTitlePadding;

enum _SideTab { lyrics, queue }

/// Second column of Split: "Lyrics | Queue" tabs, Lyrics only when the track
/// has [lyrics]. Only the chosen tab's body is built.
///
/// On the Queue tab the tab bar takes the place of the queue header's title,
/// so the queue's actions stay at the end of its row; on the Lyrics tab the
/// bar sits at the same spot over the lyrics.
class NowPlayingSidePane extends StatefulWidget {
  const NowPlayingSidePane({
    super.key,
    this.lyrics,
    this.onQueueMenuOpenChanged,
  });

  /// The lyrics view; `null` when the track has none, and then no tab.
  final Widget? lyrics;

  /// Whether the queue's `⋮` menu is open; see
  /// [QueuePanel.onMenuOpenChanged].
  final ValueChanged<bool>? onQueueMenuOpenChanged;

  @override
  State<NowPlayingSidePane> createState() => _NowPlayingSidePaneState();
}

class _NowPlayingSidePaneState extends State<NowPlayingSidePane>
    with TickerProviderStateMixin {
  /// Moves the tab bar between the two bodies without rebuilding its state.
  final _barKey = GlobalKey(debugLabel: 'Now Playing side tab bar');
  TabController? _built;
  TabController get _tabs => _built!;

  /// The tab the user chose, or the one lyrics coming back select. Without
  /// lyrics the Queue tab shows and this resets to Queue.
  late _SideTab _tab = widget.lyrics != null ? _SideTab.lyrics : _SideTab.queue;

  bool get _hasLyrics => widget.lyrics != null;

  List<_SideTab> get _tabList => [
    if (_hasLyrics) _SideTab.lyrics,
    _SideTab.queue,
  ];

  _SideTab get _shown => _hasLyrics ? _tab : _SideTab.queue;

  /// The tab bar moved the controller: follow it.
  void _onTab() {
    final tab = _tabList[_tabs.index];
    if (tab != _tab) setState(() => _tab = tab);
  }

  /// Keeps the controller's length and index in line with the tabs shown.
  void _syncController() {
    _built = motionTabController(
      context,
      current: _built,
      length: _tabList.length,
      vsync: this,
      onChanged: _onTab,
    );
    final index = _tabList.indexOf(_shown);
    if (_tabs.index != index) _tabs.index = index;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
  }

  @override
  void didUpdateWidget(NowPlayingSidePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Lyrics coming back start on the Lyrics tab again.
    if (oldWidget.lyrics == null && widget.lyrics != null) {
      _tab = _SideTab.lyrics;
    }
    _syncController();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bar = Align(
      alignment: Alignment.centerLeft,
      child: TabBar(
        key: _barKey,
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        tabs: [
          for (final tab in _tabList)
            Tab(
              text: switch (tab) {
                _SideTab.lyrics => l10n.lyricsTab,
                _SideTab.queue => l10n.nowPlayingTabQueue,
              },
            ),
        ],
      ),
    );
    return switch (_shown) {
      _SideTab.queue => QueuePanel(
        title: bar,
        onMenuOpenChanged: widget.onQueueMenuOpenChanged,
      ),
      _SideTab.lyrics => Column(
        children: [
          // The queue header's edges and room for its actions, so the tab
          // bar has the same rect on both tabs.
          Padding(
            padding: queueHeaderTitlePadding,
            child: Row(
              children: [
                Expanded(child: SizedBox(height: 48, child: bar)),
                const SizedBox(width: queueHeaderActionsWidth),
              ],
            ),
          ),
          Expanded(child: widget.lyrics!),
        ],
      ),
    };
  }
}
