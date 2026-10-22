/// How the player behaves. The defaults are what the player does today
/// (gapless on, a listen counts after min(4 minutes, 50 %), no fades); the
/// options are stored for the playback options that do not exist yet:
/// nothing reads them.
class PlaybackPrefs {
  const PlaybackPrefs({
    this.preferEmbeddedLyrics = true,
    this.gapless = true,
    this.infiniteQueue = false,
    this.crossfadeSeconds = 0,
    this.fadeOnPlayMs = 0,
    this.fadeOnPauseMs = 0,
    this.listenThresholdMinutes = 4,
    this.listenThresholdPercent = 50,
  });

  static const maxCrossfadeSeconds = 12;
  static const maxFadeMs = 5000;
  static const minListenThresholdMinutes = 1;
  static const maxListenThresholdMinutes = 10;
  static const minListenThresholdPercent = 10;
  static const maxListenThresholdPercent = 100;

  /// Lyrics inside the file win over lyric files next to it.
  final bool preferEmbeddedLyrics;

  /// No gap between tracks that follow each other.
  final bool gapless;

  /// When the queue ends, keep playing similar tracks.
  final bool infiniteQueue;

  /// Overlap of two tracks; 0 is off.
  final int crossfadeSeconds;

  /// Fade in on play and fade out on pause; 0 is off.
  final int fadeOnPlayMs;
  final int fadeOnPauseMs;

  /// A play counts as a listen after this many minutes or this share of the
  /// track, whichever comes first.
  final int listenThresholdMinutes;
  final int listenThresholdPercent;

  PlaybackPrefs copyWith({
    bool? preferEmbeddedLyrics,
    bool? gapless,
    bool? infiniteQueue,
    int? crossfadeSeconds,
    int? fadeOnPlayMs,
    int? fadeOnPauseMs,
    int? listenThresholdMinutes,
    int? listenThresholdPercent,
  }) => PlaybackPrefs(
    preferEmbeddedLyrics: preferEmbeddedLyrics ?? this.preferEmbeddedLyrics,
    gapless: gapless ?? this.gapless,
    infiniteQueue: infiniteQueue ?? this.infiniteQueue,
    crossfadeSeconds: crossfadeSeconds ?? this.crossfadeSeconds,
    fadeOnPlayMs: fadeOnPlayMs ?? this.fadeOnPlayMs,
    fadeOnPauseMs: fadeOnPauseMs ?? this.fadeOnPauseMs,
    listenThresholdMinutes:
        listenThresholdMinutes ?? this.listenThresholdMinutes,
    listenThresholdPercent:
        listenThresholdPercent ?? this.listenThresholdPercent,
  );

  @override
  bool operator ==(Object other) =>
      other is PlaybackPrefs &&
      other.preferEmbeddedLyrics == preferEmbeddedLyrics &&
      other.gapless == gapless &&
      other.infiniteQueue == infiniteQueue &&
      other.crossfadeSeconds == crossfadeSeconds &&
      other.fadeOnPlayMs == fadeOnPlayMs &&
      other.fadeOnPauseMs == fadeOnPauseMs &&
      other.listenThresholdMinutes == listenThresholdMinutes &&
      other.listenThresholdPercent == listenThresholdPercent;

  @override
  int get hashCode => Object.hash(
    preferEmbeddedLyrics,
    gapless,
    infiniteQueue,
    crossfadeSeconds,
    fadeOnPlayMs,
    fadeOnPauseMs,
    listenThresholdMinutes,
    listenThresholdPercent,
  );

  @override
  String toString() =>
      'PlaybackPrefs(preferEmbeddedLyrics: $preferEmbeddedLyrics, '
      'gapless: $gapless, infiniteQueue: $infiniteQueue, '
      'crossfadeSeconds: $crossfadeSeconds, fadeOnPlayMs: $fadeOnPlayMs, '
      'fadeOnPauseMs: $fadeOnPauseMs, '
      'listenThresholdMinutes: $listenThresholdMinutes, '
      'listenThresholdPercent: $listenThresholdPercent)';
}
