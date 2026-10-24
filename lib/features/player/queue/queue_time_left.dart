import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide RepeatMode;

import '../../../core/player/play_queue.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/repeat_mode.dart';
import '../../../l10n/l10n.dart';

/// Length of the current track and every track after it, or `null` when that
/// is not meaningful: an empty queue, repeat on (the queue never runs out),
/// or any of those tracks without a known duration (folder queues have none).
/// Walks the whole queue once, so callers cache it per queue and index.
Duration? queueRemainingDuration(PlayQueue queue) {
  if (queue.isEmpty || queue.repeat != RepeatMode.off) return null;
  var total = Duration.zero;
  for (var i = queue.index; i < queue.order.length; i++) {
    final duration = queue.trackAt(i).duration;
    if (duration == null) return null;
    total += duration;
  }
  return total;
}

/// What is left to play: [queueRemainingDuration] minus the part of the
/// current track already played ([position], capped at that track's length).
/// `null` when not meaningful.
Duration? queueTimeLeft(PlayQueue queue, Duration position) {
  final remaining = queueRemainingDuration(queue);
  if (remaining == null) return null;
  return _minusPlayed(remaining, queue, position);
}

Duration _minusPlayed(Duration remaining, PlayQueue queue, Duration position) {
  final current = queue.current?.duration ?? Duration.zero;
  final played = position > current ? current : position;
  final left = remaining - (played.isNegative ? Duration.zero : played);
  return left.isNegative ? Duration.zero : left;
}

/// Whole minutes in [left], rounded up so a track that has seconds left
/// never reads "0 min left" while it still plays.
int ceilMinutes(Duration left) =>
    (left.inMicroseconds + Duration.microsecondsPerMinute - 1) ~/
    Duration.microsecondsPerMinute;

/// "{N tracks}", plus " · {X left}" when the time left is meaningful. Only
/// this widget follows the playback position, and it rebuilds only when the
/// displayed minute changes, so the rest of the header stays still.
class QueueSummaryText extends ConsumerStatefulWidget {
  const QueueSummaryText({super.key, this.style});

  final TextStyle? style;

  @override
  ConsumerState<QueueSummaryText> createState() => _QueueSummaryTextState();
}

class _QueueSummaryTextState extends ConsumerState<QueueSummaryText> {
  // The O(n) sum, kept until the queue object or the current index changes.
  PlayQueue? _cachedQueue;
  int _cachedIndex = -1;
  Duration? _cachedRemaining;

  Duration? _remainingOf(PlayQueue queue) {
    if (!identical(queue, _cachedQueue) || queue.index != _cachedIndex) {
      _cachedQueue = queue;
      _cachedIndex = queue.index;
      _cachedRemaining = queueRemainingDuration(queue);
    }
    return _cachedRemaining;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Selects the minutes shown, not the position: ticks that leave the text
    // as it is do not rebuild.
    final tracks = ref.watch(
      playerServiceProvider.select((s) => s.queue.order.length),
    );
    // Mutating the cache inside select is safe: it is a pure memo keyed on
    // the queue object and index, and the same inputs give the same result.
    final minutesLeft = ref.watch(
      playerServiceProvider.select((s) {
        final remaining = _remainingOf(s.queue);
        if (remaining == null) return null;
        final minutes = ceilMinutes(
          _minusPlayed(remaining, s.queue, s.position),
        );
        // Nothing worth saying once the last track is about to end.
        return minutes > 0 ? minutes : null;
      }),
    );
    final count = l10n.queueTrackCount(tracks);
    final String text;
    if (minutesLeft == null) {
      text = count;
    } else {
      final hours = minutesLeft ~/ 60;
      final minutes = minutesLeft % 60;
      final left = hours > 0
          ? l10n.queueTimeLeftHours(hours, minutes)
          : l10n.queueTimeLeftMinutes(minutes);
      text = l10n.queueSummary(count, left);
    }
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}
