import 'dart:convert';

import '../online/lyrics_candidate_checks.dart'
    show maxCandidateDuration, maxLyricsTextBytes, maxRemoteIdLength;
import '../online/lyrics_provider.dart';

/// The data a plugin script returned does not have the documented shape.
/// [reason] is runtime-free text naming the field, never a script value, so
/// it is safe to log.
class PluginOutputException implements Exception {
  const PluginOutputException(this.reason);

  final String reason;

  @override
  String toString() => 'PluginOutputException($reason)';
}

/// What `search.js` returned: the usable [candidates] and one [dropped]
/// reason per item that was left out.
class PluginSearchOutput {
  const PluginSearchOutput(this.candidates, this.dropped);

  final List<LyricsCandidate> candidates;
  final List<String> dropped;
}

/// Reads the output JSON of `search.js`: an array of
/// `{id, title, artist, album?, durationMs?, lyrics?}`. An item that breaks
/// the shape is dropped with a reason like
/// `result #4: "artist" must be a non-empty string` (numbered from 1). A
/// `durationMs` of 24 h or more is ignored. A non-array throws
/// [PluginOutputException]. The host checks the survivors again (lengths,
/// control characters, duration range, match gate).
PluginSearchOutput readSearchOutput(String json, {required String providerId}) {
  final data = _decode(json);
  if (data is! List) {
    throw const PluginOutputException('search output must be an array');
  }
  final candidates = <LyricsCandidate>[];
  final dropped = <String>[];
  for (var i = 0; i < data.length; i++) {
    final label = 'result #${i + 1}';
    final problem = _readItem(data[i], providerId, candidates);
    if (problem != null) dropped.add('$label: $problem');
  }
  return PluginSearchOutput(candidates, dropped);
}

/// Reads the output JSON of `lyrics.js`: `null` (no lyrics), `{instrumental:
/// true}` or `{data, type?}`. `type` `lrc` is synced text, `txt` plain text;
/// anything else is synced when the text has a `[mm:ss.xx]` stamp and plain
/// otherwise. A blank `data` is no lyrics. Throws [PluginOutputException]
/// for any other shape or a `data` over 1 MiB.
LyricsBody? readLyricsOutput(String json) {
  final data = _decode(json);
  if (data == null) return null;
  if (data is! Map) {
    throw const PluginOutputException(
      'lyrics output must be an object or null',
    );
  }
  final instrumental = data['instrumental'];
  if (instrumental != null && instrumental is! bool) {
    throw const PluginOutputException('"instrumental" must be a boolean');
  }
  if (instrumental == true) return const LyricsBody(instrumental: true);
  final text = data['data'];
  if (text is! String) {
    throw const PluginOutputException('"data" must be a string');
  }
  final type = data['type'];
  if (type != null && type is! String) {
    throw const PluginOutputException('"type" must be a string');
  }
  if (_tooLarge(text)) {
    throw const PluginOutputException('"data" is larger than 1 MiB');
  }
  return _bodyOf(text, type as String?);
}

Object? _decode(String json) {
  try {
    return jsonDecode(json);
  } on FormatException {
    throw const PluginOutputException('the output is not valid JSON');
  }
}

/// Adds the candidate of [item] to [out]; the problem text when it is not
/// valid.
String? _readItem(Object? item, String providerId, List<LyricsCandidate> out) {
  if (item is! Map) return 'must be an object';
  final id = item['id'];
  if (id is! String || id.isEmpty || id.length > maxRemoteIdLength) {
    return '"id" must be a non-empty string of at most $maxRemoteIdLength '
        'characters';
  }
  final title = item['title'];
  if (title is! String || title.trim().isEmpty) {
    return '"title" must be a non-empty string';
  }
  final artist = item['artist'];
  if (artist is! String || artist.trim().isEmpty) {
    return '"artist" must be a non-empty string';
  }
  final album = item['album'];
  if (album != null && album is! String) return '"album" must be a string';
  final durationMs = item['durationMs'];
  Duration? duration;
  if (durationMs != null) {
    final ms = _positiveInt(durationMs);
    if (ms == null) return '"durationMs" must be an integer above 0';
    // A duration the host would not believe is dropped, not the item (and
    // is never turned into a Duration, which a huge number would overflow).
    if (ms < maxCandidateDuration.inMilliseconds) {
      duration = Duration(milliseconds: ms);
    }
  }
  final lyrics = item['lyrics'];
  if (lyrics != null && lyrics is! String) return '"lyrics" must be a string';
  if (lyrics is String && _tooLarge(lyrics)) {
    return '"lyrics" is larger than 1 MiB';
  }
  out.add(
    LyricsCandidate(
      providerId: providerId,
      remoteId: id,
      title: title,
      artist: artist,
      album: album is String && album.trim().isNotEmpty ? album : null,
      duration: duration,
      // Inline lyrics make the result complete: no second fetch.
      body: lyrics is String ? _bodyOf(lyrics, null) : null,
    ),
  );
  return null;
}

int? _positiveInt(Object value) {
  final int ms;
  if (value is int) {
    ms = value;
  } else if (value is double && value.isFinite && value == value.truncate()) {
    // JSON written by JavaScript may spell a whole number as 180000.0.
    ms = value.toInt();
  } else {
    return null;
  }
  return ms > 0 ? ms : null;
}

bool _tooLarge(String text) {
  // A UTF-16 unit is at least one byte, and at most three.
  if (text.length > maxLyricsTextBytes) return true;
  if (text.length * 3 <= maxLyricsTextBytes) return false;
  return utf8.encode(text).length > maxLyricsTextBytes;
}

final _timeStamp = RegExp(r'\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\]');

/// The body of [text]; `null` when it is blank. [type] picks synced or plain
/// text, else a time stamp does.
LyricsBody? _bodyOf(String text, String? type) {
  if (text.trim().isEmpty) return null;
  final synced = switch (type?.toLowerCase()) {
    'lrc' => true,
    'txt' => false,
    _ => _timeStamp.hasMatch(text),
  };
  return synced ? LyricsBody(syncedLrc: text) : LyricsBody(plain: text);
}
