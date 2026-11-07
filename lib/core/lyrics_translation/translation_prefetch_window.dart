import '../player/play_queue.dart';
import '../player/repeat_mode.dart';
import '../player/track.dart';

/// The next up to [n] tracks to translate ahead, in play order after the
/// current one. Empty under [RepeatMode.one]: the next tracks never auto-play.
/// Wraps to the start of the queue only under [RepeatMode.all]: a shuffled
/// repeat reshuffles at the end of a round. A track that repeats an earlier
/// uri, or the playing uri, is left out; the window stops when it comes back
/// to the current track.
List<Track> prefetchWindow(PlayQueue queue, int n) {
  final length = queue.order.length;
  final current = queue.current;
  if (n <= 0 || current == null || queue.repeat == RepeatMode.one) {
    return const [];
  }
  final wrap = queue.repeat == RepeatMode.all;
  final seen = {current.uri};
  final window = <Track>[];
  for (var step = 1; step < length && window.length < n; step++) {
    var position = queue.index + step;
    if (position >= length) {
      if (!wrap) break;
      position %= length;
    }
    final track = queue.trackAt(position);
    if (seen.add(track.uri)) window.add(track);
  }
  return window;
}
