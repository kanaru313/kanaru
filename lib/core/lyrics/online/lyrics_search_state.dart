import 'lyrics_fetch_exception.dart';
import 'lyrics_match.dart';
import 'lyrics_match_keys.dart';
import 'lyrics_provider.dart';
import 'lyrics_target.dart';

/// Most results the manual search lists.
const maxSearchResults = 20;

/// How far one provider's part of a search has come.
enum ProviderSearchPhase { searching, done, error }

/// One provider's part of a search. [kind] is the request error when
/// [phase] is [ProviderSearchPhase.error] (`null` for anything else that
/// went wrong).
class ProviderSearchState {
  const ProviderSearchState(this.phase, [this.kind]);

  final ProviderSearchPhase phase;
  final LyricsFetchKind? kind;
}

/// A search result with the verdict of the match gate for the song.
class RankedCandidate {
  const RankedCandidate(this.candidate, this.match);

  final LyricsCandidate candidate;
  final LyricsMatch match;

  /// Marked "Not these lyrics" earlier; listed last and never auto-selected.
  bool get rejected => match.rejected;

  /// Has something to pick: words or the instrumental flag.
  bool get selectable {
    final body = candidate.body;
    return body != null && (body.hasLyrics || body.instrumental);
  }
}

class LyricsSearchState {
  const LyricsSearchState({
    required this.query,
    this.byProvider = const {},
    this.results = const [],
    this.selected,
  });

  /// The text last searched, or the prefilled one before the first search.
  final String query;

  /// Provider id to its part of the current search; empty before a search.
  final Map<String, ProviderSearchState> byProvider;

  /// At most [maxSearchResults], best first.
  final List<RankedCandidate> results;

  /// Index into [results]; `null` when nothing is selected.
  final int? selected;

  bool get searching =>
      byProvider.values.any((s) => s.phase == ProviderSearchPhase.searching);

  RankedCandidate? get selection =>
      selected == null ? null : results[selected!];

  LyricsSearchState copyWith({
    String? query,
    Map<String, ProviderSearchState>? byProvider,
    List<RankedCandidate>? results,
    required int? selected,
  }) => LyricsSearchState(
    query: query ?? this.query,
    byProvider: byProvider ?? this.byProvider,
    results: results ?? this.results,
    selected: selected,
  );
}

/// The text the search box starts with: `"{primary artist} {title}"`.
String lyricsSearchPrefill(LyricsTarget target) {
  final artist = primaryArtist(target.query.artist)?.trim();
  final title = target.query.title?.trim();
  return [
    if (artist != null && artist.isNotEmpty) artist,
    if (title != null && title.isNotEmpty) title,
  ].join(' ');
}
