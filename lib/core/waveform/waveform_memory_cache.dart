import 'waveform.dart';

/// The last few waveform answers by file path, least recently used out first.
/// A `null` value is a remembered "this file has no waveform", so such a file
/// is not read again until its entry is evicted. Disk stays the source of
/// truth; this makes track changes synchronous and stops repeat reads of
/// files without a waveform. A file rewritten during the session is seen
/// again only after its entry is evicted or the app restarts.
class WaveformMemoryCache {
  WaveformMemoryCache({this.capacity = 8});

  final int capacity;
  final _entries = <String, Waveform?>{};

  /// Whether [path] has an answer, waveform or "none".
  bool contains(String path) => _entries.containsKey(path);

  /// The waveform for [path], or `null` for "none" and for unknown paths.
  /// Marks the entry as recently used.
  Waveform? lookup(String path) {
    if (!_entries.containsKey(path)) return null;
    final value = _entries.remove(path);
    _entries[path] = value;
    return value;
  }

  /// Stores the answer for [path]; `null` means "no waveform".
  void put(String path, Waveform? waveform) {
    _entries.remove(path);
    _entries[path] = waveform;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }
}
