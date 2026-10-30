import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../database/library_startup.dart';
import '../../settings/settings_provider.dart';
import 'lyrics_fetch_exception.dart';
import 'lyrics_http_retry.dart';
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
/// even when the song has changed or nothing watches it any more. The one
/// exception is the point before a request is sent (the first one, the
/// second search or a retry after a busy wait): when every caller of the
/// lookup has abandoned it by then, nothing more is sent and it ends with no
/// failure and no backoff. A plain-only exact hit already received is still
/// stored when only its extra search is cut off.
class OnlineLyricsLookups extends Notifier<Map<String, LookupState>> {
  final _inFlight = <String, _Flight>{};

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

  /// Looks [target] up at every provider the user agreed to, until one
  /// finds it. A lookup already in flight for the same key is returned
  /// instead of a second one, and [abandoned] joins it: the lookup is
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
    final flight = _Flight(abandoned);
    _inFlight[key] = flight;
    return flight.done = _run(
      target,
      key,
      auto,
      flight.abandoned,
    ).whenComplete(() => _inFlight.remove(key));
  }

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
      } on LyricsRequestAbandoned {
        _set(key, null);
        return;
      } on LyricsFetchException catch (e) {
        if (e.kind != LyricsFetchKind.notConsented) failure = e;
      } on Object catch (e) {
        if (!ref.mounted) return;
        _log.warning('Online lyrics lookup failed: ${e.runtimeType}');
        otherFailure = e;
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
    ref.read(onlineLyricsBackoffProvider.notifier).failed(failure?.retryAfter);
    _set(key, LookupFailed(failure?.kind));
  }
}

/// One lookup in flight and the abandon checks of everyone waiting on it.
class _Flight {
  _Flight(bool Function()? first) : callers = [first];

  /// One entry per caller; `null` for a caller that never abandons.
  final List<bool Function()?> callers;
  late final Future<void> done;

  bool abandoned() => callers.every((check) => check != null && check());
}

final onlineLyricsLookupsProvider =
    NotifierProvider<OnlineLyricsLookups, Map<String, LookupState>>(
      OnlineLyricsLookups.new,
    );
