import 'library_rows.dart';
import 'playlist_cover_keys.dart';

/// A playlist as lists show it; [entryCount] counts entries, duplicates
/// included.
class PlaylistSummary {
  const PlaylistSummary({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.entryCount,
    this.isFavorites = false,
  });

  final int id;
  final String name;

  /// Milliseconds since the epoch.
  final int createdAt;
  final int entryCount;

  /// Whether this is the Favorites playlist (`kind = 'favorites'`): shown
  /// with the localized name, never renamed or deleted.
  final bool isFavorites;

  @override
  bool operator ==(Object other) =>
      other is PlaylistSummary &&
      other.id == id &&
      other.name == name &&
      other.createdAt == createdAt &&
      other.entryCount == entryCount &&
      other.isFavorites == isFavorites;

  @override
  int get hashCode => Object.hash(id, name, createdAt, entryCount, isFavorites);
}

/// Whether [a] and [b] hold equal summaries in the same order.
bool samePlaylistSummaries(List<PlaylistSummary> a, List<PlaylistSummary> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A summary with its collage keys (see `pickCollageKeys`).
class PlaylistCard {
  const PlaylistCard(this.playlist, this.coverKeys);

  final PlaylistSummary playlist;
  final List<String> coverKeys;
}

/// One entry, in order. [track] is null when no library track has [path]
/// (file removed, folder removed or moved): shown, movable, not playable.
class PlaylistEntryRow {
  const PlaylistEntryRow({
    required this.entryId,
    required this.path,
    this.track,
  });

  final int entryId;
  final String path;
  final TrackListItem? track;
}

/// Everything the playlist page shows, read in one transaction.
class PlaylistPage {
  PlaylistPage({required this.playlist, required this.entries})
    : coverKeys = pickCollageKeys(entries.map((e) => e.track?.coverKey));

  final PlaylistSummary playlist;
  final List<PlaylistEntryRow> entries;
  final List<String> coverKeys;
}

/// What the header of the playlist page shows, without any entry: the
/// summary (with the entry count), the collage and whether anything can play.
/// No `==`: the page view tells a fresh read from a repeated one by identity.
class PlaylistPageHead {
  PlaylistPageHead({
    required this.playlist,
    required this.coverKeys,
    required this.hasPlayable,
  });

  final PlaylistSummary playlist;
  final List<String> coverKeys;

  /// Whether at least one entry has its file in the library.
  final bool hasPlayable;
}

/// An entry with the position it is stored at. Positions are dense
/// (`0..n-1`) in a healthy playlist; a reader that places rows by position
/// copes with a gap or a duplicate left by an outside tool.
class PlaylistPositionedEntry {
  const PlaylistPositionedEntry(this.position, this.entry);

  final int position;
  final PlaylistEntryRow entry;
}

/// An entry whose file is in the library, for building a play queue.
class PlaylistPlayableTrack {
  const PlaylistPlayableTrack({
    required this.entryId,
    required this.position,
    required this.track,
  });

  final int entryId;
  final int position;
  final TrackListItem track;
}
