/// Location of the playlists page.
///
/// The same text as `AppDestination.playlists.path`, repeated on purpose:
/// features cannot import `app/`. A test keeps the two equal.
const playlistsPath = '/playlists';

/// Location of the page of playlist [id].
String playlistLocation(int id) => '$playlistsPath/$id';

/// The playlist id in a route parameter: digits only and above zero, else
/// null (a typed `/playlists/abc` shows "not found" rather than failing).
int? parsePlaylistRouteId(String raw) {
  if (!RegExp(r'^[0-9]+$').hasMatch(raw)) return null;
  final id = int.tryParse(raw);
  return id == null || id <= 0 ? null : id;
}
