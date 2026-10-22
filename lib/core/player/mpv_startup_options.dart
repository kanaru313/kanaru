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
  ('demuxer', 'lavf'),
  ('demuxer-lavf-o', 'protocol_whitelist=file'),
];
