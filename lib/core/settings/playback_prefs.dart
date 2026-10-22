/// How ReplayGain tags change the volume. mpv reads the tags itself
/// (`replaygain`); [auto] is decided in Dart and sent as `album` or `track`.
enum ReplayGainMode {
  /// Tags are ignored (mpv `replaygain=no`).
  off,

  /// Track gain (mpv `replaygain=track`).
  track,

  /// Album gain (mpv `replaygain=album`).
  album,

  /// Album gain while a whole album plays in order, track gain otherwise.
  auto,
}

/// How the player behaves. The defaults are what the player does today
/// (gapless on, a listen counts after min(4 minutes, 50 %), no fades,
/// ReplayGain off, mpv's automatic output device). Each option is stored
/// here first and wired to the player later; a field's doc says when it is
/// read.
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
    this.replayGainMode = ReplayGainMode.off,
    this.replayGainPreampDb = 0,
    this.replayGainPreventClipping = true,
    this.audioDeviceName,
    this.audioDeviceDescription,
  });

  static const maxCrossfadeSeconds = 12;
  static const maxFadeMs = 5000;
  static const minListenThresholdMinutes = 1;
  static const maxListenThresholdMinutes = 10;
  static const minListenThresholdPercent = 10;
  static const maxListenThresholdPercent = 100;

  /// Bounds of [replayGainPreampDb]. mpv accepts -150..150; the app keeps
  /// to a useful range.
  static const minReplayGainPreampDb = -15.0;
  static const maxReplayGainPreampDb = 15.0;

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

  final ReplayGainMode replayGainMode;

  /// Gain added on top of the ReplayGain value, in dB (mpv
  /// `replaygain-preamp`), within [minReplayGainPreampDb] and
  /// [maxReplayGainPreampDb].
  final double replayGainPreampDb;

  /// Lower the gain so the peak does not clip. True is mpv
  /// `replaygain-clip=no`: in mpv `yes` *allows* clipping.
  final bool replayGainPreventClipping;

  /// The `name` of an entry of mpv's `audio-device-list` (for example
  /// `pipewire/alsa_output.usb-…`); null is mpv's `auto`. Only set it to a
  /// name taken from that list. Change it with [withAudioDevice].
  final String? audioDeviceName;

  /// The device's `description` when it was chosen, to name it while it is
  /// absent. Null with [audioDeviceName].
  final String? audioDeviceDescription;

  /// A copy with another output device; no arguments go back to `auto`
  /// (both fields null). Separate from [copyWith], where null means "keep".
  PlaybackPrefs withAudioDevice({String? name, String? description}) =>
      PlaybackPrefs(
        preferEmbeddedLyrics: preferEmbeddedLyrics,
        gapless: gapless,
        infiniteQueue: infiniteQueue,
        crossfadeSeconds: crossfadeSeconds,
        fadeOnPlayMs: fadeOnPlayMs,
        fadeOnPauseMs: fadeOnPauseMs,
        listenThresholdMinutes: listenThresholdMinutes,
        listenThresholdPercent: listenThresholdPercent,
        replayGainMode: replayGainMode,
        replayGainPreampDb: replayGainPreampDb,
        replayGainPreventClipping: replayGainPreventClipping,
        audioDeviceName: name,
        audioDeviceDescription: name == null ? null : description,
      );

  /// The device fields are kept; change them with [withAudioDevice].
  PlaybackPrefs copyWith({
    bool? preferEmbeddedLyrics,
    bool? gapless,
    bool? infiniteQueue,
    int? crossfadeSeconds,
    int? fadeOnPlayMs,
    int? fadeOnPauseMs,
    int? listenThresholdMinutes,
    int? listenThresholdPercent,
    ReplayGainMode? replayGainMode,
    double? replayGainPreampDb,
    bool? replayGainPreventClipping,
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
    replayGainMode: replayGainMode ?? this.replayGainMode,
    replayGainPreampDb: replayGainPreampDb ?? this.replayGainPreampDb,
    replayGainPreventClipping:
        replayGainPreventClipping ?? this.replayGainPreventClipping,
    audioDeviceName: audioDeviceName,
    audioDeviceDescription: audioDeviceDescription,
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
      other.listenThresholdPercent == listenThresholdPercent &&
      other.replayGainMode == replayGainMode &&
      other.replayGainPreampDb == replayGainPreampDb &&
      other.replayGainPreventClipping == replayGainPreventClipping &&
      other.audioDeviceName == audioDeviceName &&
      other.audioDeviceDescription == audioDeviceDescription;

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
    replayGainMode,
    replayGainPreampDb,
    replayGainPreventClipping,
    audioDeviceName,
    audioDeviceDescription,
  );

  @override
  String toString() =>
      'PlaybackPrefs(preferEmbeddedLyrics: $preferEmbeddedLyrics, '
      'gapless: $gapless, infiniteQueue: $infiniteQueue, '
      'crossfadeSeconds: $crossfadeSeconds, fadeOnPlayMs: $fadeOnPlayMs, '
      'fadeOnPauseMs: $fadeOnPauseMs, '
      'listenThresholdMinutes: $listenThresholdMinutes, '
      'listenThresholdPercent: $listenThresholdPercent, '
      'replayGainMode: ${replayGainMode.name}, '
      'replayGainPreampDb: $replayGainPreampDb, '
      'replayGainPreventClipping: $replayGainPreventClipping, '
      'audioDeviceName: $audioDeviceName, '
      'audioDeviceDescription: $audioDeviceDescription)';
}
