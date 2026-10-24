import '../settings/library_scan_prefs.dart';

/// Joins the year to the title part of an album key when albums are told
/// apart by year. U+001F never appears in a `groupKey` (control characters
/// become spaces), so the title key splits back unambiguously, and it
/// survives the base64/JSON route key.
const albumYearKeySeparator = '\u001f';

/// The grouping a scan keys with, per database: `upsertTracks` has no
/// parameter for it (the indexer passes only the artist rules), so
/// `LibraryKeys` registers the current one here before any scan runs. Per
/// instance, so tests do not leak into each other. A database opened in the
/// backfill isolate has none; the backfill gets its grouping explicitly.
/// Keyed on [Object] so this file need not import the database class.
final _groupings = Expando<AlbumGrouping>('albumGrouping');

/// The grouping the `LibraryDatabase` [db] keys scans with; the default until
/// one is registered.
AlbumGrouping albumGroupingFor(Object db) =>
    _groupings[db] ?? const AlbumGrouping();

/// Makes [grouping] the one scans of the `LibraryDatabase` [db] key with.
void useAlbumGrouping(Object db, AlbumGrouping grouping) =>
    _groupings[db] = grouping;
