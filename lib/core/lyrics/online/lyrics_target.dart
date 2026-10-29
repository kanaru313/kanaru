import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/library_rows.dart';
import '../../database/library_startup.dart';
import '../../database/online_lyrics_queries.dart';
import '../../player/local_path_of.dart';
import '../../player/player_service.dart';
import '../../player/track.dart';
import 'lyrics_match.dart' as match;
import 'lyrics_match_keys.dart';
import 'lyrics_provider.dart';

/// The song online lyrics are looked up for: what identifies it
/// ([trackKey], the local path else the uri), where its `.lrc` file would go
/// ([path]) and what to ask a provider ([query]).
///
/// A title equal to the file name without extension is the placeholder a
/// song gets when it has no title tag; it is dropped, so it is never sent
/// and never part of the cache key.
class LyricsTarget {
  LyricsTarget({required this.trackKey, this.path, required this.query});

  /// A target from the tag fields of the song at [uri]. [path] is the local
  /// file when the uri is one.
  factory LyricsTarget.fromFields({
    required String uri,
    required String? title,
    String? artist,
    String? album,
    Duration? duration,
  }) {
    final path = localPathOf(uri);
    return LyricsTarget(
      trackKey: path ?? uri,
      path: path,
      query: LyricsQuery(
        title: _realTitle(title, path ?? uri),
        artist: _blankToNull(artist),
        album: _blankToNull(album),
        duration: duration,
      ),
    );
  }

  /// From a queue track; its fields may be older than the library's.
  factory LyricsTarget.fromTrack(Track track) => LyricsTarget.fromFields(
    uri: track.uri,
    title: track.title,
    artist: track.artist,
    album: track.album,
    duration: track.duration,
  );

  /// From a library row, e.g. for a menu action.
  factory LyricsTarget.fromListItem(TrackListItem item) =>
      LyricsTarget.fromFields(
        uri: item.path,
        title: item.title,
        artist: item.artist,
        album: item.album,
        duration: item.durationMs == null
            ? null
            : Duration(milliseconds: item.durationMs!),
      );

  final String trackKey;

  /// The local audio file; `null` for a song outside the file system.
  final String? path;
  final LyricsQuery query;

  /// An automatic lookup has what it needs: title, real artist, duration.
  bool get isAutoSearchable => match.isAutoSearchable(query);

  /// Key of this song's rows in the online lyrics cache, computed once.
  late final String cacheKey = onlineLyricsCacheKey(query);

  @override
  bool operator ==(Object other) =>
      other is LyricsTarget &&
      other.trackKey == trackKey &&
      other.path == path &&
      other.query.title == query.title &&
      other.query.artist == query.artist &&
      other.query.album == query.album &&
      other.query.duration == query.duration;

  @override
  int get hashCode => Object.hash(
    trackKey,
    path,
    query.title,
    query.artist,
    query.album,
    query.duration,
  );

  @override
  String toString() => 'LyricsTarget($trackKey)';
}

String? _blankToNull(String? text) {
  final trimmed = text?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _realTitle(String? title, String location) {
  final trimmed = _blankToNull(title);
  if (trimmed == null) return null;
  return trimmed == Track.fromPath(location).title ? null : trimmed;
}

/// The target of the playing track, `null` when nothing plays. A library
/// song takes its fields from the library row (fresh after a rescan, even
/// when the queue holds an older [Track]); any other track, and a missing
/// library, use the track's own fields.
final lyricsTargetProvider = StreamProvider.autoDispose<LyricsTarget?>((ref) {
  final track = ref.watch(playerServiceProvider.select((s) => s.queue.current));
  final fromTrack = track == null ? null : LyricsTarget.fromTrack(track);
  if (fromTrack == null) return Stream.value(null);
  final path = fromTrack.path;
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null || path == null) return Stream.value(fromTrack);
  return db
      .watchTrackLyricsFields(path)
      .map(
        (f) => f == null
            ? fromTrack
            : LyricsTarget.fromFields(
                uri: path,
                title: f.title,
                artist: f.artist,
                album: f.album,
                duration: f.durationMs == null
                    ? null
                    : Duration(milliseconds: f.durationMs!),
              ),
      )
      .distinct();
}, retry: (_, _) => null);
