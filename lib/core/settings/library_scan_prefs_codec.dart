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
const _watchFoldersKey = 'watchFolders';
const _artistSplitKey = 'artistSplit';
const _genreSplitKey = 'genreSplit';
const _separatorsKey = 'separators';
const _keepWholeKey = 'keepWhole';
const _knownSplitKeys = {_separatorsKey, _keepWholeKey};
const _knownGroupingKeys = {_byAlbumArtistKey, _byYearKey};
const _knownKeys = {
  _respectNomediaKey,
  _duplicatesByFilenameKey,
  _m3uPlaylistsKey,
  _albumGroupingKey,
  _minFileSizeKbKey,
  _minDurationSecondsKey,
  _watchFoldersKey,
  _artistSplitKey,
  _genreSplitKey,
};

/// Reads the `libraryScan` object; each key falls back on its own. The
/// second value holds the keys this version does not know.
(LibraryScanPrefs, Map<String, Object?>) decodeLibraryScanPrefs(Object? json) {
  final map = objectOrEmpty(json);
  const d = LibraryScanPrefs();
  final grouping = objectOrEmpty(map[_albumGroupingKey]);
  final artistSplit = objectOrEmpty(map[_artistSplitKey]);
  final genreSplit = objectOrEmpty(map[_genreSplitKey]);
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
      watchFolders: boolOr(map[_watchFoldersKey], d.watchFolders),
      artistSplit: _decodeSplit(artistSplit, d.artistSplit),
      genreSplit: _decodeSplit(genreSplit, d.genreSplit),
    ),
    {
      ...unknownEntries(map, _knownKeys),
      // Unknown parts of the grouping object ride along under its own key.
      if (unknownEntries(grouping, _knownGroupingKeys) case final rest
          when rest.isNotEmpty)
        _albumGroupingKey: rest,
      if (unknownEntries(artistSplit, _knownSplitKeys) case final rest
          when rest.isNotEmpty)
        _artistSplitKey: rest,
      if (unknownEntries(genreSplit, _knownSplitKeys) case final rest
          when rest.isNotEmpty)
        _genreSplitKey: rest,
    },
  );
}

SplitPrefs _decodeSplit(Map<String, Object?> json, SplitPrefs fallback) =>
    SplitPrefs(
      separators: _entries(json[_separatorsKey], fallback.separators),
      keepWhole: _entries(json[_keepWholeKey], fallback.keepWhole),
    );

/// The usable entries of a stored list: strings only, without control
/// characters, trimmed, not empty, at most [maxSplitEntryLength] characters
/// (a longer one is dropped, not cut), without repeats (any case), at most
/// [maxSplitEntries] of them. An empty list is valid (nothing splits); a
/// value that is not a list gives [fallback].
List<String> _entries(Object? value, List<String> fallback) {
  if (value is! List) return fallback;
  final seen = <String>{};
  final out = <String>[];
  for (final item in value) {
    if (out.length >= maxSplitEntries) break;
    if (item is! String) continue;
    final text = _withoutControl(item).trim();
    if (text.isEmpty || text.runes.length > maxSplitEntryLength) continue;
    if (seen.add(text.toLowerCase())) out.add(text);
  }
  return out;
}

/// [text] without U+0000-U+001F and U+007F.
String _withoutControl(String text) => String.fromCharCodes([
  for (final unit in text.codeUnits)
    if (unit >= 0x20 && unit != 0x7f) unit,
]);

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
  _watchFoldersKey: prefs.watchFolders,
  _artistSplitKey: _encodeSplit(prefs.artistSplit, extra[_artistSplitKey]),
  _genreSplitKey: _encodeSplit(prefs.genreSplit, extra[_genreSplitKey]),
};

Map<String, Object?> _encodeSplit(SplitPrefs split, Object? rest) => {
  if (rest case final Map<String, Object?> rest) ...rest,
  _separatorsKey: split.separators,
  _keepWholeKey: split.keepWhole,
};
