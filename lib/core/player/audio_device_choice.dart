import 'audio_output_device.dart';

/// mpv's own choice of output device.
const autoAudioDevice = 'auto';

/// The devices a user can pick: entries named `<driver>/<device>`. `auto` and
/// a bare driver name (`pipewire`, `alsa`, `jack`) are left out: they are
/// "the default", and a bare driver name would force a driver without naming
/// a device. One list for the sync, the backend and the settings UI, so none
/// of them accepts a name the others would not show.
List<AudioOutputDevice> selectableDevices(List<AudioOutputDevice> available) =>
    [
      for (final device in available)
        if (_hasDeviceName(device.name)) device,
    ];

bool _hasDeviceName(String name) {
  final slash = name.indexOf('/');
  return slash > 0 && slash < name.length - 1;
}

/// Driver of the first selectable entry. mpv lists devices in the order of
/// its driver preference, so this is the driver `auto` would use. Not
/// `current-ao`, which is empty until the first track plays. `null` when
/// nothing is selectable.
String? primaryDriver(List<AudioOutputDevice> available) {
  final first = selectableDevices(available).firstOrNull;
  if (first == null) return null;
  return first.name.substring(0, first.name.indexOf('/'));
}

/// Whether [saved] names exactly one selectable device in [available].
bool isAudioDeviceAvailable(String? saved, List<AudioOutputDevice> available) =>
    saved != null &&
    saved != autoAudioDevice &&
    selectableDevices(available).where((d) => d.name == saved).length == 1;

/// The device to give mpv for the saved setting: [saved] when it names
/// exactly one selectable device, else `auto`. mpv ignores a failed
/// `audio-device` change without telling, so a name that is not in the list
/// is never sent.
String effectiveAudioDevice(String? saved, List<AudioOutputDevice> available) =>
    isAudioDeviceAvailable(saved, available) ? saved! : autoAudioDevice;

/// The part of a device name that is safe to log. A device name can carry a
/// Bluetooth address or a USB serial, and the logs are what users attach to
/// bug reports, so only the driver (before the `/`) is kept.
String audioDriverForLog(String name) {
  final slash = name.indexOf('/');
  if (slash <= 0) return 'unknown';
  final driver = name.substring(0, slash > 16 ? 16 : slash);
  return RegExp(r'^[a-z0-9_-]+$').hasMatch(driver) ? driver : 'unknown';
}
