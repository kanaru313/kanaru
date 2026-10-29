import 'dart:convert';

import '../lrc_sidecar_reader.dart';
import 'lyrics_provider.dart';

/// Longest duration believed, in seconds (a day).
const _maxDurationSeconds = 86400;

/// Longest title, artist or album kept, in characters.
const lrclibDisplayFieldMax = 512;

// C0 controls except \n and \t, DEL, and the bidirectional overrides and
// isolates (U+202A-202E, U+2066-2069) that can reorder text on screen.
final _unsafe = RegExp(
  r'[\u0000-\u0008\u000B-\u001F\u007F\u202A-\u202E\u2066-\u2069]',
);
final _spaces = RegExp(r'\s+');

/// [text] without control and bidirectional override characters.
String sanitizeLyricsText(String text) => text.replaceAll(_unsafe, '');

/// A one-line label: sanitized, whitespace collapsed, at most
/// [lrclibDisplayFieldMax] characters (code points, never half a pair).
String sanitizeDisplayText(String text) {
  final line = sanitizeLyricsText(text).replaceAll(_spaces, ' ').trim();
  final runes = line.runes;
  if (runes.length <= lrclibDisplayFieldMax) return line;
  return String.fromCharCodes(runes.take(lrclibDisplayFieldMax)).trim();
}

/// A lyrics text, or `null` when blank or over [lrcMaxBytes] in UTF-8.
String? _lyricsBody(Object? value) {
  if (value is! String) return null;
  final text = sanitizeLyricsText(value);
  if (text.trim().isEmpty) return null;
  return utf8.encode(text).length > lrcMaxBytes ? null : text;
}

/// Maps one LRCLIB JSON record to a candidate, or `null` when the record has
/// the wrong shape: not an object, no integer `id`, no `trackName` or
/// `artistName` text, or a field of the wrong type. Text is sanitized, labels
/// capped, oversized or blank lyrics dropped.
LyricsCandidate? parseLrclibRecord(Object? json, {required String providerId}) {
  if (json is! Map) return null;
  final id = json['id'];
  final track = json['trackName'];
  final artist = json['artistName'];
  if (id is! int || track is! String || artist is! String) return null;
  final album = json['albumName'];
  final seconds = json['duration'];
  final instrumental = json['instrumental'];
  final synced = json['syncedLyrics'];
  final plain = json['plainLyrics'];
  final optionalOk =
      (album == null || album is String) &&
      (instrumental == null || instrumental is bool) &&
      (synced == null || synced is String) &&
      (plain == null || plain is String) &&
      (seconds == null ||
          (seconds is num &&
              seconds.isFinite &&
              seconds >= 0 &&
              seconds <= _maxDurationSeconds));
  if (!optionalOk) return null;
  final title = sanitizeDisplayText(track);
  if (title.isEmpty) return null;
  final albumText = album is String ? sanitizeDisplayText(album) : '';
  return LyricsCandidate(
    providerId: providerId,
    remoteId: '$id',
    title: title,
    artist: sanitizeDisplayText(artist),
    album: albumText.isEmpty ? null : albumText,
    duration: seconds is num
        ? Duration(milliseconds: (seconds * 1000).round())
        : null,
    body: LyricsBody(
      syncedLrc: _lyricsBody(synced),
      plain: _lyricsBody(plain),
      instrumental: instrumental == true,
    ),
  );
}
