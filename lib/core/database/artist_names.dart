/// How the indexer joins the values of a multi-value artist tag.
const artistSeparator = '; ';

/// The artist names joined in [joined] by [artistSeparator], without empty
/// parts. `'A;B'` stays one name: only the exact separator splits.
List<String> splitArtists(String? joined) {
  if (joined == null || joined.isEmpty) return const [];
  return [
    for (final part in joined.split(artistSeparator))
      if (part.isNotEmpty) part,
  ];
}
