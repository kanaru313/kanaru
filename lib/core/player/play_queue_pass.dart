import 'dart:math';

import 'play_queue.dart';
import 'repeat_mode.dart';

/// Passes through the queue under [RepeatMode.allShuffled].
extension PlayQueuePasses on PlayQueue {
  /// On the last track of a pass under repeat all shuffled. Playing on from
  /// here starts a new pass.
  bool get endsShuffledPass =>
      repeat == RepeatMode.allShuffled && !isEmpty && index == order.length - 1;

  /// The track the engine is handed to play after the current one: none on
  /// the last track of a shuffled pass, where [nextShuffledPass] decides what
  /// comes next once the track has finished.
  int? get engineNextIndex => endsShuffledPass ? null : nextIndex;

  /// A fresh random order of every track for the next pass: index 0, shuffle
  /// on, and the first track is never the one that just played. The order
  /// shuffle goes back to is the one from before the first reshuffle, so
  /// turning shuffle off still gives the user's order. A queue of fewer than
  /// two tracks has nothing to reorder and stays as it is, shuffle flag too.
  PlayQueue nextShuffledPass(Random random) {
    if (order.length < 2) return this;
    final last = order[index];
    final fresh = List<int>.of(order);
    for (var i = fresh.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final swap = fresh[i];
      fresh[i] = fresh[j];
      fresh[j] = swap;
    }
    if (fresh.length > 1 && fresh.first == last) {
      final j = 1 + random.nextInt(fresh.length - 1);
      final swap = fresh[0];
      fresh[0] = fresh[j];
      fresh[j] = swap;
    }
    return PlayQueue(
      original: original,
      order: fresh,
      shuffled: true,
      repeat: repeat,
      unshuffledOrder: unshuffledOrder ?? order,
    );
  }
}
