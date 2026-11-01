import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_browse_album_links.dart';
import '../../core/database/library_keys_provider.dart';
import '../../core/database/library_startup.dart';
import '../artist_page/artist_page_sections.dart';
import '../artist_page/read_artist_sections.dart';

/// What the artist modal links to: the sections of the artist page (own
/// albums, appears on, songs in page order, preferred name) and the local
/// folders of those songs.
typedef ArtistLinks = ({
  ArtistPageSections sections,
  List<AlbumFolder> folders,
});

/// The links of one artist (by key); read once when the modal opens and not
/// refreshed by rescans while it is open. Null without a library or when no
/// track credits the artist. Waits (stays pending) while the library keys are
/// being rewritten, then reads afresh once they are ready: a change of the
/// split rules or album grouping turns the keys not ready and then ready, so
/// the provider reads again (and may become null). A failed read is
/// not retried, so the rows grey out.
final artistModalLinksProvider = FutureProvider.autoDispose
    .family<ArtistLinks?, String>((ref, artistKey) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Future.value(null);
      // Keys are rewritten while not ready: wait, then read afresh.
      if (!ref.watch(keysReadyProvider)) {
        return Completer<ArtistLinks?>().future;
      }
      return readArtistSections(db, artistKey).then(
        (sections) => sections == null
            ? null
            : (
                sections: sections,
                folders: albumFoldersOf([
                  for (final t in sections.songs) t.path,
                ]),
              ),
      );
    }, retry: (_, _) => null);
