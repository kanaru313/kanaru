import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../database/library_startup.dart';
import '../../player/local_path_of.dart';
import '../../player/player_service.dart';
import '../../settings/settings_provider.dart';
import '../playing_local_lyrics_provider.dart';
import 'lyrics_provider_registry.dart';
import 'lyrics_target.dart';
import 'online_lyrics_lookups.dart';
import 'online_lyrics_resolution.dart';
import 'online_lyrics_streams.dart';
import 'playing_lyrics_status.dart';

export 'online_lyrics_resolution.dart' show notFoundTtl;
export 'playing_lyrics_status.dart';

final _log = Logger('online_lyrics');

/// Waits the debounce, then starts the automatic lookup of [target]. Watched
/// by the status for as long as that lookup is wanted: a song skipped within
/// the debounce disposes it first and nothing is sent. The request itself
/// runs in the keepAlive lookups notifier, which also dedupes it.
final autoLyricsLookupProvider = FutureProvider.autoDispose
    .family<void, LyricsTarget>((ref, target) async {
      final waited = Completer<void>();
      final timer = Timer(
        ref.read(onlineLyricsDebounceProvider),
        waited.complete,
      );
      ref.onDispose(() {
        timer.cancel();
        if (!waited.isCompleted) waited.complete();
      });
      await waited.future;
      if (!ref.mounted) return;
      await ref
          .read(onlineLyricsLookupsProvider.notifier)
          .start(target, auto: true);
    }, retry: (_, _) => null);

/// What the playing song's lyrics are, or `null` when nothing plays.
///
/// Order: pin > local (tags, `.lrc`) > skip > cache > automatic lookup.
/// Without a library, or when the pin, fields or cache cannot be read, only
/// local lyrics are used and nothing is requested. A status still being
/// worked out keeps the previous one of the same song, so views do not
/// flash. Automatic lookups run only while something watches this provider
/// (Now Playing).
class PlayingLyricsStatusNotifier extends Notifier<PlayingLyricsStatus?> {
  PlayingLyricsStatus? _last;
  Object? _loggedError;

  @override
  PlayingLyricsStatus? build() {
    final next = _compose();
    final last = _last;
    final result = next is LyricsReading && last != null && last.uri == next.uri
        ? last
        : next;
    return _last = result;
  }

  PlayingLyricsStatus _localOnly(String uri, AsyncValue<PlayingLyrics?> local) {
    if (local.isLoading) return LyricsReading(uri);
    final found = local.hasError ? null : local.value;
    return found != null && found.uri == uri
        ? LyricsFound(uri, found.lyrics)
        : LyricsNone(uri, LyricsNoneReason.noLyrics);
  }

  void _logOnce(Object error) {
    if (identical(_loggedError, error)) return;
    _loggedError = error;
    _log.warning('Online lyrics need the library; using local lyrics', error);
  }

  PlayingLyricsStatus? _compose() {
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
      return LyricsReading(uri);
    }

    final pinned = pin.value;
    if (pinned != null && !pinned.isSkip) {
      final picked = statusFromPick(uri, pinned, song.query.duration);
      if (picked != null) return picked;
    }
    final localFound = local.hasError ? null : local.value;
    if (localFound != null && localFound.uri == uri) {
      return LyricsFound(uri, localFound.lyrics);
    }
    if (pinned != null && pinned.isSkip) {
      return LyricsNone(uri, LyricsNoneReason.skipped);
    }
    if (localPathOf(uri) == null) {
      return LyricsNone(uri, LyricsNoneReason.noLyrics);
    }
    return _fromCacheOrLookup(uri, song);
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
    final blocked = ref.watch(
      onlineLyricsBackoffProvider.select(
        (until) => until != null && now.isBefore(until),
      ),
    );
    final wanted = song.isAutoSearchable ? providerId : null;
    final autoId = blocked ? null : wanted;
    if (autoId != null) ref.watch(autoLyricsLookupProvider(song));
    if (blocked && wanted != null) {
      // The pause ends without any state changing, so wake up when it does.
      final until = ref.read(onlineLyricsBackoffProvider);
      if (until != null) {
        final wake = Timer(
          until.difference(now) + const Duration(milliseconds: 1),
          ref.invalidateSelf,
        );
        ref.onDispose(wake.cancel);
      }
    }
    final lookup = ref.watch(
      onlineLyricsLookupsProvider.select((m) => m[song.cacheKey]),
    );
    // An earlier failure is shown only when no new lookup is about to run.
    return switch (lookup) {
      LookupRunning(:final providerId) => LyricsSearching(uri, providerId),
      _ when autoId != null => LyricsSearching(uri, autoId),
      LookupFailed() => LyricsNone(uri, LyricsNoneReason.error),
      _ => LyricsNone(uri, LyricsNoneReason.noLyrics),
    };
  }
}

final playingLyricsStatusProvider =
    NotifierProvider.autoDispose<
      PlayingLyricsStatusNotifier,
      PlayingLyricsStatus?
    >(PlayingLyricsStatusNotifier.new);
