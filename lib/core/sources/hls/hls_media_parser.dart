import 'hls_key_tags.dart';
import 'hls_limits.dart';
import 'hls_lines.dart';
import 'hls_models.dart';
import 'hls_refusal.dart';
import 'hls_values.dart';

/// Builds a VOD media playlist from [lines], resolving URIs against [base].
///
/// Tags that apply "from here on" (`EXT-X-KEY`, `EXT-X-MAP`) are carried into
/// each segment; `EXT-X-DISCONTINUITY` and `EXT-X-BYTERANGE` apply to the
/// next segment. A playlist with no segment is `invalid`, one without
/// `EXT-X-ENDLIST` is `live`, an I-frame-only one is `noAudio`.
HlsMediaPlaylist parseHlsMedia(List<HlsLine> lines, Uri base) {
  final segments = <HlsSegment>[];
  var mediaSequence = 0;
  Duration? targetDuration;
  var ended = false;
  var totalMicroseconds = 0;
  var longestMicroseconds = 0;

  Duration? pendingDuration;
  ({int length, int? offset})? pendingRange;
  var pendingDiscontinuity = false;
  HlsKey? key;
  HlsInitSection? init;

  for (final line in lines) {
    switch (line) {
      case HlsUriLine(:final text):
        final duration = pendingDuration;
        if (duration == null) throw const HlsRefusal(HlsRefusalKind.invalid);
        if (segments.length >= hlsMaxSegments) {
          throw const HlsRefusal(HlsRefusalKind.tooLarge);
        }
        final uri = resolveHlsUri(base, text);
        totalMicroseconds += duration.inMicroseconds;
        if (totalMicroseconds > hlsMaxTotalDuration.inMicroseconds) {
          throw const HlsRefusal(HlsRefusalKind.invalid);
        }
        if (duration.inMicroseconds > longestMicroseconds) {
          longestMicroseconds = duration.inMicroseconds;
        }
        segments.add(
          HlsSegment(
            uri: uri,
            duration: duration,
            byteRange: _segmentRange(pendingRange, segments, uri),
            discontinuity: pendingDiscontinuity,
            key: key,
            init: init,
          ),
        );
        pendingDuration = null;
        pendingRange = null;
        pendingDiscontinuity = false;
      case HlsTag(:final name, :final value):
        switch (name) {
          case 'EXT-X-VERSION':
            if (parseHlsUnsigned(value) == null) _invalid();
          case 'EXT-X-TARGETDURATION':
            final seconds = parseHlsUnsigned(value);
            if (seconds == null ||
                seconds < 1 ||
                seconds > hlsMaxSegmentDuration.inSeconds) {
              _invalid();
            }
            targetDuration = Duration(seconds: seconds);
          case 'EXT-X-MEDIA-SEQUENCE':
            mediaSequence = parseHlsUnsigned(value) ?? _invalid();
          case 'EXT-X-DISCONTINUITY-SEQUENCE':
            if (parseHlsUnsigned(value) == null) _invalid();
          case 'EXT-X-PLAYLIST-TYPE':
            if (value != 'VOD' && value != 'EVENT') _invalid();
          case 'EXTINF':
            if (pendingDuration != null || value == null) _invalid();
            final comma = value.indexOf(',');
            final text = comma < 0 ? value : value.substring(0, comma);
            pendingDuration = parseHlsDuration(text.trim()) ?? _invalid();
          case 'EXT-X-BYTERANGE':
            pendingRange = parseHlsByteRangeText(value) ?? _invalid();
          case 'EXT-X-DISCONTINUITY':
            pendingDiscontinuity = true;
          case 'EXT-X-KEY':
            key = parseHlsKey(value, base);
          case 'EXT-X-MAP':
            init = parseHlsMap(value, base, key);
          case 'EXT-X-ENDLIST':
            ended = true;
          case 'EXT-X-I-FRAMES-ONLY':
            throw const HlsRefusal(HlsRefusalKind.noAudio);
        }
    }
  }
  // An EXTINF with no URI line after it.
  if (pendingDuration != null || segments.isEmpty) _invalid();
  if (!ended) throw const HlsRefusal(HlsRefusalKind.live);
  return HlsMediaPlaylist(
    segments: segments,
    mediaSequence: mediaSequence,
    // Round up to whole seconds, as the tag's own value is an integer.
    targetDuration:
        targetDuration ??
        Duration(
          seconds:
              (longestMicroseconds + Duration.microsecondsPerSecond - 1) ~/
              Duration.microsecondsPerSecond,
        ),
  );
}

/// The byte range of the segment at [uri]. Without an offset it continues
/// the previous segment's range, which must be of the same resource.
HlsByteRange? _segmentRange(
  ({int length, int? offset})? pending,
  List<HlsSegment> segments,
  Uri uri,
) {
  if (pending == null) return null;
  final previous = segments.isEmpty ? null : segments.last;
  final implicit = previous != null && previous.uri == uri
      ? previous.byteRange?.end
      : null;
  return completeHlsByteRange(pending, implicit);
}

Never _invalid() => throw const HlsRefusal(HlsRefusalKind.invalid);
