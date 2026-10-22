import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';

/// The name to show for [playlist]: the localized "Favorites" for the
/// Favorites playlist (its stored name is only a fallback), else its name.
String playlistDisplayName(PlaylistSummary playlist, AppLocalizations l10n) =>
    playlist.isFavorites ? l10n.navFavorites : playlist.name;
