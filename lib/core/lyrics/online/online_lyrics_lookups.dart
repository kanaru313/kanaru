import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../database/library_startup.dart';
import '../../settings/settings_provider.dart';
import 'lyrics_fetch_exception.dart';
import 'lyrics_provider_registry.dart';
import 'lyrics_target.dart';
import 'online_lyrics_backoff.dart';
import 'online_lyrics_http_factory.dart';
import 'run_online_lyrics_lookup.dart';

export 'run_online_lyrics_lookup.dart';

final _log = Logger('online_lyrics');

/// Where the lookup of one metadata key stands. A finished lookup leaves no
/// entry: its answer is in the cache.
sealed class LookupState {
  const LookupState();
}

/// A request is in flight at [providerId].
final class LookupRunning extends LookupState {
  const LookupRunning({required this.providerId, required this.auto});

  final String providerId;

  /// Kanaru started it, not the user.
  final bool auto;
}

/// The last lookup failed and wrote nothing. [kind] is `null` for a failure
/// that is not a request error (e.g. the database).
final class LookupFailed extends LookupState {
  const LookupFailed(this.kind);

  final LyricsFetchKind? kind;
}

/// Runs online lookups, keyed by cache key. Lives as long as the app: a sent
/// request cannot be aborted, so a lookup finishes and stores its answer
/// even when the song has changed or nothing watches it any more.
class OnlineLyricsLookups extends Notifier<Map<String, LookupState>> {
  final _inFlight = <String, Future<void>>{};

  @override
  Map<String, LookupState> build() => const {};

  /// Looks [target] up at every provider the user agreed to, until one
  /// finds it. A lookup already in flight for the same key is returned
  /// instead of a second one. Nothing is sent, and nothing recorded, for a
  /// target that is not auto-searchable, without a library, or without the
  /// consent for [auto] (automatic lookups also need the setting on).
  Future<void> start(LyricsTarget target, {required bool auto}) {
    final key = target.cacheKey;
    return _inFlight[key] ??= _run(target, key, auto).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  void _set(String key, LookupState? value) {
    if (!ref.mounted) return;
    final next = {...state};
    value == null ? next.remove(key) : next[key] = value;
    state = next;
  }

  Future<void> _run(LyricsTarget target, String key, bool auto) async {
    final db = ref.read(libraryDatabaseProvider);
    if (db == null || !target.isAutoSearchable) return;
    final prefs = ref.read(settingsProvider).onlineLyrics;
    final factory = ref.read(onlineLyricsHttpFactoryProvider);
    final now = ref.read(onlineLyricsClockProvider);
    LyricsFetchException? failure;
    Object? otherFailure;
    var found = false;
    for (final registration in ref.read(lyricsProvidersProvider)) {
      if (auto && !prefs.autoAllowedFor(registration)) continue;
      try {
        final http = auto
            ? factory.forAuto(registration)
            : factory.forManual(registration);
        _set(key, LookupRunning(providerId: registration.id, auto: auto));
        final result = await runOnlineLyricsLookup(
          registration: registration,
          http: http,
          db: db,
          now: now,
          target: target,
        );
        if (result == OnlineLyricsLookupResult.found) {
          found = true;
          break;
        }
      } on LyricsFetchException catch (e) {
        if (e.kind != LyricsFetchKind.notConsented) failure = e;
      } on Object catch (e, st) {
        if (!ref.mounted) return;
        _log.warning('Online lyrics lookup failed', e, st);
        otherFailure = e;
      }
    }
    if (!ref.mounted) return;
    if (found || (failure == null && otherFailure == null)) {
      _set(key, null);
      return;
    }
    _log.info('Online lyrics lookup failed: ${failure?.kind.name}');
    ref.read(onlineLyricsBackoffProvider.notifier).failed(failure?.retryAfter);
    _set(key, LookupFailed(failure?.kind));
  }
}

final onlineLyricsLookupsProvider =
    NotifierProvider<OnlineLyricsLookups, Map<String, LookupState>>(
      OnlineLyricsLookups.new,
    );
