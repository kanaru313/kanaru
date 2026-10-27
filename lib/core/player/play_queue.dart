import 'dart:math';

import 'repeat_mode.dart';
import 'track.dart';

// The transport commands (a part of `player_service.dart`) use the fader;
// a part cannot import, and this is the library of that file this lane may
// edit. Move to an import in `player_service.dart` when that file is free.
export 'playback_fade.dart' show playbackFadeClockProvider;
export 'playback_fade_controller.dart' show PlayPauseFader;

/// Immutable play queue: the tracks as opened, the order they play in, the
/// current position, shuffle and repeat. Every change returns a new queue.
///
/// The play order is kept as indexes into [original]. [original] only grows
/// after the queue is opened (tracks added to it go at its end), so an index
/// is never reused: removing a track only drops its index from [order]. That
/// keeps UI keys and MPRIS track ids stable, and finds the current track
/// again when the same file is queued twice.
class PlayQueue {
  PlayQueue({
    this.original = const [],
    List<int>? order,
    this.index = 0,
    this.shuffled = false,
    this.repeat = RepeatMode.off,
    this.unshuffledOrder,
  }) : assert(
         _consistent(original.length, order, unshuffledOrder),
         'order must hold unique indexes into original, and unshuffledOrder '
         'the same ones',
       ),
       order = order ?? List.generate(original.length, (i) => i);

  /// Debug check for the queue invariants: [order] has no repeats and stays
  /// inside `original`, and [unshuffledOrder] holds the same entries.
  static bool _consistent(int size, List<int>? order, List<int>? unshuffled) {
    if (order == null) return unshuffled == null || unshuffled.length == size;
    final seen = order.toSet();
    if (seen.length != order.length) return false;
    if (order.any((entry) => entry < 0 || entry >= size)) return false;
    if (unshuffled == null) return true;
    return unshuffled.length == order.length && seen.containsAll(unshuffled);
  }

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

  /// Tracks as they were opened, then those added by [insert]. Never edited
  /// otherwise, even by remove and clear.
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
    return repeat.wrapsQueue ? 0 : null;
  }

  /// Index a manual "previous" goes to, or `null` on the first track unless
  /// the whole queue repeats. Repeat all shuffled does not go back: the end of
  /// the previous pass is no meaningful place in a new random order.
  int? get previousIndex {
    if (isEmpty) return null;
    if (index > 0) return index - 1;
    return repeat == RepeatMode.all ? order.length - 1 : null;
  }

  /// Index the Next button goes to. With [wrap] (the endless queue setting,
  /// QUEUE-15) the last track goes on to the first whatever the repeat mode,
  /// and a one-track queue plays its track again. Playing on by itself never
  /// wraps: that keeps to [nextIndex].
  int? manualNextIndex({required bool wrap}) =>
      nextIndex ?? (wrap && !isEmpty ? 0 : null);

  /// Index the Previous button goes to; with [wrap] the first track goes back
  /// to the last whatever the repeat mode.
  int? manualPreviousIndex({required bool wrap}) =>
      previousIndex ?? (wrap && !isEmpty ? order.length - 1 : null);

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

  /// Puts [added] at play position [at] (`order.length` appends), in their
  /// order. They become new entries at the end of [original]; the current
  /// track stays current. While shuffled, the order shuffle goes back to gets
  /// them right after the track before [at], or at its end when appended.
  PlayQueue insert(int at, List<Track> added) {
    if (added.isEmpty || at < 0 || at > order.length) return this;
    final first = original.length;
    final entries = [for (var i = 0; i < added.length; i++) first + i];
    final unshuffled = unshuffledOrder;
    List<int>? newUnshuffled;
    if (unshuffled == null) {
      // A shuffled queue that was emptied has no saved order yet; tracks
      // added to it are in the order given, which is also the unshuffled one.
      if (shuffled && isEmpty) newUnshuffled = entries;
    } else {
      final after = at == order.length
          ? unshuffled.length
          : at == 0
          ? 0
          : unshuffled.indexOf(order[at - 1]) + 1;
      newUnshuffled = List.of(unshuffled)..insertAll(after, entries);
    }
    return PlayQueue(
      original: [...original, ...added],
      order: List.of(order)..insertAll(at, entries),
      index: !isEmpty && at <= index ? index + added.length : index,
      shuffled: shuffled,
      repeat: repeat,
      unshuffledOrder: newUnshuffled,
    );
  }

  /// Drops the track at play position [at]. When it is the current track the
  /// next one slides into its position; past the end, repeat all wraps to
  /// the first (both repeat all modes) and otherwise the new last track
  /// becomes current.
  PlayQueue removeAt(int at) {
    if (at < 0 || at >= order.length) return this;
    final entry = order[at];
    final rest = [...order]..removeAt(at);
    var newIndex = index;
    if (at < index) {
      newIndex = index - 1;
    } else if (at == index) {
      if (index >= rest.length) {
        newIndex = repeat.wrapsQueue || rest.isEmpty ? 0 : rest.length - 1;
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

  /// Drops every track but the current one. [original] shrinks to that
  /// track too, so a queue that grew by adding tracks does not keep every
  /// dropped one for the rest of the session.
  PlayQueue keepOnlyCurrent() {
    if (isEmpty) return this;
    return PlayQueue(
      original: [current!],
      order: const [0],
      shuffled: shuffled,
      repeat: repeat,
      unshuffledOrder: shuffled ? const [0] : null,
    );
  }

  /// Moves the current track to the front and shuffles the rest
  /// (Fisher–Yates), except that the [keepNext] tracks right after the
  /// current one stay there, in order. The order before is kept for
  /// [unshuffle].
  PlayQueue shuffle([Random? random, int keepNext = 0]) {
    if (isEmpty) return copyWith(shuffled: true);
    random ??= Random();
    final kept = order.sublist(
      index + 1,
      min(order.length, index + 1 + max(0, keepNext)),
    );
    final rest = [
      for (var i = 0; i < order.length; i++)
        if (i != index && (i <= index || i > index + kept.length)) order[i],
    ];
    for (var i = rest.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final swap = rest[i];
      rest[i] = rest[j];
      rest[j] = swap;
    }
    return PlayQueue(
      original: original,
      order: [order[index], ...kept, ...rest],
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
