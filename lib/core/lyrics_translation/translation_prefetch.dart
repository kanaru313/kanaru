import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../lyrics/online/lyrics_target.dart';
import '../lyrics/plugins/lyrics_sources_provider.dart';
import '../player/playing_track_art.dart' show localPathOf;
import '../player/player_service.dart';
import '../player/track.dart';
import '../settings/settings_provider.dart';
import 'queue_translation_choice.dart';
import 'translation_prefetch_clock.dart';
import 'translation_jobs.dart';
import 'translation_lines.dart';
import 'translation_prefetch_step.dart';
import 'translation_prefetch_window.dart';
import 'translation_scope_providers.dart';
import 'translation_song_context.dart';

final _log = Logger('translation');

/// Translates the next songs of the queue in the background, one job at a
/// time, with the rules of the playing song (service choice by the scope
/// precedence, accepted notice, saved rows) and only from lyrics already on
/// this device; it never looks lyrics up online.
///
/// It never rebuilds: [build] only sets up listeners and the state lives in
/// fields. The lyrics translation controller listens to it for its whole life,
/// so it runs while Now Playing is open, also for a playing song without
/// lyrics. It never reads the controller.
///
/// A round has a generation. It changes when the queue window, the count, the
/// show switch, the scope precedence, the song choices or the queue choice
/// change; a round of an older generation stops at its next step and a new one
/// waits for the job in flight, so at most one background job runs. Position
/// ticks and job status changes do not change it: jobs are only watched to
/// notice the playing song's job ending, which lets a waiting round start.
class TranslationPrefetch extends Notifier<void> {
  TranslationPrefetch(this.appLang);

  final String appLang;

  late final TranslationJobs _jobs;
  var _generation = 0;
  // The generation whose round has started; reset when a round ends early.
  var _startedGeneration = -1;
  Future<BackgroundRunResult>? _active;
  // Wakes a round waiting on lyrics when the generation changes.
  var _changed = Completer<void>();

  late final PrefetchClock _clock;
  var _windowKey = '';
  var _currentWasRunning = false;
  // Keys resolved for the window, kept while only the queue moved.
  final _keys = <String, TranslationJobKey>{};

  @override
  void build() {
    // Kept alive here, not by the controller: jobs and the choice rule read
    // them synchronously.
    ref.listen(songTranslationOverridesProvider, (_, _) => _restart());
    ref.listen(queueTranslationChoiceProvider, (_, _) => _restart());
    ref.listen(translatePluginRecordsProvider, (_, _) => _restart());
    // The window and the job keys do not depend on the count or the switch.
    ref.listen(
      settingsProvider.select(
        (s) => (s.translation.show, s.translation.prefetchCount),
      ),
      (_, _) {
        _windowKey = _windowKeyOf();
        _restart(keepKeys: true);
      },
    );
    ref.listen(
      settingsProvider.select(
        (s) => (s.translation.scopePrecedence, s.translation.targetLanguage),
      ),
      (_, _) => _restart(),
    );
    ref.listen(playerServiceProvider.select((s) => s.queue), (_, queue) {
      final key = _windowKeyOf();
      if (key == _windowKey) return;
      _windowKey = key;
      _restart(keepKeys: true);
    });
    ref.listen(
      playerServiceProvider.select((s) => (s.playing, s.playthrough)),
      (_, _) => _syncClock(),
    );
    ref.listen(translationJobsProvider, (_, _) {
      final running = _jobs.currentRunning;
      final ended = _currentWasRunning && !running;
      _currentWasRunning = running;
      if (ended) _maybeStart();
    });

    _jobs = ref.read(translationJobsProvider.notifier);
    _clock = PrefetchClock(
      ref.read(translationPrefetchTimeProvider),
      ref.read(translationPrefetchDelayProvider),
      _maybeStart,
    );
    _windowKey = _windowKeyOf();
    _currentWasRunning = _jobs.currentRunning;
    ref.onDispose(() {
      _generation++;
      _clock.dispose();
      if (!_changed.isCompleted) _changed.complete();
      _jobs.setPrefetch({});
    });
    _syncClock();
  }

