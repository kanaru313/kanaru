import '../play_queue.dart';
import '../player_state.dart';
import '../repeat_mode.dart';
import '../track.dart';

/// What is needed to bring playback back after a restart: the queue as the
/// [PlayQueue] holds it (so a shuffled order comes back exactly), where in
/// the current track it was, and the volume. Whether it was playing is not
/// kept: a restored session always starts paused.
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
  });

  /// Snapshot of [state] at [position]. The position is passed in because
  /// the engine's last tick is not always the one worth keeping (it reports
  /// a stray zero right after a paused open).
  factory PlaybackSession.fromState(
    PlayerState state, {
    required Duration position,
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
    );
  }

  /// `PlayQueue.original`: every track as opened, removed ones included.
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

  /// Whether there is a track to restore.
  bool get hasTrack => order.isNotEmpty;

  /// The queue as it was. Tracks no longer in [order] (removed ones) are
  /// dropped and the indexes renumbered, so [tracks] does not grow for as
  /// long as the queue is edited across restarts.
  PlayQueue toQueue() {
    if (order.length >= tracks.length) {
      return PlayQueue(
        original: tracks,
        order: order,
        index: index,
        shuffled: shuffled,
        repeat: repeat,
        unshuffledOrder: unshuffledOrder,
      );
    }
    final kept = [...order]..sort();
    final renumbered = {for (var i = 0; i < kept.length; i++) kept[i]: i};
    List<int> renumber(List<int> entries) => [
      for (final entry in entries) renumbered[entry]!,
    ];
    return PlayQueue(
      original: [for (final entry in kept) tracks[entry]],
      order: renumber(order),
      index: index,
      shuffled: shuffled,
      repeat: repeat,
      unshuffledOrder: unshuffledOrder == null
          ? null
          : renumber(unshuffledOrder!),
    );
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
      _sameInts(other.unshuffledOrder, unshuffledOrder);

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
        x.duration != y.duration) {
      return false;
    }
  }
  return true;
}
