import 'dart:math';

import 'repeat_mode.dart';
import 'track.dart';

/// Immutable play queue: the tracks as opened, the order they play in, the
/// current position, shuffle and repeat. Every change returns a new queue.
///
/// The play order is kept as indexes into [original]. [original] never changes
/// after the queue is opened, so an index is never reused: removing a track
/// only drops its index from [order]. That keeps UI keys and MPRIS track ids
/// stable, and finds the current track again when the same file is queued
/// twice.
class PlayQueue {
  PlayQueue({
    this.original = const [],
    List<int>? order,
    this.index = 0,
    this.shuffled = false,
    this.repeat = RepeatMode.off,
    this.unshuffledOrder,
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
    assert(start >= 0 && start < tracks.length, 'start $start out of range');
    final queue = PlayQueue(original: tracks, index: start, repeat: repeat);
    return shuffled ? queue.shuffle(random) : queue;
  }

  /// Tracks as they were opened. Never edited, even by remove and clear.
  final List<Track> original;

  /// Play order: `order[i]` is the index in [original] of the i-th track.
  /// Has no repeats; indexes of removed tracks are missing.
  final List<int> order;

  /// Position of the current track in [tracks].
  final int index;
  final bool shuffled;
  final RepeatMode repeat;

  /// While [shuffled]: the order that comes back when shuffle is turned off
  /// (same entries as [order]). `null` when not shuffled, as [order] is then
  /// the order the user arranged.
  final List<int>? unshuffledOrder;

  /// Tracks in play order, the same order as the engine's playlist. Built on
  /// first use (for the queue panel); playback reads [trackAt] instead, so a
  /// track change never copies the whole queue.
  late final List<Track> tracks = [for (final i in order) original[i]];

  /// The track at play position [i], without building [tracks].
  Track trackAt(int i) => original[order[i]];

  bool get isEmpty => order.isEmpty;
  Track? get current => isEmpty ? null : trackAt(index);

  /// Index a manual "next" goes to, or `null` on the last track unless the
  /// whole queue repeats. Repeat-one still moves on within the queue.
  int? get nextIndex {
    if (isEmpty) return null;
    if (index < order.length - 1) return index + 1;
    return repeat == RepeatMode.all ? 0 : null;
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
    unshuffledOrder: unshuffledOrder,
  );

  /// Moves the track at play position [from] so it ends up at [to]. The
  /// current track keeps playing; only its position follows. Out-of-range
  /// positions and `from == to` leave the queue as it is.
  PlayQueue move(int from, int to) {
    final length = order.length;
    if (from < 0 || from >= length || to < 0 || to >= length || from == to) {
      return this;
    }
    // One copy plus a block shift; spreading and insert/remove would each
    // walk the whole list, which is slow on a queue of a whole library.
    final moved = List<int>.of(order);
    if (from < to) {
      moved.setRange(from, to, order, from + 1);
    } else {
      moved.setRange(to + 1, from + 1, order, to);
    }
    moved[to] = order[from];
    var newIndex = index;
    if (from == index) {
      newIndex = to;
    } else if (from < index && to >= index) {
      newIndex = index - 1;
    } else if (from > index && to <= index) {
      newIndex = index + 1;
    }
    return copyWith(order: moved, index: newIndex);
  }

  /// Drops the track at play position [at]. When it is the current track the
  /// next one slides into its position; past the end, repeat all wraps to
  /// the first and otherwise the new last track becomes current.
  PlayQueue removeAt(int at) {
    if (at < 0 || at >= order.length) return this;
    final entry = order[at];
    final rest = [...order]..removeAt(at);
    var newIndex = index;
    if (at < index) {
      newIndex = index - 1;
    } else if (at == index) {
      if (index >= rest.length) {
        newIndex = repeat == RepeatMode.all || rest.isEmpty
            ? 0
            : rest.length - 1;
      }
    }
    final unshuffled = unshuffledOrder;
    return PlayQueue(
      original: original,
      order: rest,
      index: newIndex,
      shuffled: shuffled,
      repeat: repeat,
      unshuffledOrder: unshuffled == null
          ? null
          : [
              for (final e in unshuffled)
                if (e != entry) e,
            ],
    );
  }

  /// Drops every track but the current one.
  PlayQueue keepOnlyCurrent() {
    if (isEmpty) return this;
    final only = [order[index]];
    return PlayQueue(
      original: original,
      order: only,
      shuffled: shuffled,
      repeat: repeat,
      unshuffledOrder: shuffled ? [...only] : null,
    );
  }

  /// Moves the current track to the front and shuffles the rest
  /// (Fisher–Yates). The order before is kept for [unshuffle].
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
    return PlayQueue(
      original: original,
      order: [order[index], ...rest],
      shuffled: true,
      repeat: repeat,
      unshuffledOrder: unshuffledOrder ?? order,
    );
  }

  /// Back to the order from before shuffling (minus removed tracks), still on
  /// the current track. Dragging done while shuffled is lost. Without a saved
  /// order the opened order is used.
  PlayQueue unshuffle() {
    final restored = unshuffledOrder ?? ([...order]..sort());
    return PlayQueue(
      original: original,
      order: restored,
      index: isEmpty ? 0 : restored.indexOf(order[index]),
      repeat: repeat,
    );
  }
}
