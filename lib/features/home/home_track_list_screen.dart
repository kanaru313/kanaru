import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart' show TrackListItem;
import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_paths.dart';
import '../../core/player/track.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/song_tile.dart';
import 'home_paged_providers.dart';
import 'home_paged_view.dart';

/// A full list of songs under Home, read page by page. Tapping a song plays
/// the songs loaded so far from it; [header] sits between the title and the
/// list (the "recently added" chips).
class HomeTrackListScreen extends ConsumerWidget {
  const HomeTrackListScreen({
    super.key,
    required this.title,
    required this.emptyText,
    required this.pages,
    this.header,
  });

  final String title;
  final String emptyText;
  final HomeTrackPages pages;
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final covers = ref.watch(coverCacheDirectoryProvider);
    Track trackOf(TrackListItem t) => trackFromItem(
      path: t.path,
      title: t.title,
      artist: t.artist,
      durationMs: t.durationMs,
      artPath: coverPath(covers, t.coverKey),
    );
    final list = HomePagedView<TrackListItem>(
      state: ref.watch(pages),
      onLoadMore: () => ref.read(pages.notifier).loadMore(),
      onRetry: () => ref.read(pages.notifier).retry(),
      emptyIcon: AppIcons.musicNoteOutlined,
      emptyText: emptyText,
      builder: (context, controller, rows) => ListView.builder(
        controller: controller,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: rows.length,
        itemBuilder: (context, i) => SongTile(
          song: rows[i],
          onTap: () => playTracks(ref, [for (final t in rows) trackOf(t)], i),
          onQueueAction: (action) => enqueueLoaded(ref, context, action, [
            trackOf(rows[i]),
          ], rows[i].title),
        ),
      ),
    );
    return PageScaffold(
      title: title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          Expanded(child: list),
        ],
      ),
    );
  }
}
