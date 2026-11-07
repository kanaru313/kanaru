import 'dart:typed_data';

import '../../hls/hls_models.dart';

/// What the playlist of one snapshot says about segment boundaries, in the
/// terms a later snapshot of the same item is compared by. Two equal layouts
/// map segment i to segment i, key j to key j and init section j to init
/// section j, so a request made for the first can be served from the second.
///
/// Compared: the media sequence, the segment count and per segment its
/// duration in whole milliseconds, its discontinuity flag, its key state (the
/// key index and the IV, explicit or derived) and its init index; per init
/// section the key state in force at its `EXT-X-MAP` line; plus the key count.
/// Segment URLs, byte ranges and key bytes are not part of it: they change
/// with every signed URL.
class HlsLayout {
  HlsLayout({
    required this.mediaSequence,
    required List<HlsLayoutSegment> segments,
    required this.keyCount,
    required List<HlsKeyState> inits,
  }) : segments = List.unmodifiable(segments),
       inits = List.unmodifiable(inits);

  final int mediaSequence;
  final List<HlsLayoutSegment> segments;
  final int keyCount;

  /// Per init section j, the key state in force at its `EXT-X-MAP` line.
  final List<HlsKeyState> inits;

  int get initCount => inits.length;

  @override
  bool operator ==(Object other) {
    if (other is! HlsLayout ||
        other.mediaSequence != mediaSequence ||
        other.keyCount != keyCount ||
        other.inits.length != inits.length ||
        other.segments.length != segments.length) {
      return false;
    }
    for (var i = 0; i < inits.length; i++) {
      if (other.inits[i] != inits[i]) return false;
    }
    for (var i = 0; i < segments.length; i++) {
      if (other.segments[i] != segments[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    mediaSequence,
    keyCount,
    Object.hashAll(inits),
    Object.hashAll(segments),
  );
}

/// The key in force at a point of the playlist: which key file (the j of
/// `k<j>.key`, numbered by URI) and which IV. Not encrypted: [none].
///
/// [iv] is the explicit 16 bytes, or null when the decrypting side derives it
/// from the media sequence number; two derived IVs are the same state.
class HlsKeyState {
  const HlsKeyState(this.keyIndex, this.iv);

  static const none = HlsKeyState(null, null);

  final int? keyIndex;
  final Uint8List? iv;

  @override
  bool operator ==(Object other) =>
      other is HlsKeyState &&
      other.keyIndex == keyIndex &&
      HlsKey.sameIv(other.iv, iv);

  @override
  int get hashCode =>
      Object.hash(keyIndex, iv == null ? null : Object.hashAll(iv!));
}

/// One segment as [HlsLayout] compares it.
class HlsLayoutSegment {
  const HlsLayoutSegment({
    required this.durationMs,
    required this.discontinuity,
    this.keyState = HlsKeyState.none,
    this.initIndex,
  });

  /// The duration rounded to whole milliseconds.
  final int durationMs;
  final bool discontinuity;

  /// The key and IV the segment is decrypted with.
  final HlsKeyState keyState;

  /// The j of the segment's `i<j>.mp4`; null: no init section.
  final int? initIndex;

  /// The j of the segment's `k<j>.key`; null: not encrypted.
  int? get keyIndex => keyState.keyIndex;

  @override
  bool operator ==(Object other) =>
      other is HlsLayoutSegment &&
      other.durationMs == durationMs &&
      other.discontinuity == discontinuity &&
      other.keyState == keyState &&
      other.initIndex == initIndex;

  @override
  int get hashCode =>
      Object.hash(durationMs, discontinuity, keyState, initIndex);
}
