import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../database/library_startup.dart';
import '../../player/local_path_of.dart';
import '../../player/player_service.dart';
import '../../settings/settings_provider.dart';
import '../lyrics.dart';
import '../playing_local_lyrics_provider.dart';
import 'auto_lyrics_lookup_provider.dart';
import 'lyrics_choice.dart';
import 'lyrics_source_resolution.dart';
import 'lyrics_provider_registry.dart';
import 'lyrics_target.dart';
import 'online_lyrics_lookups.dart';
import 'online_lyrics_resolution.dart';
import 'online_lyrics_streams.dart';
import 'playing_lyrics_status.dart';
export 'lyrics_source_resolution.dart';

final _log = Logger('online_lyrics');

/// Wires the inputs of [resolveChoice] for the playing song: the pin, the
/// song's own lyrics, the target, the cache, the lookups and the pause.
/// `null` when nothing plays.
///
/// Without a library, or when the pin, fields or cache cannot be read, only
/// local lyrics are used and nothing is requested. Resolving never writes.
/// Automatic lookups run only while something watches this provider (Now
/// Playing).
class PlayingLyricsResolutionNotifier
    extends Notifier<LyricsSourceResolution?> {
  Object? _loggedError;
  LyricsSourceResolution? _last;

  /// A record still being worked out (`LyricsReading`) keeps the previous
  /// whole record of the same song, so views and the source pill do not
  /// flash while the song's own lyrics are read again.
  @override
  LyricsSourceResolution? build() {
    final next = _compose();
    final last = _last;
    final keep =
        next != null &&
        last != null &&
        next.status is LyricsReading &&
        last.status.uri == next.status.uri;
    return _last = keep ? last : next;
  }

  LyricsSourceResolution? _compose() {
    final uri = ref.watch(
      playerServiceProvider.select((s) => s.queue.current?.uri),
    );
    if (uri == null) return null;
    final local = ref.watch(playingLocalLyricsProvider);
    if (ref.watch(libraryDatabaseProvider) == null) {
      return _localOnly(uri, local);
    }
    final trackKey = localPathOf(uri) ?? uri;
    final pin = ref.watch(lyricsPinProvider(trackKey));
    final target = ref.watch(lyricsTargetProvider);
    for (final async in [pin, target]) {
      if (async.hasError) {
        _logOnce(async.error!);
        return _localOnly(uri, local);
      }
    }
    final song = target.value;
    if (pin.isLoading ||
        target.isLoading ||
        local.isLoading ||
        song == null ||
        song.trackKey != trackKey) {
      return _result(LyricsReading(uri), pin.value, LyricsChoice.auto, false);
    }

    final localLyrics = _ownLyrics(uri, local);
    final resolved = resolveChoice(
      uri: uri,
      pin: pin.value,
      songDuration: song.query.duration,
      local: localLyrics,
      isLocalFile: localPathOf(uri) != null,
      fromCacheOrLookup: () => _fromCacheOrLookup(uri, song),
    );
    return _result(
      resolved.status,
      pin.value,
      resolved.effective,
      localLyrics != null,
    );
  }

  LyricsSourceResolution _result(
    PlayingLyricsStatus status,
    LyricsPinEntry? pin,
    LyricsChoice effective,
    bool hasLocal,
  ) => (
    chosen: pin?.choice ?? LyricsChoice.auto,
    effective: effective,
    pin: pin,
    hasLocal: hasLocal,
    status: status,
  );

  Lyrics? _ownLyrics(String uri, AsyncValue<PlayingLyrics?> local) {
    final found = local.hasError ? null : local.value;
    return found != null && found.uri == uri ? found.lyrics : null;
  }

  LyricsSourceResolution _localOnly(
    String uri,
    AsyncValue<PlayingLyrics?> local,
  ) {
    if (local.isLoading) {
      return _result(LyricsReading(uri), null, LyricsChoice.auto, false);
    }
    final own = _ownLyrics(uri, local);
    return _result(
      own != null
          ? LyricsFound(uri, own)
          : LyricsNone(uri, LyricsNoneReason.noLyrics),
      null,
      LyricsChoice.auto,
      own != null,
    );
  }

  void _logOnce(Object error) {
    if (identical(_loggedError, error)) return;
    _loggedError = error;
    _log.warning('Online lyrics need the library; using local lyrics', error);
  }

  PlayingLyricsStatus _fromCacheOrLookup(String uri, LyricsTarget song) {
    final cache = ref.watch(onlineLyricsCacheProvider(song.cacheKey));
    if (cache.hasError) {
      _logOnce(cache.error!);
      return LyricsNone(uri, LyricsNoneReason.noLyrics);
    }
    if (cache.isLoading) return LyricsReading(uri);
    final now = ref.read(onlineLyricsClockProvider)();
    final cached = statusFromCache(
      uri,
      cache.requireValue,
      now,
      song.query.duration,
    );
    if (cached != null) return cached;

    // A miss: look it up when automatic lookups are allowed. The auto
    // provider stays watched while its lookup runs, so an answer that has
    // not reached the cache stream yet does not start a second one.
    final registrations = ref.watch(lyricsProvidersProvider);
    final providerId = ref.watch(
      settingsProvider.select(
        (s) => registrations
            .where(s.onlineLyrics.autoAllowedFor)
            .map((r) => r.id)
            .firstOrNull,
      ),
    );
    // The end of the pause, not only whether it runs: a longer pause updates
    // the time the status reports.
    final until = ref.watch(onlineLyricsBackoffProvider);
    final blocked = until != null && now.isBefore(until);
    final wanted = song.isAutoSearchable ? providerId : null;
    final autoId = blocked ? null : wanted;
    if (autoId != null) ref.watch(autoLyricsLookupProvider(song));
    if (blocked && wanted != null) {
      // The pause ends without any state changing, so wake up when it does.
      final wake = Timer(
        until.difference(now) + const Duration(milliseconds: 1),
        ref.invalidateSelf,
      );
      ref.onDispose(wake.cancel);
    }
    final lookup = ref.watch(
      onlineLyricsLookupsProvider.select((m) => m[song.cacheKey]),
    );
    return statusFromLookup(
      uri: uri,
      lookup: lookup,
      wanted: wanted != null,
      pausedUntil: until,
      now: now,
      autoProviderId: autoId,
    );
  }
}

final playingLyricsResolutionProvider =
    NotifierProvider.autoDispose<
      PlayingLyricsResolutionNotifier,
      LyricsSourceResolution?
    >(PlayingLyricsResolutionNotifier.new);
