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
  // A local file named `.mp3` that holds an M3U or HLS playlist makes mpv
  // fetch the URLs in it (measured: one request per file to a local server).
  // Without references mpv plays the file itself and follows nothing. It
  // also turns off CUE, EDL and ordered chapters that point at other files;
  // the app plays none of those.
  ('access-references', 'no'),
];
