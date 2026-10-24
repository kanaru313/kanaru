import '../l10n/app_localizations.dart';

/// The artist line of an album: "Various artists" for an album merged from
/// several album artists, else [artist], else "Unknown artist". One rule for
/// every tile and header.
String albumArtistLabel(
  AppLocalizations l10n, {
  String? artist,
  bool variousArtists = false,
}) => variousArtists
    ? l10n.albumVariousArtists
    : artist ?? l10n.albumsUnknownArtist;
