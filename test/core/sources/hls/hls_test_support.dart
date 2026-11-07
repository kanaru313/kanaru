import 'dart:convert';

import 'package:kanaru/core/sources/hls/hls_playlist_parser.dart';

final testBase = Uri.parse('https://cdn.example.com/audio/index.m3u8');

/// Parses [text] as a playlist fetched from [base].
HlsPlaylist parseText(String text, {Uri? base}) =>
    parseHlsPlaylist(utf8.encode(text), base ?? testBase);

HlsMediaPlaylist parseMedia(String text, {Uri? base}) =>
    parseText(text, base: base) as HlsMediaPlaylist;

HlsMasterPlaylist parseMaster(String text, {Uri? base}) =>
    parseText(text, base: base) as HlsMasterPlaylist;

/// A media playlist body: [lines] between the header and `#EXT-X-ENDLIST`.
String media(List<String> lines, {bool end = true}) => [
  '#EXTM3U',
  '#EXT-X-TARGETDURATION:10',
  ...lines,
  if (end) '#EXT-X-ENDLIST',
].join('\n');

String master(List<String> lines) => ['#EXTM3U', ...lines].join('\n');

/// Expects [body] to throw an [HlsRefusal] of [kind].
void expectRefused(void Function() body, HlsRefusalKind kind) {
  try {
    body();
  } on HlsRefusal catch (refusal) {
    if (refusal.kind != kind) {
      throw StateError(
        'refused with ${refusal.kind.name}, wanted ${kind.name}',
      );
    }
    return;
  }
  throw StateError('not refused, wanted ${kind.name}');
}
