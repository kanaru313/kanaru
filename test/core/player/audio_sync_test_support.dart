import 'package:kanaru/core/player/audio_output_device.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/replay_gain_options.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/playback_prefs.dart';

/// Shared by the ReplayGain and output device sync tests.
const albumOne = (artist: 'Ann', title: 'One');
const albumTwo = (artist: 'Bob', title: 'Two');

/// Album of each test file: `a1`, `a2` and `a3` share one, `b1` has another,
/// `s` and anything else has none.
const albumsByPath = <String, AlbumRunKey>{
  '/m/a1.flac': albumOne,
  '/m/a2.flac': albumOne,
  '/m/a3.flac': albumOne,
  '/m/b1.flac': albumTwo,
};

Track t(String name) => Track.fromPath('/m/$name.flac');

PlayQueue queueOf(
  List<String> names, {
  int at = 0,
  RepeatMode repeat = RepeatMode.off,
}) => PlayQueue.open([for (final n in names) t(n)], at, repeat: repeat);

AudioOutputDevice device(String name) =>
    AudioOutputDevice(name: name, description: name);

PlaybackPrefs rg(
  ReplayGainMode mode, {
  double preamp = 0,
  bool preventClipping = true,
}) => PlaybackPrefs(
  replayGainMode: mode,
  replayGainPreampDb: preamp,
  replayGainPreventClipping: preventClipping,
);
