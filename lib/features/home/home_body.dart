import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart';
import '../../l10n/l10n.dart';
import 'home_added_window_chips.dart';
import 'home_data_version.dart';
import 'home_album_card.dart';
import 'home_artist_card.dart';
import 'home_providers.dart';
import 'home_section.dart';
import 'home_shelf.dart';
import 'home_tile_metrics.dart';
import 'home_track_card.dart';

/// Cards drawn while a shelf reads for the first time, so the page keeps its
/// height.
const _placeholderCount = 8;

/// The five sections of Home, always in this order.
class HomeBody extends ConsumerStatefulWidget {
  const HomeBody({super.key});

  @override
  ConsumerState<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<HomeBody> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The window regained focus, maybe the next day: read the day again.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(homeDataVersionProvider.notifier).checkDay(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CustomScrollView(
      slivers: [
        SliverList.list(
          children: [
            HomeSection(
              title: l10n.homeRecentlyPlayedTitle,
              child: _tracks(ref.watch(homeRecentlyPlayedProvider)),
            ),
            HomeSection(
              title: l10n.homeRecentlyAddedTitle,
              below: const HomeAddedWindowChips(),
              child: _tracks(ref.watch(homeRecentlyAddedProvider)),
            ),
            HomeSection(
              title: l10n.homeMemoriesTitle,
              child: _tracks(
                ref.watch(homeMemoriesProvider),
                emptyText: l10n.homeMemoriesEmpty,
              ),
            ),
            HomeSection(
              title: l10n.homeRecentAlbumsTitle,
              child: _row<AlbumSummary>(
                ref.watch(homeRecentAlbumsProvider),
                (_, items, i) => HomeAlbumCard(album: items[i]),
              ),
            ),
            HomeSection(
              title: l10n.homeRecentArtistsTitle,
              child: _row<ArtistCredit>(
                ref.watch(homeRecentArtistsProvider),
                (_, items, i) => HomeArtistCard(artist: items[i]),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ],
    );
  }

  Widget _tracks(AsyncValue<List<TrackListItem>> async, {String? emptyText}) =>
      _row<TrackListItem>(
        async,
        (_, items, i) => HomeTrackCard(row: items, index: i),
        emptyText: emptyText,
      );

  /// The row for [async]: the last rows read (kept while reading again or
  /// after a failure), placeholders on the first read, and, with nothing to
  /// show, a gap. [emptyText] is shown only when a read finished with no rows.
  Widget _row<T>(
    AsyncValue<List<T>> async,
    Widget Function(BuildContext, List<T>, int) card, {
    String? emptyText,
  }) {
    final items = async.value;
    if (items == null) {
      if (!async.isLoading) return const SizedBox(height: 8);
      return HomeShelf(
        itemCount: _placeholderCount,
        itemBuilder: (_, _) => const HomeCardPlaceholder(),
      );
    }
    if (items.isEmpty) {
      return emptyText == null
          ? const SizedBox(height: 8)
          : _EmptyRowText(emptyText);
    }
    return HomeShelf(
      itemCount: items.length,
      itemBuilder: (context, i) => card(context, items, i),
    );
  }
}

class _EmptyRowText extends StatelessWidget {
  const _EmptyRowText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
