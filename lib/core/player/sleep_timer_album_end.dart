import 'dart:async';

import 'album_run_key_cache.dart';
import 'album_run_lookup.dart';
import 'local_path_of.dart';
import 'play_queue.dart';
import 'play_queue_pass.dart';

/// Tells whether the current track of a queue is the last of its album in
/// play order, for the sleep timer's end of album mode: the next track in
/// play order ([PlayQueue.nextIndex]) has another album key, or no track
/// follows (also the last track of a pass under repeat all shuffled). A
/// track without a key (not in the library, no album tag, keys not computed
/// yet, not a local file) is an album of its own.
///
/// Keys are read through an [AlbumRunKeyCache], so a pair seen before is
/// decided at once. For a new pair the current track is first assumed to
/// end its album (a stop too many beats one too few), then decided when
/// the lookup completes, only if no newer [check] or [cancel] came
/// meanwhile. The track after the next one is read ahead with the pair, so
/// moving on inside an album finds the following pair cached and never
/// assumes a stop.
class SleepTimerAlbumEnd {
  SleepTimerAlbumEnd(AlbumRunKeyLookup lookup)
    : _keys = AlbumRunKeyCache(lookup);

  final AlbumRunKeyCache _keys;
  int _generation = 0;

  /// Calls [decided] with whether the current track of [queue] ends its
  /// album: once, synchronously, when the keys are cached; else with `true`
  /// at once and again with the answer once they are read.
  void check(PlayQueue queue, void Function(bool lastOfAlbum) decided) {
    final generation = ++_generation;
    final current = queue.current;
    final next = queue.nextIndex;
    // The last track of a shuffled pass is followed by a new random order:
    // nothing predictable follows, so it ends the album.
    if (current == null || next == null || queue.endsShuffledPass) {
      return decided(true);
    }
    final path = localPathOf(current.uri);
    final nextPath = localPathOf(queue.trackAt(next).uri);
    if (path == null || nextPath == null) return decided(true);
    final ahead = _afterNextPath(queue, next);
    void decide() {
      if (generation != _generation) return;
      final key = _keys[path];
      decided(key == null || key != _keys[nextPath]);
    }

    if (_keys.has(path) && _keys.has(nextPath)) {
      decide();
      if (ahead != null) unawaited(_keys.ensure([ahead]));
      return;
    }
    decided(true);
    // The cache logs and swallows lookup failures; the paths then count as
    // having no album.
    unawaited(_keys.ensure([path, nextPath, ?ahead]).then((_) => decide()));
  }

  /// Local path of the track after the one at [next] in play order, or
  /// `null` (none follows, or not a local file).
  static String? _afterNextPath(PlayQueue queue, int next) {
    final index = next + 1 < queue.order.length
        ? next + 1
        : (queue.repeat.wrapsQueue ? 0 : null);
    return index == null ? null : localPathOf(queue.trackAt(index).uri);
  }

  /// Drops the decision of a lookup still running.
  void cancel() => _generation++;

  void dispose() {
    _generation++;
    _keys.dispose();
  }
}
