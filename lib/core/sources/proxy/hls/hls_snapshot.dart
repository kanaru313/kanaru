import '../../hls/hls_models.dart';
import 'hls_layout.dart';

export 'hls_layout.dart';

/// The checked media playlist the proxy loaded for one resolve, with its
/// [rev] and [layout]. Every request of a playthrough that shares the
/// resolve shares the snapshot.
class HlsSnapshot {
  HlsSnapshot._(this.playlist, this.rev, this.keys, this.inits, this.layout);

  /// A snapshot of [playlist] with a known [rev].
  factory HlsSnapshot(HlsMediaPlaylist playlist, int rev) =>
      HlsSnapshot.build(playlist, (_) => rev);

  /// Numbers the key files of [playlist] by URI and its init sections (an
  /// init section read under another key is another one) by first
  /// appearance (the j of `k<j>.key` and `i<j>.mp4`), builds the layout, and
  /// takes the rev [assignRev] gives for that layout.
  factory HlsSnapshot.build(
    HlsMediaPlaylist playlist,
    int Function(HlsLayout layout) assignRev,
  ) {
    final keyIndexes = <Uri, int>{};
    final initIndexes = <HlsInitSection, int>{};
    final initStates = <HlsKeyState>[];
    HlsKeyState stateOf(HlsKey? key) => key == null
        ? HlsKeyState.none
        : HlsKeyState(
            keyIndexes.putIfAbsent(key.uri, () => keyIndexes.length),
            key.iv,
          );
    final layoutSegments = <HlsLayoutSegment>[];
    for (final segment in playlist.segments) {
      final init = segment.init;
      int? initIndex;
      if (init != null) {
        // Before the segment's own key: the init section's `EXT-X-MAP` line
        // comes first in the playlist.
        initIndex = initIndexes.putIfAbsent(init, () {
          initStates.add(stateOf(init.key));
          return initIndexes.length;
        });
      }
      layoutSegments.add(
        HlsLayoutSegment(
          durationMs: (segment.duration.inMicroseconds / 1000).round(),
          discontinuity: segment.discontinuity,
          keyState: stateOf(segment.key),
          initIndex: initIndex,
        ),
      );
    }
    final keys = keyIndexes.keys.toList(growable: false);
    final inits = initIndexes.keys.toList(growable: false);
    final layout = HlsLayout(
      mediaSequence: playlist.mediaSequence,
      segments: layoutSegments,
      keyCount: keys.length,
      inits: initStates,
    );
    return HlsSnapshot._(playlist, assignRev(layout), keys, inits, layout);
  }

  final HlsMediaPlaylist playlist;

  /// Positive; new for every snapshot of a proxy session.
  final int rev;

  /// The distinct key file URLs, indexed by the j of `k<j>.key`.
  final List<Uri> keys;

  /// The distinct init sections, indexed by the j of `i<j>.mp4`.
  final List<HlsInitSection> inits;

  final HlsLayout layout;
}
