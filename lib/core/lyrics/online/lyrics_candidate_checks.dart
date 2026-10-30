import 'dart:convert';

import '../lrc_parser.dart';
import '../lyrics.dart';
import 'lrclib_record.dart' show sanitizeLyricsText;
import 'lyrics_fetch_exception.dart';
import 'lyrics_provider.dart';

/// Most results one provider answer may carry; the rest is dropped.
const maxProviderResults = 20;

/// Longest `remoteId`, in characters.
const maxRemoteIdLength = 256;

/// Longest title, artist or album, in characters (code points).
const maxLabelLength = 512;

/// Largest lyrics text, in UTF-8 bytes. A larger text is dropped.
const maxLyricsTextBytes = 1024 * 1024;

/// Longest duration believed; a candidate with a duration of this much or
/// more has no duration.
const maxCandidateDuration = Duration(hours: 24);

final _anyControl = RegExp(r'[\u0000-\u001F\u007F]');
final _spaces = RegExp(r'\s+');

/// What the host does with the answer of any provider before it ranks or
/// stores it. A provider is trusted to find lyrics, never to hand over
/// well-formed data.
extension LyricsCandidateBody on LyricsCandidate {
  /// Has something to use: words or the instrumental flag. A `null` body, or
  /// one with neither, does not.
  bool get hasBody {
    final b = body;
    return b != null && (b.hasLyrics || b.instrumental);
  }

  /// This record with [body] in place of its own.
  LyricsCandidate withBody(LyricsBody? body) => LyricsCandidate(
    providerId: providerId,
    remoteId: remoteId,
    title: title,
    artist: artist,
    album: album,
    duration: duration,
    body: body,
  );
}

/// [candidate] as the host keeps it, or `null` when it is not valid: an
/// empty, over-long or control-character `remoteId`, or a `title` or
/// `artist` that is empty after trimming or over [maxLabelLength]. Labels
/// lose control characters and extra spaces; an over-long `album` and a
/// `duration` outside 0..24 h (exclusive) are dropped, not the candidate;
/// the body goes through [checkBody]. The `providerId` is always
/// [providerId], the one the provider registered with.
LyricsCandidate? checkCandidate(
  LyricsCandidate candidate, {
  required String providerId,
}) {
  final id = candidate.remoteId;
  if (id.trim().isEmpty ||
      id.runes.length > maxRemoteIdLength ||
      _anyControl.hasMatch(id)) {
    return null;
  }
  final title = _label(candidate.title);
  final artist = _label(candidate.artist);
  if (title.isEmpty || artist.isEmpty) return null;
  if (_tooLong(title) || _tooLong(artist)) return null;
  final rawAlbum = candidate.album;
  final album = rawAlbum == null ? '' : _label(rawAlbum);
  final duration = candidate.duration;
  final durationOk =
      duration != null &&
      duration > Duration.zero &&
      duration < maxCandidateDuration;
  return LyricsCandidate(
    providerId: providerId,
    remoteId: id,
    title: title,
    artist: artist,
    album: album.isEmpty || _tooLong(album) ? null : album,
    duration: durationOk ? duration : null,
    body: checkBody(candidate.body),
  );
}

/// [found] as the host keeps it: invalid candidates and repeats of a
/// `remoteId` (the first wins) are dropped, and at most [maxProviderResults]
/// are kept. A non-empty list without a single valid candidate is a broken
/// provider, so it throws `LyricsFetchException(invalidResponse)` instead of
/// being taken for "no lyrics".
List<LyricsCandidate> checkCandidates(
  Iterable<LyricsCandidate> found, {
  required String providerId,
}) {
  final seen = <String>{};
  final kept = <LyricsCandidate>[];
  var any = false;
  for (final raw in found) {
    any = true;
    if (kept.length >= maxProviderResults) break;
    final checked = checkCandidate(raw, providerId: providerId);
    if (checked != null && seen.add(checked.remoteId)) kept.add(checked);
  }
  if (any && kept.isEmpty) {
    throw const LyricsFetchException(LyricsFetchKind.invalidResponse);
  }
  return kept;
}

/// The answer of a provider's `lookup`: `null` stays `null`; a record that
/// is not valid throws `LyricsFetchException(invalidResponse)`.
LyricsCandidate? checkLookupCandidate(
  LyricsCandidate? candidate, {
  required String providerId,
}) => candidate == null
    ? null
    : checkCandidates([candidate], providerId: providerId).single;

/// [body] with its texts cleaned: control characters other than `\n` and
/// `\t` removed, `\r\n` turned into `\n`, a blank text or one over
/// [maxLyricsTextBytes] dropped. Synced text that does not read as timed
/// lyrics moves to `plain` (or is dropped when `plain` is already there or
/// nothing is left to show).
LyricsBody? checkBody(LyricsBody? body) {
  if (body == null) return null;
  var synced = _text(body.syncedLrc);
  var plain = _text(body.plain);
  if (synced != null) {
    final parsed = parseLyricsText(synced, LyricsSource.sidecar);
    if (parsed == null || !parsed.synced) {
      if (parsed != null) plain ??= synced;
      synced = null;
    }
  }
  return LyricsBody(
    syncedLrc: synced,
    plain: plain,
    instrumental: body.instrumental,
  );
}

/// The answer of a provider's `fetch`: [checkBody], or `null` when nothing
/// usable is left (no words and not instrumental).
LyricsBody? checkFetchedBody(LyricsBody? body) {
  final checked = checkBody(body);
  if (checked == null || !(checked.hasLyrics || checked.instrumental)) {
    return null;
  }
  return checked;
}

String _label(String text) =>
    sanitizeLyricsText(text).replaceAll(_spaces, ' ').trim();

bool _tooLong(String label) => label.runes.length > maxLabelLength;

String? _text(String? raw) {
  if (raw == null) return null;
  final text = sanitizeLyricsText(raw.replaceAll('\r\n', '\n'));
  if (text.trim().isEmpty) return null;
  return utf8.encode(text).length > maxLyricsTextBytes ? null : text;
}
