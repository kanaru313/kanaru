import '../core/database/library_database.dart';
import 'sort_compare.dart';

/// One artist row (Artists list, search results).
class ArtistSummary {
  const ArtistSummary({
    required this.key,
    required this.name,
    required this.songCount,
    required this.albumCount,
    this.durationMs,
  });

  /// `artistKey(name)`; identifies the artist page.
  final String key;

  /// The [preferredSpelling] among the tracks.
  final String name;
  final int songCount;

  /// Albums holding at least one of the artist's tracks.
  final int albumCount;

  /// See `ArtistCredit.durationMs`.
  final int? durationMs;
}

/// The list rows for [credits], one per artist key.
List<ArtistSummary> buildArtistSummaries(List<ArtistCredit> credits) => [
  for (final credit in credits)
    ArtistSummary(
      key: credit.key,
      name: credit.name,
      songCount: credit.trackCount,
      albumCount: credit.albumCount,
      durationMs: credit.durationMs,
    ),
];

/// Of two spellings of one artist (same key), the one shown: the smallest
/// by code point, like album titles. Any track order gives the same name,
/// on the list and on the artist page.
String preferredSpelling(String? current, String candidate) =>
    current == null || compareCodePoints(candidate, current) < 0
    ? candidate
    : current;
