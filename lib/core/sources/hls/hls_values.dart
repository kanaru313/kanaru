import 'dart:typed_data';

import 'hls_limits.dart';
import 'hls_models.dart';
import 'hls_refusal.dart';

final _digits = RegExp(r'^[0-9]+$');
final _decimal = RegExp(r'^[0-9]+(\.[0-9]*)?$');
final _iv = RegExp(r'^0[xX]([0-9a-fA-F]{32})$');

/// A non-negative decimal integer of at most 15 digits, or null.
int? parseHlsUnsigned(String? text) {
  if (text == null || text.length > 15 || !_digits.hasMatch(text)) return null;
  return int.parse(text);
}

/// An `EXTINF` duration: a plain decimal (no sign, no exponent, no `NaN`)
/// longer than zero and at most [hlsMaxSegmentDuration]; null otherwise.
Duration? parseHlsDuration(String text) {
  if (!_decimal.hasMatch(text)) return null;
  final seconds = double.parse(text);
  if (!seconds.isFinite) return null;
  final microseconds = (seconds * Duration.microsecondsPerSecond).round();
  if (microseconds < 1 || microseconds > hlsMaxSegmentDuration.inMicroseconds) {
    return null;
  }
  return Duration(microseconds: microseconds);
}

/// An `IV` attribute: `0x` and exactly 32 hex digits → 16 bytes; null
/// otherwise.
Uint8List? parseHlsIv(String text) {
  final match = _iv.firstMatch(text);
  if (match == null) return null;
  final hex = match.group(1)!;
  return Uint8List.fromList([
    for (var i = 0; i < 32; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

/// `<length>[@<offset>]` of `EXT-X-BYTERANGE` and the `BYTERANGE` attribute.
/// [length] ≥ 1; [offset] null when the text has none. Null: malformed.
({int length, int? offset})? parseHlsByteRangeText(String? text) {
  if (text == null) return null;
  final parts = text.split('@');
  if (parts.length > 2) return null;
  final length = parseHlsUnsigned(parts[0]);
  if (length == null || length < 1) return null;
  if (parts.length == 1) return (length: length, offset: null);
  final offset = parseHlsUnsigned(parts[1]);
  if (offset == null) return null;
  return (length: length, offset: offset);
}

/// Completes a parsed byte range with [implicitOffset] when it has no
/// offset (null: an offset is required). `invalid` without an offset to use,
/// or ending past [hlsMaxByteRangeEnd].
HlsByteRange completeHlsByteRange(
  ({int length, int? offset}) parsed,
  int? implicitOffset,
) {
  final offset = parsed.offset ?? implicitOffset;
  if (offset == null || offset + parsed.length > hlsMaxByteRangeEnd) {
    throw const HlsRefusal(HlsRefusalKind.invalid);
  }
  return HlsByteRange(offset: offset, length: parsed.length);
}

/// Resolves a URI from a playlist against [base]. Empty or unparseable →
/// `invalid`; longer than [hlsMaxUriLength] → `tooLarge`. Which hosts and
/// schemes are allowed is the loader's call, not this one's.
Uri resolveHlsUri(Uri base, String? text) {
  if (text == null || text.isEmpty) {
    throw const HlsRefusal(HlsRefusalKind.invalid);
  }
  if (text.length > hlsMaxUriLength) {
    throw const HlsRefusal(HlsRefusalKind.tooLarge);
  }
  try {
    return base.resolveUri(Uri.parse(text));
  } on FormatException {
    throw const HlsRefusal(HlsRefusalKind.invalid);
  }
}
