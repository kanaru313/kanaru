import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_startup.dart';
import '../database/online_lyrics_queries.dart';
import 'lyrics.dart';
import 'online/lyrics_provider_registry.dart';
import 'online/lyrics_source_names.dart';
import 'online/lyrics_target.dart';
import 'online/online_lyrics_resolution.dart';
import 'online/online_lyrics_streams.dart';
import 'online/playing_lyrics_status.dart';
import 'track_local_lyrics_provider.dart';

final _log = Logger('track_lyrics_preview');

/// Where the lyrics of a [TrackLyricsPreview] came from.
enum TrackLyricsKind { sidecar, embedded, online }

/// The lyrics a library song shows, and where they came from.
class TrackLyricsPreview {
  const TrackLyricsPreview({required this.lyrics, this.onlineProviderId});

  final Lyrics lyrics;

  /// The source of online lyrics (picked or cached); null for the song's own.
  final String? onlineProviderId;

  TrackLyricsKind get kind => onlineProviderId != null
      ? TrackLyricsKind.online
      : switch (lyrics.source) {
          LyricsSource.sidecar => TrackLyricsKind.sidecar,
          LyricsSource.embedded => TrackLyricsKind.embedded,
        };
}

/// The target of the library song at a path, from its row; null when the
/// path is not in the library.
final _trackTargetProvider = StreamProvider.autoDispose
    .family<LyricsTarget?, String>((ref, path) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(null);
      return db
          .watchTrackLyricsFields(path)
          .map(
            (f) => f == null ? null : LyricsTarget.fromLibraryFields(path, f),
          )
          .distinct();
    }, retry: (_, _) => null);

/// The lyrics Now Playing would show for the local song at [path], without
/// playing it: the same order (the user's choice and pick, then the song's
/// own `.lrc` or tags, then the saved online answers), because it calls the
/// same [resolveChoice].
///
/// It only reads. Unlike Now Playing it never starts an online lookup: a
/// song with nothing saved resolves to `null`, so opening a song's details
/// sends no request. Loading while anything is still being read for the first
/// time (a reload keeps the last value); `null`
/// data when the song has no lyrics or the user turned them off. Without a
/// library only the song's own lyrics count.
final trackLyricsPreviewProvider = Provider.autoDispose
    .family<AsyncValue<TrackLyricsPreview?>, String>((ref, path) {
      final local = ref.watch(trackLocalLyricsProvider(path));
      TrackLyricsPreview? own() {
        final lyrics = local.hasError ? null : local.value;
        return lyrics == null ? null : TrackLyricsPreview(lyrics: lyrics);
      }

      if (ref.watch(libraryDatabaseProvider) == null) {
        return _noValueYet(local) ? const AsyncLoading() : AsyncData(own());
      }
      final pin = ref.watch(lyricsPinProvider(path));
      final target = ref.watch(_trackTargetProvider(path));
      for (final async in [pin, target]) {
        if (async.hasError) {
          _log.warning('Lyrics preview needs the library', async.error);
          return _noValueYet(local) ? const AsyncLoading() : AsyncData(own());
        }
      }
      if (_noValueYet(pin) || _noValueYet(target) || _noValueYet(local)) {
        return const AsyncLoading();
      }

      final song = target.value;
      final resolved = resolveChoice(
        uri: path,
        pin: pin.value,
        songDuration: song?.query.duration,
        local: own()?.lyrics,
        isLocalFile: true,
        fromCacheOrLookup: () => _fromCache(ref, path, song),
      );
      return switch (resolved.status) {
        LyricsReading() => const AsyncLoading(),
        LyricsFound(:final lyrics, :final origin) => AsyncData(
          TrackLyricsPreview(
            lyrics: lyrics,
            onlineProviderId: origin?.providerId,
          ),
        ),
        LyricsSearching() || LyricsNone() => const AsyncData(null),
      };
    });

/// True only for a first load. An input that is reloading (a setting changed,
/// a row was rewritten) still holds its last value, which keeps being used so
/// the preview never drops back to loading and loses what it showed.
bool _noValueYet(AsyncValue<Object?> async) =>
    async.isLoading && !async.hasValue;

/// The saved online answers for [song]; a miss is no lyrics, never a lookup.
PlayingLyricsStatus _fromCache(Ref ref, String path, LyricsTarget? song) {
  if (song == null) return LyricsNone(path, LyricsNoneReason.noLyrics);
  if (!ref.watch(lyricsSourcesLoadedProvider)) return LyricsReading(path);
  final cache = ref.watch(onlineLyricsCacheProvider(song.cacheKey));
  if (cache.hasError) {
    _log.warning('Saved online lyrics could not be read', cache.error);
    return LyricsNone(path, LyricsNoneReason.noLyrics);
  }
  if (_noValueYet(cache)) return LyricsReading(path);
  final cached = statusFromCache(
    path,
    cache.requireValue,
    ref.read(onlineLyricsClockProvider)(),
    song.query.duration,
    enabledIds: [for (final r in ref.watch(lyricsProvidersProvider)) r.id],
  );
  return cached ?? LyricsNone(path, LyricsNoneReason.noLyrics);
}
