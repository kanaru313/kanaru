/// A media type with optional parameters, `type/subtype; name=value`.
final _mediaType = RegExp(
  r'^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+'
  r'(\s*;\s*[a-z0-9_-]+=("[^"\x00-\x1f]*"|[a-z0-9._-]+))*$',
  caseSensitive: false,
);

final _control = RegExp(r'[\x00-\x1f\x7f]');

/// [value] when it is a media type that may go into a `content-type`
/// header as it is (no control characters, nothing but a type and simple
/// parameters), else null. Neither the plugin's type nor the upstream's is
/// ever copied unchecked.
String? safeMediaType(String? value) {
  if (value == null || _control.hasMatch(value)) return null;
  return _mediaType.hasMatch(value) ? value : null;
}

final _contentRange = RegExp(r'^bytes\s+(\d{1,15})-(\d{1,15})/(\d{1,15}|\*)$');

/// The parts of a `206` answer's `Content-Range: bytes start-end/total`;
/// [total] is null for `*`. Null when [value] does not have that shape or
/// its ends are out of order.
({int start, int end, int? total})? parseContentRange(String? value) {
  if (value == null) return null;
  final match = _contentRange.firstMatch(value.trim());
  if (match == null) return null;
  final start = int.parse(match.group(1)!);
  final end = int.parse(match.group(2)!);
  final total = int.tryParse(match.group(3)!);
  if (end < start || (total != null && end >= total)) return null;
  return (start: start, end: end, total: total);
}

/// The total of a `416` answer's `Content-Range: bytes */total`, or null.
int? unsatisfiedRangeTotal(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^bytes\s+\*/(\d{1,15})$').firstMatch(value.trim());
  return match == null ? null : int.parse(match.group(1)!);
}
