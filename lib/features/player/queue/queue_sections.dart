/// Where a drop in the upcoming list puts a track: the play positions to give
/// `moveTrack` and whether the track ends up in the Play next run.
typedef QueueDrop = ({int from, int to, bool playNext});

/// How the queue splits into sections, as plain arithmetic on three numbers so
/// a queue of tens of thousands of tracks costs nothing to map.
///
/// - Earlier: the [played] tracks before the current one.
/// - Now playing: the track at [index].
/// - Upcoming: one list of rows. The first [playNext] rows are the Play next
///   run; when that run is not empty, one extra "Up next" header row follows
///   it (at row [playNext]) and the rest of the tracks come after the header.
///   The header is a row of the list so a drag across it moves a track into
///   or out of the run.
class QueueSections {
  QueueSections({
    required int index,
    required int playNext,
    required this.length,
  }) : index = length == 0 ? 0 : index.clamp(0, length - 1),
       playNext = playNext.clamp(
         0,
         length == 0 ? 0 : length - (index.clamp(0, length - 1)) - 1,
       );

  /// Play position of the current track.
  final int index;

  /// Tracks of the Play next run right after the current one.
  final int playNext;

  /// Tracks in the queue.
  final int length;

  /// Tracks before the current one.
  int get played => index;

  /// Tracks after the current one.
  int get upcomingTracks => length == 0 ? 0 : length - index - 1;

  /// The "Up next" header row exists only while the Play next run does.
  bool get hasUpNextHeader => playNext > 0;

  /// Rows of the upcoming list: the tracks plus the header, if any.
  int get upcomingRows => upcomingTracks + (hasUpNextHeader ? 1 : 0);

  /// Play position shown by upcoming row [row]; `null` for the header row.
  int? positionOfRow(int row) {
    if (hasUpNextHeader && row == playNext) return null;
    return index + 1 + row - (hasUpNextHeader && row > playNext ? 1 : 0);
  }

  /// Upcoming row that shows play position [position] (after the current
  /// track).
  int rowOfPosition(int position) {
    final track = position - index - 1;
    return track + (hasUpNextHeader && track >= playNext ? 1 : 0);
  }

  /// Whether upcoming row [row] is a Play next track.
  bool isPlayNextRow(int row) => row < playNext;

  /// What `moveTrack` must do for a drag of upcoming row [fromRow] that ends
  /// at row [toRow] of the list (the final row, as the reorderable list
  /// reports it). `null` when [fromRow] is the header, which cannot move.
  /// A drop on the boundary can leave the position unchanged ([from] equals
  /// [to]) while the track changes section.
  QueueDrop? drop(int fromRow, int toRow) {
    final from = positionOfRow(fromRow);
    if (from == null) return null;
    if (!hasUpNextHeader) {
      return (from: from, to: index + 1 + toRow, playNext: false);
    }
    // Row of the header once the dragged row is out of the list, then once
    // it is back at [toRow].
    final withoutDragged = fromRow < playNext ? playNext - 1 : playNext;
    final header = toRow <= withoutDragged
        ? withoutDragged + 1
        : withoutDragged;
    return (
      from: from,
      to: index + 1 + toRow - (header < toRow ? 1 : 0),
      playNext: toRow < header,
    );
  }
}
