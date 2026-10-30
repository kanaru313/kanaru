import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../database/library_database.dart';
import '../../database/library_startup.dart';
import '../../database/online_lyrics_queries.dart';
import '../../settings/settings_provider.dart';
import 'lyrics_fetch_exception.dart';
import 'lyrics_http_retry.dart';
import 'lyrics_provider_registry.dart';
import 'lyrics_source_names.dart';
import 'lookup_flight.dart';
import 'lookup_state.dart';
import 'lyrics_target.dart';
import 'online_lyrics_backoff.dart';
import 'online_lyrics_entries.dart';
import 'online_lyrics_http_factory.dart';
import 'online_lyrics_resolution.dart';
import 'run_online_lyrics_lookup.dart';

export 'lookup_state.dart';
export 'run_online_lyrics_lookup.dart';

final _log = Logger('online_lyrics');

/// Runs online lookups, keyed by cache key. Lives as long as the app: a sent
/// request cannot be aborted, so a lookup finishes and stores its answer
/// even when the song has changed or nothing watches it any more. The one
/// exception is the point before a request is sent (the first one, the
/// second search or a retry after a busy wait): when every caller of the
/// lookup has abandoned it by then, nothing more is sent and it ends with no
/// failure and no backoff. A plain-only exact hit already received is still
/// stored when only its extra search is cut off.
class OnlineLyricsLookups extends Notifier<Map<String, LookupState>> {
  final _inFlight = <String, LookupFlight>{};

  /// Keys whose last lookup left a source unasked: it skipped (the plugin
  /// runtime was busy) or its answer could not be stored (the plugin was
  /// removed meanwhile). Nothing was recorded for that source, so the caller
  /// decides when to try again.
  final _unasked = <String>{};

  /// Bumped by [forgetFailures]; a lookup started before the bump records no
  /// failure and starts no pause.
  int _generation = 0;

  @override
  Map<String, LookupState> build() => const {};

  /// Drops every remembered failure (Settings "Clear"), so a song shows its
  /// state again as if nothing had gone wrong. A lookup already running
  /// finishes, but its failure is not recorded and starts no pause. A found
  /// or not-found answer it stores after this call still lands: a sent
  /// request cannot be aborted.
  void forgetFailures() {
    _generation++;
    if (!ref.mounted) return;
    state = {
      for (final e in state.entries)
        if (e.value is! LookupFailed) e.key: e.value,
    };
  }

  /// Looks [target] up at every enabled provider the user agreed to, until
  /// one finds it. An automatic lookup skips a provider that already has a
  /// recent "no match" for the song; a manual one asks them all again. A
  /// lookup already in flight for the same key is returned instead of a
  /// second one, and [abandoned] joins it: the lookup is
  /// dropped only once every caller's check says so, and a caller without
  /// one (a manual lookup) keeps it. Nothing is sent, and nothing recorded,
  /// for a target that is not auto-searchable, without a library, or
  /// without the consent for [auto] (automatic lookups also need the
  /// setting on).
  Future<void> start(
    LyricsTarget target, {
    required bool auto,
    bool Function()? abandoned,
  }) {
    final key = target.cacheKey;
    final running = _inFlight[key];
    if (running != null) {
      running.callers.add(abandoned);
      return running.done;
    }
    final flight = LookupFlight(abandoned);
    _inFlight[key] = flight;
    return flight.done = _run(
      target,
      key,
      auto,
      flight.abandoned,
    ).whenComplete(() => _inFlight.remove(key));
  }

  /// The ids of the [enabled] sources whose row for [key] is not a usable
  /// miss: no row, a stale "no match", or a found row (see [sourcesToAsk]).
  Future<Set<String>> _sourcesToAsk(
    LibraryDatabase db,
    String key,
    List<LyricsProviderRegistration> enabled,
    DateTime now,
  ) async {
    final rows = await db.watchOnlineLyrics(key).first;
    final entries = [
      for (final row in rows) OnlineLyricsEntry.fromRow(row, row.lookupStatus!),
    ];
    return sourcesToAsk(entries, [for (final r in enabled) r.id], now).toSet();
  }

