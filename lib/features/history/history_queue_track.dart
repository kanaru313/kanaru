import '../../core/database/library_rows.dart' show TrackListItem;
import '../../core/player/track.dart';
import '../../shared/play_tracks.dart';

/// The queue entry of a library song. The player is only ever handed the
/// `tracks` row's path, never the path a play remembers: a play outlives its
/// file, and the library row is the one the indexer vetted. [covers] is the
/// cover thumbnail folder, null when covers are off.
Track historyQueueTrack(TrackListItem track, String? covers) =>
    trackFromListItem(track, covers);
