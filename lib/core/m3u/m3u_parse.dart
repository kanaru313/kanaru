import 'dart:convert';
import 'dart:typed_data';

/// Lines longer than this (in UTF-8 bytes) are never paths a player wrote;
/// they are reported as not found without touching the disk.
const m3uMaxLineBytes = 4096;

/// At most this many path lines are read from one file; the rest is dropped
/// and reported.
const m3uMaxPathLines = 50000;

/// One non-comment line of an M3U file. [line] counts from 1 in the file.
/// [tooLong] lines are reported as not found without being resolved.
typedef M3uLine = ({int line, String text, bool tooLong});

/// The path lines of an M3U file and whether [m3uMaxPathLines] cut it.
typedef M3uLines = ({List<M3uLine> lines, bool truncated});

/// [bytes] as text: UTF-8 without its byte order mark, or Latin-1 when the
/// bytes are not valid UTF-8 (old Windows players wrote the system code
/// page, most often CP1252, which Latin-1 reads right for letters).
String decodeM3uBytes(Uint8List bytes) {
  var start = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    start = 3;
  }
  final body = Uint8List.sublistView(bytes, start);
  try {
    return utf8.decode(body);
  } on FormatException {
    return latin1.decode(body);
  }
}

/// The path lines of [text] in order: blank lines and `#` lines (`#EXTM3U`,
/// `#EXTINF`, comments) are skipped, a trailing CR is dropped. Stops after
/// [m3uMaxPathLines] path lines.
M3uLines m3uPathLines(String text) {
  final lines = <M3uLine>[];
  var number = 0;
  var truncated = false;
  for (var raw in const LineSplitter().convert(text)) {
    number++;
    if (raw.endsWith('\r')) raw = raw.substring(0, raw.length - 1);
    if (raw.trim().isEmpty || raw.startsWith('#')) continue;
    if (lines.length == m3uMaxPathLines) {
      truncated = true;
      break;
    }
    lines.add((
      line: number,
      text: raw,
      tooLong:
          raw.length > m3uMaxLineBytes ||
          utf8.encode(raw).length > m3uMaxLineBytes,
    ));
  }
  return (lines: lines, truncated: truncated);
}

/// [decodeM3uBytes] then [m3uPathLines]; a top-level function so it can run
/// in `Isolate.run`.
M3uLines parseM3uBytes(Uint8List bytes) => m3uPathLines(decodeM3uBytes(bytes));