  /// Whether the last lookup of [key] left an enabled source unasked without
  /// a failure (see `_unasked`). The automatic lookup waits before it
  /// retries such a song, so a busy runtime is not asked again every second.
  bool leftSourceUnasked(String key) => _unasked.contains(key);

  void _set(String key, LookupState? value) {
    if (!ref.mounted) return;
    final next = {...state};
    value == null ? next.remove(key) : next[key] = value;
    state = next;
  }

  Future<void> _run(
    LyricsTarget target,
    String key,
    bool auto,
    bool Function() abandoned,
  ) async {
    final db = ref.read(libraryDatabaseProvider);
    if (db == null || !target.isAutoSearchable) return;
    final generation = _generation;
    _unasked.remove(key);
    // The list of sources is complete before any request goes out.
    if (!ref.read(lyricsSourcesLoadedProvider)) {
      await whenLyricsSourcesLoaded(ref);
      if (!ref.mounted) return;
    }
    final prefs = ref.read(settingsProvider).onlineLyrics;
    final factory = ref.read(onlineLyricsHttpFactoryProvider);
    final now = ref.read(onlineLyricsClockProvider);
    LyricsFetchException? failure;
    Object? otherFailure;
    var found = false;
    final enabled = ref.read(lyricsProvidersProvider);
    final backoff = ref.read(onlineLyricsBackoffProvider.notifier);
    // Pauses only the source that failed, and only when the user has not
    // cleared the failures since this lookup started.
    void pause(String providerId, Duration? retryAfter) {
      if (ref.mounted && generation == _generation) {
        backoff.failed(providerId, retryAfter);
      }
    }

    Set<String>? toAsk;
    if (auto) {
      try {
        toAsk = await _sourcesToAsk(db, key, enabled, now());
      } on Object catch (e) {
        if (!ref.mounted) return;
        _log.warning('Online lyrics lookup failed: ${e.runtimeType}');
        otherFailure = e;
        toAsk = const {};
        for (final registration in enabled) {
          pause(registration.id, null);
        }
      }
    }
    if (!ref.mounted) return;
    for (final registration in enabled) {
      if (!ref.mounted) return;
      if (toAsk != null && !toAsk.contains(registration.id)) continue;
      if (auto && !prefs.autoAllowed) continue;
      // A paused source is left alone until its pause ends; the user's own
      // lookups (Retry, Search again) lift every pause first.
      if (auto && backoff.isPaused(registration.id)) continue;
      try {
        final http = auto
            ? factory.forAuto(registration, abandoned: abandoned)
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
        // Nothing was stored (the plugin was removed during the lookup): the
        // source is left unasked, not counted as a miss.
        if (result == OnlineLyricsLookupResult.notStored) _unasked.add(key);
      } on LyricsRequestAbandoned {
        _set(key, null);
        return;
      } on LyricsSourceSkipped {
        // Not run this time: no failure, no pause, nothing stored.
        _unasked.add(key);
        continue;
      } on LyricsFetchException catch (e) {
        if (e.kind != LyricsFetchKind.notConsented) {
          failure = e;
          pause(registration.id, e.retryAfter);
        }
      } on Object catch (e) {
        if (!ref.mounted) return;
        _log.warning('Online lyrics lookup failed: ${e.runtimeType}');
        otherFailure = e;
        pause(registration.id, null);
      }
    }
    if (!ref.mounted) return;
    if (found ||
        (failure == null && otherFailure == null) ||
        generation != _generation) {
      _set(key, null);
      return;
    }
    _log.info('Online lyrics lookup failed: ${failure?.kind.name}');
    _set(key, LookupFailed(failure?.kind));
  }
}

final onlineLyricsLookupsProvider =
    NotifierProvider<OnlineLyricsLookups, Map<String, LookupState>>(
      OnlineLyricsLookups.new,
    );
