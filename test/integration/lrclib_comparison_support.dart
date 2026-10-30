import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_search_controller.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';

import '../core/lyrics/online/lookup_test_harness.dart';
import '../core/lyrics_translation/loopback_server.dart';
import 'fake_lrclib.dart';

/// A song to look up, and the record of [lrclibRecords] that is the answer
/// (`null` for a song LRCLIB does not have).
class LrclibSong {
  const LrclibSong(
    this.name,
    this.title,
    this.artist,
    this.seconds, {
    this.bothTexts = false,
  });

  final String name;
  final String title;
  final String artist;
  final int seconds;

  /// The answer has synced and plain lyrics (a plugin keeps one text).
  final bool bothTexts;

  LyricsTarget get target => LyricsTarget.fromFields(
    uri: '/music/$name.flac',
    title: title,
    artist: artist,
    album: 'Album',
    duration: Duration(seconds: seconds),
  );
}

const lrclibSongs = [
  LrclibSong('synced', 'Synced Song', 'Synced Artist', 200, bothTexts: true),
  LrclibSong('plain', 'Plain Song', 'Plain Artist', 180),
  LrclibSong('instrumental', 'Instrumental Song', 'Instrumental Artist', 240),
  LrclibSong('miss', 'Missing Song', 'Nobody', 150),
  // Two artists in the tag: the Dart provider looks up the first and searches
  // by title only.
  LrclibSong(
    'multi',
    'Synced Song',
    'Synced Artist; Guest Star',
    200,
    bothTexts: true,
  ),
  // A record with duration 0 beside one the app refuses whole.
  LrclibSong('zero', 'Zero Song', 'Zero Artist', 150),
];

/// What a lookup stored for a song, without the provider id.
typedef StoredRow = ({
  String status,
  String? remoteId,
  String? synced,
  String? plain,
  bool instrumental,
  int? durationMs,
  int fetchedAt,
});

StoredRow storedRowOf(OnlineLyricsRow row) => (
  status: row.status,
  remoteId: row.remoteId,
  synced: row.syncedText,
  plain: row.plainText,
  instrumental: row.instrumental,
  durationMs: row.remoteDurationMs,
  fetchedAt: row.fetchedAt,
);

StoredRow withoutPlain(StoredRow row) => (
  status: row.status,
  remoteId: row.remoteId,
  synced: row.synced,
  plain: null,
  instrumental: row.instrumental,
  durationMs: row.durationMs,
  fetchedAt: row.fetchedAt,
);

/// What one automatic lookup stored and which requests it sent.
typedef AutoLookup = ({List<StoredRow> rows, List<String> paths});

/// Runs the automatic lookup of [song] at [registration] against [server].
Future<AutoLookup> autoLookup(
  LyricsProviderRegistration registration,
  LrclibSong song,
  LoopbackServer server, {
  LibraryDatabase? database,
}) async {
  server.requests.clear();
  final h = await createHarness(
    [registration],
    client: LrclibRoutingClient(server),
    database: database,
  );
  await h.lookups.start(song.target, auto: true);
  final rows = await h.db.watchOnlineLyrics(song.target.cacheKey).first;
  return (
    rows: [for (final row in rows) storedRowOf(row)],
    paths: [for (final r in server.requests) r.uri.path],
  );
}

/// One entry of the ranked list of a manual search.
typedef RankedEntry = ({
  String remoteId,
  String title,
  String artist,
  String? album,
  int? durationMs,
  bool goodMatch,
});

/// The ranked list a manual search of [song] shows, and the lyrics of the
/// result it selected on its own (`synced`, `plain`, `instrumental`).
typedef ManualSearch = ({
  List<RankedEntry> ranked,
  String? selectedId,
  (String?, String?, bool)? selectedBody,
  List<String> paths,
});

Future<ManualSearch> manualSearch(
  LyricsProviderRegistration registration,
  LrclibSong song,
  LoopbackServer server, {
  LibraryDatabase? database,
}) async {
  server.requests.clear();
  final h = await createHarness(
    [registration],
    client: LrclibRoutingClient(server),
    database: database,
  );
  final provider = lyricsSearchControllerProvider(song.target);
  h.container.listen(provider, (_, _) {});
  await h.container
      .read(provider.notifier)
      .search(lyricsSearchPrefill(song.target));
  final state = h.container.read(provider);
  final body = state.selection?.candidate.body;
  return (
    ranked: [
      for (final r in state.results)
        (
          remoteId: r.candidate.remoteId,
          title: r.candidate.title,
          artist: r.candidate.artist,
          album: r.candidate.album,
          durationMs: r.candidate.duration?.inMilliseconds,
          goodMatch: r.match.goodMatch,
        ),
    ],
    selectedId: state.selection?.candidate.remoteId,
    selectedBody: body == null
        ? null
        : (body.syncedLrc, body.plain, body.instrumental),
    paths: [for (final r in server.requests) r.uri.path],
  );
}
