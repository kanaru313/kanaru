import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../player/local_path_of.dart';
import '../player/player_service.dart';
import '../player/player_state.dart';
import 'waveform.dart';
import 'waveform_memory_cache.dart';

final _log = Logger('waveform');

/// Local path of the track the queue plays after the current one, or `null`.
String? _nextLocalPath(PlayerState s) {
  final i = s.queue.nextIndex;
  return i == null ? null : localPathOf(s.queue.trackAt(i).uri);
}

/// One waveform job in flight.
class _Running {
  _Running(this.path);

  final String path;

  /// Known once the reader has begun the job.
  int? job;
  bool cancelled = false;
}

/// Follows the player and holds the waveform of the playing local track.
///
/// Views of the waveform ([attach]/[detach]) switch loading on: while at
/// least one is attached, the playing track is read first, then the next
/// track in play order, one native job at a time. Nothing is read otherwise.
/// The state is set synchronously on a track change from a small memory
/// cache, so a waveform read earlier shows on the first frame.
///
/// Keep-alive, and `build` only listens (never watches), so the notifier is
/// never recreated and a view may keep the instance it read in `initState`.
class WaveformController extends Notifier<PlayingWaveform?> {
  late final WaveformReader _reader;
  final _cache = WaveformMemoryCache();

  /// Paths whose last read ended with [WaveformRetry]. They are skipped until
  /// a track change or a newly attached view, so a file that cannot be read
  /// right now is tried once per such event, never in a loop.
  final _deferred = <String>{};

  String? _currentUri;
  String? _current;
  String? _next;
  int _slots = 0;
  _Running? _running;

  @override
  PlayingWaveform? build() {
    _reader = ref.read(waveformReaderProvider);
    // One listener for both, so a move of current and next together (a jump
    // to the track before the playing one) is one decision: the running job
    // is judged against the final pair, never against a half-updated one.
    ref.listen(
      playerServiceProvider.select(
        (s) => (uri: s.queue.current?.uri, next: _nextLocalPath(s)),
      ),
      (_, now) => _onPlayer(now.uri, now.next),
    );
    ref.onDispose(_cancelRunning);
    final player = ref.read(playerServiceProvider);
    _setCurrent(player.queue.current?.uri);
    _next = _nextLocalPath(player);
    return _stateFor(_currentUri);
  }

  /// A waveform view appeared. Starts loading if nothing is running. Never
  /// sets [state] before returning, so it is safe to call while building.
  void attach() {
    _slots++;
    _deferred.clear();
    _pump();
  }

  /// A waveform view went away. When no view is left after a microtask (a
  /// view swapped for another in the same frame cancels nothing), the
  /// running job is cancelled and nothing else starts. No `Timer` is used.
  void detach() {
    assert(_slots > 0, 'detach without a matching attach');
    if (_slots > 0) _slots--;
    scheduleMicrotask(() {
      if (ref.mounted && _slots == 0) _cancelRunning();
    });
  }

  void _setCurrent(String? uri) {
    _currentUri = uri;
    _current = uri == null ? null : localPathOf(uri);
  }

  PlayingWaveform? _stateFor(String? uri) {
    final path = uri == null ? null : localPathOf(uri);
    if (uri == null || path == null) return null;
    final waveform = _cache.lookup(path);
    return waveform == null ? null : (uri: uri, waveform: waveform);
  }

  void _onPlayer(String? uri, String? next) {
    _next = next;
    if (uri != _currentUri) {
      _setCurrent(uri);
      _deferred.clear();
      state = _stateFor(uri);
    }
    _cancelRunningUnlessWanted();
    _pump();
  }

  /// Cancels the running job unless it reads the current or the next track.
  /// A prefetch of the track that just became current is kept.
  void _cancelRunningUnlessWanted() {
    final running = _running;
    if (running != null && running.path != _current && running.path != _next) {
      _cancelRunning();
    }
  }

  void _cancelRunning() {
    final running = _running;
    if (running == null || running.cancelled) return;
    running.cancelled = true;
    final job = running.job;
    if (job != null) _reader.cancel(job);
  }

  /// First of current, next that has no answer yet and is not deferred.
  String? _target() {
    for (final path in [_current, _next]) {
      if (path != null && !_cache.contains(path) && !_deferred.contains(path)) {
        return path;
      }
    }
    return null;
  }

  void _pump() {
    if (!ref.mounted || _slots == 0 || _running != null) return;
    final target = _target();
    if (target != null) unawaited(_run(target));
  }

  Future<void> _run(String path) async {
    final running = _running = _Running(path);
    WaveformReadResult result = const WaveformRetry();
    try {
      final job = await _reader.beginJob();
      running.job = job;
      // Cancelled while the job was starting: the id must still be read, as
      // that frees it, and the read then ends at once.
      if (running.cancelled || !ref.mounted) _reader.cancel(job);
      result = await _reader.read(path, job);
    } on Object catch (error) {
      // The path is personal data, so only the error type is logged.
      _log.warning('Waveform read failed: ${error.runtimeType}');
    }
    if (!ref.mounted) return;
    _running = null;
    switch (result) {
      case WaveformFound(:final waveform):
        _cache.put(path, waveform);
        final uri = _currentUri;
        if (path == _current && uri != null) {
          state = (uri: uri, waveform: waveform);
        }
      case WaveformAbsent():
        _cache.put(path, null);
      case WaveformRetry():
        // A read this controller cancelled is not a failed attempt.
        if (!running.cancelled) _deferred.add(path);
    }
    _pump();
  }
}

final waveformControllerProvider =
    NotifierProvider<WaveformController, PlayingWaveform?>(
      WaveformController.new,
    );
