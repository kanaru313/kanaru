/// One "Label: value" line of the Song info page.
class SongInfoField {
  const SongInfoField({
    required this.id,
    required this.label,
    this.value,
    this.chips = const [],
  });

  final String id;
  final String label;

  /// The text as it is copied; null when the song has no value (Unknown).
  final String? value;

  /// Small tags under the value (the release date's).
  final List<String> chips;

  bool get isKnown => value != null;
}

class SongInfoGroup {
  const SongInfoGroup({
    required this.id,
    required this.title,
    required this.fields,
  });

  final String id;
  final String title;
  final List<SongInfoField> fields;

  /// The fields to show: all of them with [showUnknown], else those with a
  /// value.
  List<SongInfoField> visibleFields({required bool showUnknown}) => [
    for (final f in fields)
      if (showUnknown || f.isKnown) f,
  ];
}

String? infoText(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : s;
}

String? infoNumber(int? no, int? total) {
  if (no == null) return null;
  return total == null ? '$no' : '$no/$total';
}

/// [n] formatted by [fmt]; null (unknown) when missing or not positive.
String? infoCount(int? n, String Function(int) fmt) =>
    n == null || n <= 0 ? null : fmt(n);
