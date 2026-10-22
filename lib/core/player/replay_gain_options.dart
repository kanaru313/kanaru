import '../settings/playback_prefs.dart';

/// Values of mpv's `replaygain` option.
enum MpvReplayGain { no, track, album }

/// What the engine is told about ReplayGain: the three mpv options.
class ReplayGainOptions {
  const ReplayGainOptions({
    required this.mode,
    required this.preampDb,
    required this.allowClipping,
  });

  /// What a fresh mpv does (`mpv --list-options`: `replaygain=no`,
  /// `replaygain-preamp=0`, `replaygain-clip=no`), so applying it is a no-op.
  static const engineDefault = ReplayGainOptions(
    mode: MpvReplayGain.no,
    preampDb: 0,
    allowClipping: false,
  );

  final MpvReplayGain mode;
  final double preampDb;

  /// Let a boosted peak clip instead of lowering the gain.
  final bool allowClipping;

  /// The mpv properties to set, in the order to set them. The mode goes last:
  /// each of the three recomputes the gain of the playing file at once, and
  /// this order never passes through a mode with the old preamp. Clipping is
  /// inverted on purpose: mpv's `replaygain-clip=yes` *allows* clipping (its
  /// `audio.c` lowers the gain only when the flag is off).
  List<(String, String)> toMpvProperties() => [
    ('replaygain-preamp', _preamp(preampDb)),
    ('replaygain-clip', allowClipping ? 'yes' : 'no'),
    ('replaygain', mode.name),
  ];

  /// Two decimals with a `.` and an ASCII `-`, whatever the locale; `+ 0.0`
  /// turns `-0.0` into `0.0`.
  static String _preamp(double db) => (db + 0.0).toStringAsFixed(2);

  @override
  bool operator ==(Object other) =>
      other is ReplayGainOptions &&
      other.mode == mode &&
      other.preampDb == preampDb &&
      other.allowClipping == allowClipping;

  @override
  int get hashCode => Object.hash(mode, preampDb, allowClipping);

  @override
  String toString() => 'ReplayGainOptions($mode, $preampDb, $allowClipping)';
}

/// Identity of an album as the library keys it (`albumArtistKey`,
/// `albumTitleKey`). The artist is null for an album without one.
typedef AlbumRunKey = ({String? artist, String title});

/// Whether the track between [previous] and [next] is part of a run of
/// tracks of one album: a neighbour with the same key as [current]. A
/// missing key (no library row, no album) never makes a run.
bool isAlbumRun({
  AlbumRunKey? previous,
  required AlbumRunKey? current,
  AlbumRunKey? next,
}) {
  if (current == null) return false;
  return previous == current || next == current;
}

/// The engine options for [prefs]. [albumRun] only matters for
/// [ReplayGainMode.auto]: album gain inside a run, track gain otherwise.
/// The preamp is clamped to the app's range, and an unusable value is 0.
ReplayGainOptions replayGainOptionsFor(
  PlaybackPrefs prefs, {
  required bool albumRun,
}) {
  final MpvReplayGain mode = switch (prefs.replayGainMode) {
    ReplayGainMode.off => MpvReplayGain.no,
    ReplayGainMode.track => MpvReplayGain.track,
    ReplayGainMode.album => MpvReplayGain.album,
    ReplayGainMode.auto => albumRun ? MpvReplayGain.album : MpvReplayGain.track,
  };
  final preamp = prefs.replayGainPreampDb;
  return ReplayGainOptions(
    mode: mode,
    preampDb: preamp.isFinite
        ? preamp
              .clamp(
                PlaybackPrefs.minReplayGainPreampDb,
                PlaybackPrefs.maxReplayGainPreampDb,
              )
              .toDouble()
        : 0,
    allowClipping: !prefs.replayGainPreventClipping,
  );
}
