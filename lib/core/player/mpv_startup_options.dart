import 'package:logging/logging.dart';

final _log = Logger('player');

/// mpv options set once, before the first track opens: `(name, value)`.
const mpvStartupOptions = <(String, String)>[
  // mpv's default today, set so gapless does not depend on it. `weak` joins
  // tracks only when their audio format matches; `yes` would resample a
  // track to the format of the one before it.
  ('gapless-audio', 'weak'),
  // media_kit turns on mpv's disk cache, but libmpv runs with config=no and
  // has no cache directory, so every opened file logged "Failed to create
  // file cache". Audio fits the RAM cache; remote streams will be cached by
  // the local proxy, not by mpv.
  ('cache-on-disk', 'no'),
  // A local file named `.mp3` that holds an M3U or HLS playlist makes mpv's
  // own playlist demuxer fetch the URLs in it (measured: one request per
  // file to a local server). Forcing libavformat for every played file skips
  // that demuxer; libavformat refuses such a file, and its nested opens
  // (HLS, concat) may only use local files. `access-references=no` would
  // also stop it, but media_kit's `open` loads the track through `loadlist`
  // of a temporary playlist file, which that option refuses, so nothing
  // would play. The playlist given to `loadlist` is still read: it forces
  // the playlist format and does not use `demuxer`. Remote sources will
  // need the whitelist widened for the local HTTP proxy.
  // Setting `demuxer-lavf-o` replaces media_kit's whole value
  // (`seg_max_retry=5,strict=experimental,allowed_extensions=ALL,
  // protocol_whitelist=...`, media_kit `real.dart`). That is fine for local
  // files; remote sources may need the `-append` form to keep those keys.
  ('demuxer', 'lavf'),
  ('demuxer-lavf-o', 'protocol_whitelist=file'),
];

/// Options whose value is read back after they are set: mpv ignores a failed
/// `set_property` on them silently, and they are what keeps a file from
/// making mpv fetch URLs.
const _verifiedOptions = {'demuxer', 'demuxer-lavf-o'};

/// Sets [mpvStartupOptions] with [setProperty], then reads the verified ones
/// back with [getProperty] and logs a warning for each that did not take. A
/// failing call is logged and does not stop the rest.
Future<void> applyMpvStartupOptions({
  required Future<void> Function(String name, String value) setProperty,
  required Future<String> Function(String name) getProperty,
}) async {
  for (final (name, value) in mpvStartupOptions) {
    try {
      await setProperty(name, value);
    } on Object catch (error) {
      _log.warning('Could not set the mpv option $name', error);
    }
  }
  for (final (name, value) in mpvStartupOptions) {
    if (!_verifiedOptions.contains(name)) continue;
    try {
      final actual = await getProperty(name);
      if (actual != value) {
        _log.warning('The mpv option $name did not take: expected "$value"');
      }
    } on Object catch (error) {
      _log.warning('Could not read back the mpv option $name', error);
    }
  }
}
