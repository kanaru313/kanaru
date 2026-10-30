import 'lyrics_candidate_checks.dart';
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

/// How far the fetch of one result's lyrics has come (a result the search
/// answered without them).
enum BodyFetchPhase { loading, failed }

/// The fetch of one result's lyrics. [kind] is the request error when [phase]
/// is [BodyFetchPhase.failed] (`null` for anything else that went wrong).
class BodyFetchState {
  const BodyFetchState(this.phase, [this.kind]);

  final BodyFetchPhase phase;
  final LyricsFetchKind? kind;
}

/// A search result with the verdict of the match gate for the song.
class RankedCandidate {
  const RankedCandidate(this.candidate, this.match, {this.bodyMissing = false});

  final LyricsCandidate candidate;
  final LyricsMatch match;

  /// The lyrics were fetched and the provider has none (or nothing usable).
  final bool bodyMissing;

  /// Marked "Not these lyrics" earlier; listed last and never auto-selected.
  bool get rejected => match.rejected;

  /// Has its lyrics (words or the instrumental flag): can be picked.
  bool get hasBody => candidate.hasBody;

  /// Can be selected in the list: has its lyrics, or has not been asked for
  /// them yet or is being asked (selecting it fetches them).
  bool get selectable => hasBody || (candidate.body == null && !bodyMissing);
}

class LyricsSearchState {
  const LyricsSearchState({
    required this.query,
    this.byProvider = const {},
    this.results = const [],
    this.selected,
    this.bodyFetches = const {},
  });

  /// The text last searched, or the prefilled one before the first search.
  final String query;

  /// Provider id to its part of the current search; empty before a search.
  final Map<String, ProviderSearchState> byProvider;

  /// At most [maxSearchResults], best first.
  final List<RankedCandidate> results;

  /// Index into [results]; `null` when nothing is selected.
  final int? selected;

  /// The running or failed fetches of lyrics, by result. A finished fetch
  /// is not listed: its lyrics are in the result's candidate.
  final Map<({String providerId, String remoteId}), BodyFetchState> bodyFetches;

  bool get searching =>
      byProvider.values.any((s) => s.phase == ProviderSearchPhase.searching);

  RankedCandidate? get selection =>
      selected == null ? null : results[selected!];

  /// The fetch state of the selected result, if one is running or failed.
  BodyFetchState? get selectionFetch {
    final s = selection;
    return s == null ? null : bodyFetches[s.candidate.ref];
  }

  LyricsSearchState copyWith({
    String? query,
    Map<String, ProviderSearchState>? byProvider,
    List<RankedCandidate>? results,
    required int? selected,
    Map<({String providerId, String remoteId}), BodyFetchState>? bodyFetches,
  }) => LyricsSearchState(
    query: query ?? this.query,
    byProvider: byProvider ?? this.byProvider,
    results: results ?? this.results,
    selected: selected,
    bodyFetches: bodyFetches ?? this.bodyFetches,
  );
}

/// The text the search box starts with: `"{primary artist} {title}"`. A
/// placeholder artist ("Unknown Artist") is left out.
String lyricsSearchPrefill(LyricsTarget target) {
  var artist = primaryArtist(target.query.artist)?.trim();
  if (artist != null && isUnknownArtist(artist)) artist = null;
  final title = target.query.title?.trim();
  return [
    if (artist != null && artist.isNotEmpty) artist,
    if (title != null && title.isNotEmpty) title,
  ].join(' ');
}
