/// What a request's `Range` header asks for. Only one byte range is
/// served: `bytes=a-b`, `bytes=a-` or `bytes=-n`.
sealed class RangeRequest {
  const RangeRequest();

  /// Reads a `Range` header value. Null or blank: the whole body
  /// ([WholeBody]). Several ranges, another unit or a malformed range:
  /// [UnsatisfiableRange].
  factory RangeRequest.parse(String? header) {
    if (header == null || header.trim().isEmpty) return const WholeBody();
    final match = _single.firstMatch(header.trim());
    if (match == null) return const UnsatisfiableRange();
    final first = match.group(1)!;
    final last = match.group(2)!;
    if (first.isEmpty) {
      final suffix = _number(last);
      if (suffix == null || suffix == 0) return const UnsatisfiableRange();
      return SuffixRange(suffix);
    }
    final start = _number(first);
    if (start == null) return const UnsatisfiableRange();
    if (last.isEmpty) return ByteRange(start);
    final end = _number(last);
    if (end == null || end < start) return const UnsatisfiableRange();
    return ByteRange(start, end);
  }

  /// The bytes to send of a body of [total] bytes, `(start, end)` with both
  /// ends included, or null when none of it can be sent (the range starts
  /// past the end, or the body is empty).
  ({int start, int end})? within(int total);

  /// Whether the answer is a `206` with `content-range`.
  bool get partial => true;

  static int? _number(String digits) =>
      digits.length > 15 ? null : int.tryParse(digits);
}

/// No `Range`: the whole body, answered `200`.
class WholeBody extends RangeRequest {
  const WholeBody();

  @override
  bool get partial => false;

  @override
  ({int start, int end})? within(int total) =>
      total == 0 ? null : (start: 0, end: total - 1);
}

/// `bytes=start-end` or, without [end], `bytes=start-`.
class ByteRange extends RangeRequest {
  const ByteRange(this.start, [this.end]);

  final int start;
  final int? end;

  @override
  ({int start, int end})? within(int total) {
    if (start >= total) return null;
    final last = end;
    return (
      start: start,
      end: last == null || last >= total ? total - 1 : last,
    );
  }
}

/// `bytes=-length`: the last [length] bytes.
class SuffixRange extends RangeRequest {
  const SuffixRange(this.length);

  final int length;

  @override
  ({int start, int end})? within(int total) => total == 0
      ? null
      : (start: length >= total ? 0 : total - length, end: total - 1);
}

/// A `Range` that is not served: answered `416`.
class UnsatisfiableRange extends RangeRequest {
  const UnsatisfiableRange();

  @override
  ({int start, int end})? within(int total) => null;
}

final _single = RegExp(
  r'^bytes\s*=\s*(\d*)\s*-\s*(\d*)$',
  caseSensitive: false,
);
