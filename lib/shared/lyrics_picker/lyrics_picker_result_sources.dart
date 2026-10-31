import '../../core/lyrics/online/lyrics_search_controller.dart';

/// The sources that returned results, with how many each returned, in the
/// order of their first result.
List<({String id, int count})> lyricsResultSources(
  List<RankedCandidate> results,
) {
  final counts = <String, int>{};
  for (final r in results) {
    counts.update(r.candidate.providerId, (n) => n + 1, ifAbsent: () => 1);
  }
  return [for (final e in counts.entries) (id: e.key, count: e.value)];
}

/// [filter] when one of [sources] returned results, else `null` (every
/// source). A filter on a source that has none (after a new search) is
/// therefore no filter.
String? effectiveSourceFilter(
  String? filter,
  List<({String id, int count})> sources,
) => sources.any((s) => s.id == filter) ? filter : null;
