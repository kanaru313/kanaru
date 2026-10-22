import 'playback_prefs.dart';
import 'settings_codec_values.dart';

const _preferEmbeddedLyricsKey = 'preferEmbeddedLyrics';
const _gaplessKey = 'gapless';
const _infiniteQueueKey = 'infiniteQueue';
const _crossfadeSecondsKey = 'crossfadeSeconds';
const _fadeOnPlayMsKey = 'fadeOnPlayMs';
const _fadeOnPauseMsKey = 'fadeOnPauseMs';
const _listenThresholdMinutesKey = 'listenThresholdMinutes';
const _listenThresholdPercentKey = 'listenThresholdPercent';
const _knownKeys = {
  _preferEmbeddedLyricsKey,
  _gaplessKey,
  _infiniteQueueKey,
  _crossfadeSecondsKey,
  _fadeOnPlayMsKey,
  _fadeOnPauseMsKey,
  _listenThresholdMinutesKey,
  _listenThresholdPercentKey,
};

/// Reads the `playback` object; each key falls back on its own. The second
/// value holds the keys this version does not know.
(PlaybackPrefs, Map<String, Object?>) decodePlaybackPrefs(Object? json) {
  final map = objectOrEmpty(json);
  const d = PlaybackPrefs();
  return (
    PlaybackPrefs(
      preferEmbeddedLyrics: boolOr(
        map[_preferEmbeddedLyricsKey],
        d.preferEmbeddedLyrics,
      ),
      gapless: boolOr(map[_gaplessKey], d.gapless),
      infiniteQueue: boolOr(map[_infiniteQueueKey], d.infiniteQueue),
      crossfadeSeconds: intInRange(
        map[_crossfadeSecondsKey],
        0,
        PlaybackPrefs.maxCrossfadeSeconds,
        d.crossfadeSeconds,
      ),
      fadeOnPlayMs: intInRange(
        map[_fadeOnPlayMsKey],
        0,
        PlaybackPrefs.maxFadeMs,
        d.fadeOnPlayMs,
      ),
      fadeOnPauseMs: intInRange(
        map[_fadeOnPauseMsKey],
        0,
        PlaybackPrefs.maxFadeMs,
        d.fadeOnPauseMs,
      ),
      listenThresholdMinutes: intInRange(
        map[_listenThresholdMinutesKey],
        PlaybackPrefs.minListenThresholdMinutes,
        PlaybackPrefs.maxListenThresholdMinutes,
        d.listenThresholdMinutes,
      ),
      listenThresholdPercent: intInRange(
        map[_listenThresholdPercentKey],
        PlaybackPrefs.minListenThresholdPercent,
        PlaybackPrefs.maxListenThresholdPercent,
        d.listenThresholdPercent,
      ),
    ),
    unknownEntries(map, _knownKeys),
  );
}

/// The `playback` object, with [extra] (unknown keys) carried over.
Map<String, Object?> encodePlaybackPrefs(
  PlaybackPrefs prefs, {
  Map<String, Object?> extra = const {},
}) => {
  ...extra,
  _preferEmbeddedLyricsKey: prefs.preferEmbeddedLyrics,
  _gaplessKey: prefs.gapless,
  _infiniteQueueKey: prefs.infiniteQueue,
  _crossfadeSecondsKey: prefs.crossfadeSeconds,
  _fadeOnPlayMsKey: prefs.fadeOnPlayMs,
  _fadeOnPauseMsKey: prefs.fadeOnPauseMs,
  _listenThresholdMinutesKey: prefs.listenThresholdMinutes,
  _listenThresholdPercentKey: prefs.listenThresholdPercent,
};
