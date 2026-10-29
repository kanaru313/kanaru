import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../lyrics/lyrics.dart';

/// Identifies the text of [lyrics] for the translation cache: lowercase hex
/// sha256 of the non-blank line texts joined with `\n`. Timestamps and blank
/// (instrumental) lines are ignored, so re-synced or re-timed lyrics of the
/// same words keep their saved translation.
///
/// This definition is a storage contract: changing it orphans every cached
/// row. Orphans are harmless and are removed by "Clear saved translations".
///
/// Rejected online lyrics are remembered by this same hash (see
/// `candidateContentHash`), so a duplicate of a rejected text is recognised.
String lyricsContentHash(Lyrics lyrics) {
  final texts = lyrics.lines
      .map((line) => line.text)
      .where((text) => text.trim().isNotEmpty);
  return sha256.convert(utf8.encode(texts.join('\n'))).toString();
}

final _hashes = Expando<String>('lyricsContentHash');

/// [lyricsContentHash] computed once per [Lyrics] instance.
String lyricsContentHashOf(Lyrics lyrics) =>
    _hashes[lyrics] ??= lyricsContentHash(lyrics);
