import 'package:media_kit/media_kit.dart' hide Track;

import 'audio_output_control.dart';
import 'audio_output_device.dart';
import 'replay_gain_options.dart';

/// The audio output half of [MediaKitBackend]: [AudioOutputControl] wired to
/// one media_kit player. Only the media_kit types are handled here; what to
/// do with them is decided in the control.
class MpvAudioOutput {
  MpvAudioOutput(Player player, NativePlayer native)
    : _control = AudioOutputControl(
        setProperty: native.setProperty,
        listed: () => _map(player.state.audioDevices),
        updates: player.stream.audioDevices.map(_map),
      );

  final AudioOutputControl _control;

  Future<void> setReplayGain(ReplayGainOptions options) =>
      _control.setReplayGain(options);

  Future<void> setAudioDevice(String name) => _control.setAudioDevice(name);

  List<AudioOutputDevice> get devices => _control.devices;

  Stream<List<AudioOutputDevice>> get devicesChanged => _control.devicesChanged;

  Stream<String> get deviceFailed => _control.deviceFailed;

  /// Call with every mpv log line, to catch a device that fails to open.
  void onMpvLog(PlayerLog entry) => _control.onMpvLog(entry.text);

  /// Stops new calls and waits for the ones running.
  Future<void> dispose() => _control.dispose();

  static List<AudioOutputDevice> _map(List<AudioDevice> raw) => [
    for (final d in raw)
      AudioOutputDevice(name: d.name, description: d.description),
  ];
}
