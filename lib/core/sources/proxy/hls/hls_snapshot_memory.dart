import 'hls_layout.dart';

/// How many snapshots a proxy session remembers.
const hlsRememberedSnapshots = 64;

/// Hands out revs and remembers `(rev → item key, layout)` for the last
/// [hlsRememberedSnapshots] snapshots, so a request that names an older rev
/// can be matched to the current snapshot of its item by layout.
class HlsSnapshotMemory {
  var _lastRev = 0;
  final _remembered = <int, ({String key, HlsLayout layout})>{};

  /// A new rev, remembered with [key] and [layout]; forgets the oldest one
  /// past the limit.
  int remember(String key, HlsLayout layout) {
    final rev = ++_lastRev;
    _remembered[rev] = (key: key, layout: layout);
    if (_remembered.length > hlsRememberedSnapshots) {
      _remembered.remove(_remembered.keys.first);
    }
    return rev;
  }

  /// The layout remembered for [rev] when it is a snapshot of [key], else
  /// null (never seen, forgotten, or another item's).
  HlsLayout? layoutOf(String key, int rev) {
    final found = _remembered[rev];
    return found != null && found.key == key ? found.layout : null;
  }
}
