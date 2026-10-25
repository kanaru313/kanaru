import 'package:material_ui/material_ui.dart';

import 'now_playing_auto_hide.dart';
import 'now_playing_header.dart';
import 'now_playing_side_pane.dart';
import 'now_playing_split_geometry.dart';
import 'now_playing_title_bar.dart';
import 'now_playing_track_column.dart';

/// Wide Now Playing: the auto-hiding header over Split, the track column
/// beside the tabs for lyrics and the queue.
class NowPlayingWideLayout extends StatelessWidget {
  const NowPlayingWideLayout({
    super.key,
    required this.chrome,
    required this.floatingOpen,
    required this.onClose,
    this.titleBar,
    this.lyrics,
  });

  final AutoHideController chrome;

  /// See [NowPlayingHeader.floatingOpen].
  final ValueNotifier<bool> floatingOpen;
  final VoidCallback onClose;
  final NowPlayingTitleBar? titleBar;

  /// The lyrics view; `null` when the track has none.
  final Widget? lyrics;

  @override
  Widget build(BuildContext context) {
    final header = NowPlayingHeader(
      onClose: onClose,
      excludeFromDrag: titleBar?.excludeFromDrag ?? noDragExclusion,
      floatingOpen: floatingOpen,
      hasWindowButtons: titleBar?.hasWindowButtons ?? false,
    );
    return AutoHideRegion(
      controller: chrome,
      child: Column(
        children: [
          AutoHide(
            controller: chrome,
            child: titleBar?.wrapHeader(header) ?? header,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  SizedBox(
                    width: splitColumnWidth(constraints.maxWidth),
                    child: NowPlayingTrackColumn(chrome: chrome),
                  ),
                  Expanded(child: NowPlayingSidePane(lyrics: lyrics)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
