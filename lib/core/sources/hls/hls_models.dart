import 'dart:typed_data';

/// A parsed playlist: media (segments) or master (variants).
sealed class HlsPlaylist {
  const HlsPlaylist();
}

/// A VOD media playlist (it ended in `EXT-X-ENDLIST`).
final class HlsMediaPlaylist extends HlsPlaylist {
  HlsMediaPlaylist({
    required List<HlsSegment> segments,
    required this.mediaSequence,
    required this.targetDuration,
  }) : segments = List.unmodifiable(segments);

  final List<HlsSegment> segments;

  /// Sequence number of the first segment (`EXT-X-MEDIA-SEQUENCE`, else 0).
  final int mediaSequence;

  /// `EXT-X-TARGETDURATION`, else the longest duration rounded up.
  final Duration targetDuration;

  Duration get totalDuration =>
      segments.fold(Duration.zero, (sum, s) => sum + s.duration);
}

/// One media segment, with everything that applies to it already resolved.
final class HlsSegment {
  const HlsSegment({
    required this.uri,
    required this.duration,
    this.byteRange,
    this.discontinuity = false,
    this.key,
    this.init,
  });

  /// Absolute, resolved against the playlist URL. The host is not checked.
  final Uri uri;
  final Duration duration;

  /// The bytes of [uri] that make up the segment; null: the whole resource.
  final HlsByteRange? byteRange;

  /// `EXT-X-DISCONTINUITY` precedes this segment.
  final bool discontinuity;

  /// The `AES-128` key in force; null: not encrypted.
  final HlsKey? key;

  /// The `EXT-X-MAP` initialization section in force, if any.
  final HlsInitSection? init;
}

/// `length` bytes starting at `offset` (an implicit offset is already
/// computed).
final class HlsByteRange {
  const HlsByteRange({required this.offset, required this.length});

  final int offset;
  final int length;

  /// First byte after the range.
  int get end => offset + length;

  @override
  bool operator ==(Object other) =>
      other is HlsByteRange && other.offset == offset && other.length == length;

  @override
  int get hashCode => Object.hash(offset, length);
}

/// An `AES-128` key: the key URI and the IV in force with it. Equal keys
/// (same URI and IV) compare equal; a consumer that numbers the key files of
/// a playlist numbers them by [uri] alone.
final class HlsKey {
  const HlsKey({required this.uri, this.iv});

  final Uri uri;

  /// The 16-byte IV the playlist gave; null: derived from the segment's media
  /// sequence number by the decrypting side.
  final Uint8List? iv;

  @override
  bool operator ==(Object other) =>
      other is HlsKey && other.uri == uri && sameIv(other.iv, iv);

  @override
  int get hashCode => Object.hash(uri, iv == null ? null : Object.hashAll(iv!));

  /// Two IVs are the same when both are derived (null) or hold the same
  /// bytes.
  static bool sameIv(Uint8List? a, Uint8List? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// An `EXT-X-MAP` initialization section (fMP4).
final class HlsInitSection {
  const HlsInitSection({required this.uri, this.byteRange, this.key});

  final Uri uri;
  final HlsByteRange? byteRange;

  /// The `AES-128` key in force at the `EXT-X-MAP` line; null: none. A
  /// decrypting player reads the init section under this key, whatever key
  /// the segments after it use, so the same init section under another key is
  /// another init section.
  final HlsKey? key;

  @override
  bool operator ==(Object other) =>
      other is HlsInitSection &&
      other.uri == uri &&
      other.byteRange == byteRange &&
      other.key == key;

  @override
  int get hashCode => Object.hash(uri, byteRange, key);
}

/// A master playlist: the variants and renditions to choose from.
final class HlsMasterPlaylist extends HlsPlaylist {
  HlsMasterPlaylist({
    required List<HlsVariant> variants,
    required List<HlsRendition> renditions,
  }) : variants = List.unmodifiable(variants),
       renditions = List.unmodifiable(renditions);

  final List<HlsVariant> variants;
  final List<HlsRendition> renditions;
}

/// An `EXT-X-STREAM-INF` variant.
final class HlsVariant {
  const HlsVariant({
    required this.uri,
    required this.bandwidth,
    this.codecs,
    this.audioGroup,
  });

  final Uri uri;

  /// `BANDWIDTH`; 0 when missing or not a number.
  final int bandwidth;

  /// The `CODECS` entries; null when the attribute is absent or empty.
  final List<String>? codecs;

  /// The `AUDIO` group id naming `EXT-X-MEDIA` renditions.
  final String? audioGroup;
}

/// An `EXT-X-MEDIA` rendition.
final class HlsRendition {
  const HlsRendition({
    required this.type,
    required this.groupId,
    this.uri,
    this.isDefault = false,
    this.isAutoselect = false,
  });

  /// `AUDIO`, `VIDEO`, `SUBTITLES`, `CLOSED-CAPTIONS`.
  final String type;
  final String groupId;

  /// Null: the rendition's media is muxed into the variants.
  final Uri? uri;
  final bool isDefault;
  final bool isAutoselect;
}
