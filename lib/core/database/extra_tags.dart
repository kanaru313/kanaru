import 'dart:convert';

/// Version of the `tracks.extra_tags` JSON. Rows whose stored `v` is lower
/// (or that have no JSON yet) are read again by the next scan, so adding a key
/// means bumping this number; no schema change is needed.
const extraTagsVersion = 1;

/// Largest stored `extra_tags` JSON, in UTF-8 bytes. Today's content is under
/// 100 bytes; the cap keeps a hostile tag from growing a row.
const maxExtraTagsBytes = 4096;

/// What the scan keeps of a file beyond the typed `tracks` columns.
class ExtraTags {
  const ExtraTags({this.releaseDate});

  /// Release date exactly as the tag wrote it (`2019`, `2019-07-15`, ...);
  /// `parseReleaseDate` turns it into parts. Null when the tag has none.
  final String? releaseDate;

  static const empty = ExtraTags();

  @override
  bool operator ==(Object other) =>
      other is ExtraTags && other.releaseDate == releaseDate;

  @override
  int get hashCode => releaseDate.hashCode;
}

/// The JSON stored in `tracks.extra_tags`: always carries `"v"`, omits keys
/// that are null, and drops any key whose value would push it over
/// [maxExtraTagsBytes].
String encodeExtraTags({String? releaseDate}) {
  final map = <String, Object>{'v': extraTagsVersion};
  if (releaseDate != null) {
    final withDate = {...map, 'releaseDate': releaseDate};
    if (utf8.encode(jsonEncode(withDate)).length <= maxExtraTagsBytes) {
      map['releaseDate'] = releaseDate;
    }
  }
  return jsonEncode(map);
}

/// Reads [json] as written by [encodeExtraTags]. Null, invalid JSON, anything
/// but an object and keys of the wrong type give [ExtraTags.empty] (or just
/// leave that key unset); unknown keys are ignored.
ExtraTags decodeExtraTags(String? json) {
  if (json == null || json.isEmpty) return ExtraTags.empty;
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return ExtraTags.empty;
  }
  if (decoded is! Map<String, Object?>) return ExtraTags.empty;
  final date = decoded['releaseDate'];
  return ExtraTags(releaseDate: date is String ? date : null);
}
