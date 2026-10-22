import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_output_device.dart';
import 'player_service.dart';

/// Output devices mpv lists, now and as they change (a headset plugged in or
/// out). Includes `auto` and bare driver names: pick the entries to show
/// with `selectableDevices`.
final audioOutputDevicesProvider = StreamProvider<List<AudioOutputDevice>>(
  (ref) => ref.watch(audioBackendProvider).audioDevicesChanged,
);

/// The saved output device that mpv could not open this session, or `null`.
/// Written by the player; playback has already gone back to `auto`.
class AudioOutputFailedDevice extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? name) => state = name;
}

final audioOutputFailedDeviceProvider =
    NotifierProvider<AudioOutputFailedDevice, String?>(
      AudioOutputFailedDevice.new,
    );
