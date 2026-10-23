import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/library_startup.dart';
import '../player/player_service.dart';
import '../settings/settings_provider.dart';
import 'listen_accumulator.dart';
import 'listen_recorder.dart';

/// Real clocks for the recorder; tests override it.
final listenClockProvider = Provider<ListenClock>((ref) {
  final stopwatch = Stopwatch()..start();
  return (now: DateTime.now, elapsed: () => stopwatch.elapsed);
});

/// The listen recorder, or `null` without a library database. Nothing in the
/// UI reads it except the settings section; `main.dart` keeps it alive.
final listenRecorderProvider = Provider<ListenRecorder?>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return null;
  final settings = ref.read(settingsProvider);
  final recorder = ListenRecorder(
    db,
    enabled: settings.recordListenHistory,
    clock: ref.watch(listenClockProvider),
    threshold: _thresholdOf(settings),
  );
  ref.listen(
    settingsProvider.select((s) => s.recordListenHistory),
    (_, enabled) => recorder.setEnabled(enabled),
  );
  // Listened, not watched: a new threshold must not rebuild the recorder
  // and lose the playthrough under way.
  ref.listen(
    settingsProvider.select(_thresholdOf),
    (_, threshold) => recorder.threshold = threshold,
  );
  ref.listen(playerServiceProvider, recorder.onState, fireImmediately: true);
  ref.onDispose(recorder.dispose);
  return recorder;
});

ListenThreshold _thresholdOf(AppSettings settings) => ListenThreshold(
  minutes: settings.playback.listenThresholdMinutes,
  percent: settings.playback.listenThresholdPercent,
);
