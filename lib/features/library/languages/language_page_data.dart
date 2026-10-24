import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/language_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/text_keys.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../../../shared/library_browse_refresh.dart';
import '../../../shared/sort_compare.dart';
import '../albums/album_tile_data.dart';
import 'languages_provider.dart';

/// What a language page shows: the fallback name of the language (see
/// `LanguageSummary.name`), the albums holding at least one of its tracks
/// (each as the Albums list shows it) and its tracks by title.
class LanguagePageData {
  const LanguagePageData({
    required this.name,
    required this.albums,
    required this.tracks,
  });

  final String name;
  final List<AlbumTileData> albums;
  final List<BrowseTrack> tracks;
}

/// What the page needs of a language from the Languages list: its name and
/// the stored strings that name it. Equal when both are, so a list reload
/// that changes neither leaves the page alone.
class _LanguageRaws {
  const _LanguageRaws(this.name, this.raws);

  final String name;
  final List<String> raws;

  @override
  bool operator ==(Object other) =>
      other is _LanguageRaws &&
      other.name == name &&
      listEquals(other.raws, raws);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(raws));
}

/// Reads the page of the language called [name], held by the stored strings
/// [raws], in one transaction. Null when no track is left in it.
Future<LanguagePageData?> readLanguagePage(
  LibraryDatabase db,
  String name,
  List<String> raws,
) => db.transaction(() async {
  final (tracks, albums) = await (
    db.languageTracks(raws),
    db.languageAlbums(raws),
  ).wait;
  if (tracks.isEmpty) return null;
  albums.sort(_byTitle);
  return LanguagePageData(
    name: name,
    albums: [for (final a in albums) AlbumTileData.fromSummary(a)],
    tracks: tracks,
  );
});

/// Title sort key, then the album key.
int _byTitle(AlbumSummary a, AlbumSummary b) {
  final title = compareCodePoints(
    a.titleSort ?? sortKey(a.title),
    b.titleSort ?? sortKey(b.title),
  );
  if (title != 0) return title;
  final artist = compareCodePoints(a.key.artistKey, b.key.artistKey);
  return artist != 0
      ? artist
      : compareCodePoints(a.key.titleKey, b.key.titleKey);
}

/// The page of one language (by key), reloaded at most every
/// [libraryBrowseRefreshIntervalProvider] while the library changes. The
/// stored strings of the language come from [languagesProvider] (shared with
/// the list); it follows them when a retag adds or drops one. Null when no
/// track has the language any more. Disposed when its page closes.
final languagePageProvider = StreamProvider.autoDispose
    .family<LanguagePageData?, String>((ref, languageKey) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(null);
      final language = ref.watch(
        languagesProvider.select(
          (languages) => languages.whenData((list) {
            final found = list.where((l) => l.key == languageKey).firstOrNull;
            return found == null ? null : _LanguageRaws(found.name, found.raws);
          }),
        ),
      );
      if (language.hasError) {
        return Stream.error(language.error!, language.stackTrace!);
      }
      // Not loaded yet (or the keys are still being made).
      if (!language.hasValue) return const Stream.empty();
      final raws = language.requireValue;
      if (raws == null) return Stream.value(null);
      return throttledTracksQuery(
        db,
        () => readLanguagePage(db, raws.name, raws.raws),
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      );
    });
