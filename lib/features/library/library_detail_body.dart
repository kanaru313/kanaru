import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart';
import '../../core/database/library_startup.dart';
import 'songs/songs_empty_view.dart';
import 'widgets/library_loading.dart';
import 'widgets/page_material.dart';

final _log = Logger('library');

/// Body of the album and artist pages: library unavailable, loading, a
/// failed read (logged; once tracks were shown they stay), "not found" (a
/// broken key, given as a null [tracks], or no tracks left), or the page.
class LibraryDetailBody extends ConsumerWidget {
  const LibraryDetailBody({
    super.key,
    required this.tracks,
    required this.what,
    required this.notFound,
    required this.builder,
  });

  final ProviderListenable<AsyncValue<List<BrowseTrack>>>? tracks;

  /// What is read, for the log ("the album").
  final String what;
  final Widget notFound;
  final Widget Function(List<BrowseTrack> tracks) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = this.tracks;
    final Widget body;
    if (ref.watch(libraryDatabaseProvider) == null) {
      body = const SongsEmptyView(kind: SongsEmptyKind.unavailable);
    } else if (tracks == null) {
      body = notFound;
    } else {
      ref.listen(tracks, (previous, next) {
        if (next.hasError && !(previous?.hasError ?? false)) {
          _log.severe('Reading $what failed', next.error, next.stackTrace);
        }
      });
      body = ref
          .watch(tracks)
          .when(
            skipLoadingOnReload: true,
            skipError: true,
            loading: () => const LibraryLoading(),
            error: (error, stackTrace) =>
                const SongsEmptyView(kind: SongsEmptyKind.unavailable),
            data: (list) => list.isEmpty ? notFound : builder(list),
          );
    }
    return PageMaterial(child: body);
  }
}
