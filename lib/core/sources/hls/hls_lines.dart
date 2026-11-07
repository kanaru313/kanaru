import 'dart:convert';
import 'dart:typed_data';

import 'hls_limits.dart';
import 'hls_refusal.dart';

/// One meaningful line of a playlist.
sealed class HlsLine {
  const HlsLine();
}

/// A `#EXT…` tag: [name] without the `#` (`EXT-X-KEY`), [value] the text
/// after the first `:`, null when there is no colon.
final class HlsTag extends HlsLine {
  const HlsTag(this.name, this.value);

  final String name;
  final String? value;
}

/// A line that is not a tag or comment: a URI.
final class HlsUriLine extends HlsLine {
  const HlsUriLine(this.text);

  final String text;
}

/// Splits playlist [bytes] into lines (LF or CRLF, optional UTF-8 BOM) and
/// drops blank lines and `#` comments. The first line must be `#EXTM3U`.
///
/// Invalid UTF-8, a missing or late `#EXTM3U` → `invalid`; a line over
/// [hlsMaxLineBytes] → `tooLarge`. It stops as soon as the playlist has more
/// URI lines than [hlsMaxSegments], more `EXT-X-STREAM-INF` tags than
/// [hlsMaxVariants] or more `EXT-X-MEDIA` tags than [hlsMaxRenditions]
/// (`tooLarge` too), so a body of short lines never costs a line object each.
List<HlsLine> lexHlsPlaylist(List<int> bytes) {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  var start = _hasBom(data) ? 3 : 0;
  final lines = <HlsLine>[];
  var first = true;
  var uriLines = 0;
  var variantTags = 0;
  var renditionTags = 0;
  while (start <= data.length) {
    var end = data.indexOf(0x0A, start);
    final next = end < 0 ? data.length + 1 : end + 1;
    if (end < 0) end = data.length;
    if (end > start && data[end - 1] == 0x0D) end--;
    if (end - start > hlsMaxLineBytes) {
      throw const HlsRefusal(HlsRefusalKind.tooLarge);
    }
    final String text;
    try {
      text = utf8.decode(Uint8List.sublistView(data, start, end)).trim();
    } on FormatException {
      throw const HlsRefusal(HlsRefusalKind.invalid);
    }
    start = next;
    if (first) {
      if (text != '#EXTM3U') throw const HlsRefusal(HlsRefusalKind.invalid);
      first = false;
      continue;
    }
    if (text.isEmpty) continue;
    if (!text.startsWith('#')) {
      if (++uriLines > hlsMaxSegments) _tooLarge();
      lines.add(HlsUriLine(text));
    } else if (text.startsWith('#EXT')) {
      final colon = text.indexOf(':');
      final tag = colon < 0
          ? HlsTag(text.substring(1), null)
          : HlsTag(text.substring(1, colon), text.substring(colon + 1));
      if (tag.name == 'EXT-X-STREAM-INF' && ++variantTags > hlsMaxVariants) {
        _tooLarge();
      }
      if (tag.name == 'EXT-X-MEDIA' && ++renditionTags > hlsMaxRenditions) {
        _tooLarge();
      }
      lines.add(tag);
    }
  }
  if (first) throw const HlsRefusal(HlsRefusalKind.invalid);
  return lines;
}

Never _tooLarge() => throw const HlsRefusal(HlsRefusalKind.tooLarge);

bool _hasBom(Uint8List data) =>
    data.length >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF;
