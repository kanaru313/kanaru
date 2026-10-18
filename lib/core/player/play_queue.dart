import 'dart:math';

import 'repeat_mode.dart';
import 'track.dart';

/// Immutable play queue: the tracks as opened, the order they play in, the
/// current position, shuffle and repeat. Every change returns a new queue.
///
/// The play order is kept as indexes into [original], so turning shuffle off
/// finds the current track again even when the same file is queued twice.
class PlayQueue {
  PlayQueue({
    this.original = const [],
    List<int>? order,
    this.index = 0,
    this.shuffled = false,
    this.repeat = RepeatMode.off,
  }) : order = order ?? List.generate(original.length, (i) => i);

  /// Queue for freshly opened [tracks], starting at [start]. Keeps the given
  /// shuffle and repeat settings; when shuffled, [start] plays first.
  factory PlayQueue.open(
    List<Track> tracks,
    int start, {
    RepeatMode repeat = RepeatMode.off,
    bool shuffled = false,
    Random? random,
  }) {
    final queue = PlayQueue(original: tracks, index: start, repeat: repeat);
    return shuffled ? queue.shuffle(random) : queue;
  }

  /// Tracks as they were opened.
  final List<Track> original;

  /// Play order: `order[i]` is the index in [original] of the i-th track.
  final List<int> order;

  /// Position of the current track in [tracks].
  final int index;
  final bool shuffled;
  final RepeatMode repeat;

  /// Tracks in play order, the same order as the engine's playlist.
  late final List<Track> tracks = [for (final i in order) original[i]];

  bool get isEmpty => original.isEmpty;
  Track? get current => isEmpty ? null : tracks[index];

  /// Index a manual "next" goes to, or `null` at the end of the queue with
  /// repeat off. Repeat-one still moves on, like with repeat-all.
  int? get nextIndex {
    if (isEmpty) return null;
    if (index < order.length - 1) return index + 1;
    return repeat == RepeatMode.off ? null : 0;
  }

  /// Index a manual "previous" goes to, or `null` on the first track unless
  /// the whole queue repeats.
  int? get previousIndex {
    if (isEmpty) return null;
    if (index > 0) return index - 1;
    return repeat == RepeatMode.all ? order.length - 1 : null;
  }

  PlayQueue copyWith({
    List<int>? order,
    int? index,
    bool? shuffled,
    RepeatMode? repeat,
  }) => PlayQueue(
    original: original,
    order: order ?? this.order,
    index: index ?? this.index,
    shuffled: shuffled ?? this.shuffled,
    repeat: repeat ?? this.repeat,
  );

  /// Moves the current track to the front and shuffles the rest
  /// (Fisher–Yates).
  PlayQueue shuffle([Random? random]) {
    if (isEmpty) return copyWith(shuffled: true);
    random ??= Random();
    final rest = [...order]..removeAt(index);
    for (var i = rest.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final swap = rest[i];
      rest[i] = rest[j];
      rest[j] = swap;
    }
    return copyWith(order: [order[index], ...rest], index: 0, shuffled: true);
  }

  /// Back to the opened order, still on the current track.
  PlayQueue unshuffle() => PlayQueue(
    original: original,
    index: isEmpty ? 0 : order[index],
    repeat: repeat,
  );
}