  String _windowKeyOf() {
    final queue = ref.read(playerServiceProvider).queue;
    final n = ref.read(settingsProvider).translation.prefetchCount;
    return [
      queue.current?.uri,
      ...prefetchWindow(queue, n).map((t) => t.uri),
    ].join('\u0000');
  }

  /// Starts a new generation: the old round stops at its next step.
  void _restart({bool keepKeys = false}) {
    if (!ref.mounted) return;
    _generation++;
    if (!keepKeys) _keys.clear();
    if (!_changed.isCompleted) _changed.complete();
    _changed = Completer<void>();
    final window = _window();
    final uris = {for (final t in window) t.uri};
    _keys.removeWhere((uri, _) => !uris.contains(uri));
    // A job in flight keeps going while its song stays in the window.
    _jobs.setPrefetch(_keys.values.toSet());
    _syncClock();
    _maybeStart();
  }

  List<Track> _window() {
    final prefs = ref.read(settingsProvider).translation;
    if (!prefs.show) return const [];
    return prefetchWindow(
      ref.read(playerServiceProvider).queue,
      prefs.prefetchCount,
    );
  }

  /// Lets the clock follow the player; it times only while there is a window.
  void _syncClock() {
    if (!ref.mounted) return;
    final player = ref.read(playerServiceProvider);
    _clock.sync(
      playthrough: player.playthrough,
      playing: player.playing,
      wanted: _window().isNotEmpty,
    );
  }

  void _maybeStart() {
    if (!ref.mounted || _startedGeneration == _generation) return;
    // Readiness belongs to the playthrough it measured, whatever order the
    // player's changes arrive in.
    if (!_clock.isReady(ref.read(playerServiceProvider).playthrough)) return;
    if (_window().isEmpty || _jobs.currentRunning) return;
    final generation = _startedGeneration = _generation;
    unawaited(_round(generation));
  }

  bool _live(int generation) => ref.mounted && generation == _generation;

  Future<void> _round(int generation) async {
    try {
      // One background job at a time: wait for the one of an older round.
      await _active?.catchError((_) => BackgroundRunResult.failed);
      if (!_live(generation)) return;
      for (final track in _window()) {
        if (!_live(generation)) return;
        final result = await _prefetchTrack(generation, track);
        if (result == BackgroundRunResult.superseded) {
          if (_live(generation)) {
            // The playing song needs the gate; try again when its job ends.
            _startedGeneration = -1;
            if (!_jobs.currentRunning) scheduleMicrotask(_maybeStart);
          }
          return;
        }
      }
    } on Object catch (e) {
      // A step failed (a database closing, say): this round ends, the next
      // trigger starts another.
      _log.warning('translate-ahead round failed: ${e.runtimeType}');
      if (_live(generation)) _startedGeneration = -1;
    }
  }

  /// The filter steps of one song, then its background job. Null when the song
  /// is left out.
  Future<BackgroundRunResult?> _prefetchTrack(
    int generation,
    Track track,
  ) async {
    final path = localPathOf(track.uri);
    if (path == null) return null;
    final lyrics = await previewLyricsOf(ref, path, _changed.future);
    if (lyrics == null || !_live(generation)) return null;
    final found = await prefetchCandidateFor(ref, appLang, lyrics);
    if (found == null || !_live(generation)) return null;
    _keys[track.uri] = found.key;
    _jobs.setPrefetch(_keys.values.toSet());
    if (!found.needsRequest) return null;
    final query = LyricsTarget.fromTrack(track).query;
    final run = _jobs.runBackground(
      found.key,
      uniqueLineTexts(lyrics),
      found.target,
      song: TranslationSongContext(title: query.title, artist: query.artist),
    );
    _active = run;
    return run;
  }
}

/// [appLang] is the app's language code, the default target language.
final translationPrefetchProvider = NotifierProvider.autoDispose
    .family<TranslationPrefetch, void, String>(
      TranslationPrefetch.new,
      retry: (_, _) => null,
    );
