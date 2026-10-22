import 'library_scan_prefs.dart';
import 'settings_codec_values.dart';

const _respectNomediaKey = 'respectNomedia';
const _duplicatesByFilenameKey = 'duplicatesByFilename';
const _m3uPlaylistsKey = 'm3uPlaylists';
const _albumGroupingKey = 'albumGrouping';
const _byAlbumArtistKey = 'byAlbumArtist';
const _byYearKey = 'byYear';
const _minFileSizeKbKey = 'minFileSizeKb';
const _minDurationSecondsKey = 'minDurationSeconds';
const _knownGroupingKeys = {_byAlbumArtistKey, _byYearKey};
const _knownKeys = {
  _respectNomediaKey,
  _duplicatesByFilenameKey,
  _m3uPlaylistsKey,
  _albumGroupingKey,
  _minFileSizeKbKey,
  _minDurationSecondsKey,
};

/// Reads the `libraryScan` object; each key falls back on its own. The
/// second value holds the keys this version does not know.
(LibraryScanPrefs, Map<String, Object?>) decodeLibraryScanPrefs(Object? json) {
  final map = objectOrEmpty(json);
  const d = LibraryScanPrefs();
  final grouping = objectOrEmpty(map[_albumGroupingKey]);
  return (
    LibraryScanPrefs(
      respectNomedia: boolOr(map[_respectNomediaKey], d.respectNomedia),
      duplicatesByFilename: boolOr(
        map[_duplicatesByFilenameKey],
        d.duplicatesByFilename,
      ),
      m3uPlaylists: boolOr(map[_m3uPlaylistsKey], d.m3uPlaylists),
      albumGrouping: AlbumGrouping(
        byAlbumArtist: boolOr(
          grouping[_byAlbumArtistKey],
          d.albumGrouping.byAlbumArtist,
        ),
        byYear: boolOr(grouping[_byYearKey], d.albumGrouping.byYear),
      ),
      minFileSizeKb: intInRange(
        map[_minFileSizeKbKey],
        0,
        maxMinFileSizeKb,
        d.minFileSizeKb,
      ),
      minDurationSeconds: intInRange(
        map[_minDurationSecondsKey],
        0,
        maxMinDurationSeconds,
        d.minDurationSeconds,
      ),
    ),
    {
      ...unknownEntries(map, _knownKeys),
      // Unknown parts of the grouping object ride along under its own key.
      if (unknownEntries(grouping, _knownGroupingKeys) case final rest
          when rest.isNotEmpty)
        _albumGroupingKey: rest,
    },
  );
}

/// The `libraryScan` object, with [extra] (unknown keys) carried over.
Map<String, Object?> encodeLibraryScanPrefs(
  LibraryScanPrefs prefs, {
  Map<String, Object?> extra = const {},
}) => {
  ...extra,
  _respectNomediaKey: prefs.respectNomedia,
  _duplicatesByFilenameKey: prefs.duplicatesByFilename,
  _m3uPlaylistsKey: prefs.m3uPlaylists,
  _albumGroupingKey: {
    if (extra[_albumGroupingKey] case final Map<String, Object?> rest) ...rest,
    _byAlbumArtistKey: prefs.albumGrouping.byAlbumArtist,
    _byYearKey: prefs.albumGrouping.byYear,
  },
  _minFileSizeKbKey: prefs.minFileSizeKb,
  _minDurationSecondsKey: prefs.minDurationSeconds,
};
