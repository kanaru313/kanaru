import '../play_queue.dart';
import '../player_state.dart';
import '../repeat_mode.dart';
import '../track.dart';

/// What is needed to bring playback back after a restart: the queue as the
/// [PlayQueue] holds it (so a shuffled order comes back exactly), which
/// tracks "play next" put in that have not played yet, where in the current
/// track it was, and the volume. Whether it was playing is not kept: a
/// restored session always starts paused.
class PlaybackSession {
  const PlaybackSession({
    this.tracks = const [],
    this.order = const [],
    this.unshuffledOrder,
    this.index = 0,
    this.shuffled = false,
    this.repeat = RepeatMode.off,
    this.position = Duration.zero,
    this.volume = 100,
    this.volumeBeforeMute,
    this.upNext = const [],
  });

  /// Snapshot of [state] at [position]. The position is passed in because
  /// the engine's last tick is not always the one worth keeping (it reports
  /// a stray zero right after a paused open).
  ///
  /// [upNext] is the player's set of entries (indexes into
  /// `PlayQueue.original`) put in by "play next" that have not played yet.
  factory PlaybackSession.fromState(
    PlayerState state, {
    required Duration position,
    Iterable<int> upNext = const [],
  }) {
    final queue = state.queue;
    return PlaybackSession(
      tracks: queue.original,
      order: queue.order,
      unshuffledOrder: queue.unshuffledOrder,
      index: queue.isEmpty ? 0 : queue.index,
      shuffled: queue.shuffled,
      repeat: queue.repeat,
      position: queue.isEmpty ? Duration.zero : position,
      volume: state.volume,
      volumeBeforeMute: state.volumeBeforeMute,
      upNext: queue.isEmpty ? const [] : List.unmodifiable(upNext),
    );
  }

  /// `PlayQueue.original`: the tracks opened and those added later. Removed
  /// ones are dropped when the session is restored (`toQueue`).
  final List<Track> tracks;

  /// `PlayQueue.order`: indexes into [tracks] in play order.
  final List<int> order;
  final List<int>? unshuffledOrder;

  /// Position of the current track in [order].
  final int index;
  final bool shuffled;
  final RepeatMode repeat;

  /// Where in the current track playback was.
  final Duration position;

  /// 0–100; 0 while muted.
  final double volume;

  /// Volume to go back to on unmute; `null` when not muted.
  final double? volumeBeforeMute;

  /// Indexes into [tracks] of the "play next" tracks that have not played
  /// yet, so the next "play next" still goes behind them after a restart.
  /// See [restoredUpNext] for the entries that count.
  final List<int> upNext;

  /// Whether there is a track to restore.
  bool get hasTrack => order.isNotEmpty;

  /// The same session at another [position].
  PlaybackSession withPosition(Duration position) => PlaybackSession(
    tracks: tracks,
    order: order,
    unshuffledOrder: unshuffledOrder,
    index: index,
    shuffled: shuffled,
    repeat: repeat,
    position: position,
    volume: volume,
    volumeBeforeMute: volumeBeforeMute,
    upNext: upNext,
  );

  /// The queue as it was. Tracks no longer in [order] (removed ones) are
  /// dropped and the indexes renumbered, so [tracks] does not grow for as
  /// long as the queue is edited across restarts.
  PlayQueue toQueue() {
    final renumbered = _renumbering();
    if (renumbered == null) {
      return PlayQueue(
        original: tracks,
        order: order,
        index: index,
        shuffled: shuffled,
        repeat: repeat,
        unshuffledOrder: unshuffledOrder,
      );
    }
    List<int> renumber(List<int> entries) => [
      for (final entry in entries) renumbered[entry]!,
    ];
    return PlayQueue(
      original: [for (final entry in renumbered.keys) tracks[entry]],
      order: renumber(order),
      index: index,
      shuffled: shuffled,
      repeat: repeat,
      unshuffledOrder: unshuffledOrder == null
          ? null
          : renumber(unshuffledOrder!),
    );
  }

  /// The entries of [upNext] in the numbering of [toQueue], kept only when
  /// they are still to come: in the order after the current track. A broken
  /// or stale entry is dropped, never an error.
  Set<int> restoredUpNext() {
    if (upNext.isEmpty || order.isEmpty) return const {};
    final renumbered = _renumbering();
    final ahead = order.sublist(index + 1).toSet();
    return {
      for (final entry in upNext)
        if (ahead.contains(entry))
          renumbered == null ? entry : renumbered[entry]!,
    };
  }

  /// Old entry to new entry for the tracks still in [order], in the order of
  /// [tracks], when removed ones are to be dropped; `null` when every track
  /// is kept as it is.
  Map<int, int>? _renumbering() {
    if (order.length >= tracks.length) return null;
    final kept = [...order]..sort();
    return {for (var i = 0; i < kept.length; i++) kept[i]: i};
  }

  @override
  bool operator ==(Object other) =>
      other is PlaybackSession &&
      other.index == index &&
      other.shuffled == shuffled &&
      other.repeat == repeat &&
      other.position == position &&
      other.volume == volume &&
      other.volumeBeforeMute == volumeBeforeMute &&
      _sameTracks(other.tracks, tracks) &&
      _sameInts(other.order, order) &&
      _sameInts(other.unshuffledOrder, unshuffledOrder) &&
      _sameInts(other.upNext, upNext);

  @override
  int get hashCode => Object.hash(
    index,
    shuffled,
    repeat,
    position,
    volume,
    volumeBeforeMute,
    tracks.length,
    order.length,
    upNext.length,
  );
}

bool _sameInts(List<int>? a, List<int>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Same files with the same metadata: [Track]'s `==` only looks at the URI,
/// but a changed title is worth saving too.
bool _sameTracks(List<Track> a, List<Track> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    if (identical(x, y)) continue;
    if (x.uri != y.uri ||
        x.title != y.title ||
        x.artist != y.artist ||
        x.artUri != y.artUri ||
        x.duration != y.duration ||
        x.album != y.album ||
        x.year != y.year) {
      return false;
    }
  }
  return true;
}
