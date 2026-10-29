import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/motion_tab_controller.dart';
import '../queue/queue_panel.dart';
import '../queue/queue_panel_header.dart'
    show queueHeaderTitleRowHeight, queueHeaderTitleRowPadding;
import 'now_playing_side_tab.dart';

/// Second column of Split: "Lyrics | Queue" tabs, both always there. Only the
/// chosen tab's body is built.
///
/// On the Queue tab the tab bar takes the place of the queue header's title,
/// so the queue's actions stay at the end of its row; on the Lyrics tab the
/// bar sits at the same spot over the lyrics. The tab the user picked is kept
/// for the app session ([nowPlayingSideTabProvider]), across track changes.
class NowPlayingSidePane extends ConsumerStatefulWidget {
  const NowPlayingSidePane({super.key, required this.lyrics});

  /// The lyrics view, shown on the Lyrics tab.
  final Widget lyrics;

  @override
  ConsumerState<NowPlayingSidePane> createState() => _NowPlayingSidePaneState();
}

class _NowPlayingSidePaneState extends ConsumerState<NowPlayingSidePane>
    with TickerProviderStateMixin {
  /// Moves the tab bar between the two bodies without rebuilding its state.
  final _barKey = GlobalKey(debugLabel: 'Now Playing side tab bar');
  TabController? _built;
  TabController get _tabs => _built!;

  static const _tabList = NowPlayingSideTab.values;

  /// The tab bar moved the controller: follow it.
  void _onTab() {
    final tab = _tabList[_tabs.index];
    if (tab != ref.read(nowPlayingSideTabProvider)) {
      ref.read(nowPlayingSideTabProvider.notifier).choose(tab);
    }
  }

  /// Keeps the controller's length and index in line with the chosen tab.
  void _syncController() {
    _built = motionTabController(
      context,
      current: _built,
      length: _tabList.length,
      vsync: this,
      onChanged: _onTab,
    );
    final index = _tabList.indexOf(ref.read(nowPlayingSideTabProvider));
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
    final shown = ref.watch(nowPlayingSideTabProvider);
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
                NowPlayingSideTab.lyrics => l10n.lyricsTab,
                NowPlayingSideTab.queue => l10n.nowPlayingTabQueue,
              },
            ),
        ],
      ),
    );
    return switch (shown) {
      NowPlayingSideTab.queue => QueuePanel(title: bar),
      NowPlayingSideTab.lyrics => Column(
        children: [
          // The queue header's first row, so the tab bar has the same rect
          // on both tabs.
          Padding(
            padding: queueHeaderTitleRowPadding,
            child: SizedBox(height: queueHeaderTitleRowHeight, child: bar),
          ),
          Expanded(child: widget.lyrics),
        ],
      ),
    };
  }
}
