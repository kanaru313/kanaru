/// Pieces of an artist [tag]: each is the text and, for a credited name, the
/// index of that name in [names]; null for the text around the names
/// (separators, spaces).
///
/// [names] come from the library in tag order and are substrings of the tag,
/// so each is searched for after the previous one. When one is missing (the
/// tag and the library drifted apart, or [names] belong to the previous song)
/// the whole tag is one piece linked to the first name, never text built from
/// the names. Empty [names] give the whole tag as plain text.
List<({String text, int? artist})> artistLineSegments(
  String tag,
  List<String> names,
) {
  if (names.isEmpty) return [(text: tag, artist: null)];
  final segments = <({String text, int? artist})>[];
  var cursor = 0;
  for (var i = 0; i < names.length; i++) {
    final name = names[i];
    final at = name.isEmpty ? -1 : tag.indexOf(name, cursor);
    if (at < 0) return [(text: tag, artist: 0)];
    if (at > cursor) {
      segments.add((text: tag.substring(cursor, at), artist: null));
    }
    segments.add((text: name, artist: i));
    cursor = at + name.length;
  }
  if (cursor < tag.length) {
    segments.add((text: tag.substring(cursor), artist: null));
  }
  return segments;
}
