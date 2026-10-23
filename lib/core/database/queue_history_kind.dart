import 'playlist_favorites.dart' show queueKind;

/// `playlists.kind` of a saved queue (invariant 8 of `user_data_tables.dart`):
/// one row per queue the user replaced. Playlist lists leave these rows out.
const queueSnapshotKind = queueKind;

/// Most saved queues kept: saving one more deletes the oldest in the same
/// transaction.
const queueSnapshotLimit = 20;

/// Fewest tracks a queue needs to be worth saving: a single track picked from
/// search is not a queue anyone goes back to.
const queueSnapshotMinTracks = 2;

/// `playlists.name` of a saved queue. Never shown: the page names a saved
/// queue by when it was saved, in the user's language.
const queueSnapshotStoredName = 'Queue';
