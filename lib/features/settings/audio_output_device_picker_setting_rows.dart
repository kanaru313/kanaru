import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/audio_device_choice.dart';
import '../../core/player/audio_output_device.dart';
import '../../core/player/audio_output_devices_provider.dart';
import '../../core/player/player_service.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';

Future<void> showAudioOutputDeviceDialog(BuildContext context) => showDialog(
  context: context,
  builder: (_) => const _AudioOutputDeviceDialog(),
);

/// How a driver is named in the list. Unknown drivers show as mpv names them.
String _driverLabel(String driver) => switch (driver) {
  'pipewire' => 'PipeWire',
  'pulse' => 'PulseAudio',
  'alsa' => 'ALSA',
  'jack' => 'JACK',
  'openal' => 'OpenAL',
  'sdl' => 'SDL',
  'oss' => 'OSS',
  _ => driver,
};

String _driverOf(AudioOutputDevice d) =>
    d.name.substring(0, d.name.indexOf('/'));

class _AudioOutputDeviceDialog extends ConsumerStatefulWidget {
  const _AudioOutputDeviceDialog();

  @override
  ConsumerState<_AudioOutputDeviceDialog> createState() =>
      _AudioOutputDeviceDialogState();
}

class _AudioOutputDeviceDialogState
    extends ConsumerState<_AudioOutputDeviceDialog> {
  // Read from the engine on every open: the stream only fires when a device
  // is added or removed, not when a description changes.
  late List<AudioOutputDevice> _devices = ref
      .read(audioBackendProvider)
      .audioDevices;

  /// A radio reports `null` when the one that is already selected is tapped
  /// (the tiles are `toggleable`, or nothing would be reported): nothing to
  /// change, so the dialog just closes.
  void _pick(String? name) {
    if (name == null) {
      Navigator.of(context).pop();
      return;
    }
    final settings = ref.read(settingsProvider.notifier);
    final p = ref.read(settingsProvider).playback;
    if (name == autoAudioDevice) {
      settings.setPlayback(p.withAudioDevice());
    } else {
      final device = _devices.where((d) => d.name == name).firstOrNull;
      // The device left the list while the dialog was open.
      if (device == null) return;
      settings.setPlayback(
        p.withAudioDevice(name: device.name, description: device.description),
      );
      // Choosing the failed device again changes no setting: say so
      // explicitly, or nothing would retry it.
      if (ref.read(audioOutputFailedDeviceProvider) == name) {
        ref.read(audioOutputFailedDeviceProvider.notifier).retry();
      }
    }
    Navigator.of(context).pop();
  }

  Widget _tile(AudioOutputDevice d) => RadioListTile<String>(
    value: d.name,
    toggleable: true,
    title: Text(d.description.isEmpty ? d.name : d.description),
    subtitle: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(audioOutputDevicesProvider, (_, next) {
      final list = next.value;
      if (list != null) setState(() => _devices = list);
    });
    final saved = ref.watch(
      settingsProvider.select((s) => s.playback.audioDeviceName),
    );
    final savedDescription = ref.watch(
      settingsProvider.select((s) => s.playback.audioDeviceDescription),
    );
    final failed = ref.watch(audioOutputFailedDeviceProvider);
    final choices = selectableDevices(_devices);
    final primary = primaryDriver(_devices);
    final main = [
      for (final d in choices)
        if (_driverOf(d) == primary) d,
    ];
    final others = [
      for (final d in choices)
        if (_driverOf(d) != primary) d,
    ];
    final missing = saved != null && !isAudioDeviceAvailable(saved, _devices);
    // The output is Automatic while the saved device is failed, and tapping
    // a radio that is already selected would not report a pick.
    final selected = saved == null || failed == saved ? autoAudioDevice : saved;

    return AlertDialog(
      title: Text(l10n.audioDeviceDialogTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: RadioGroup<String>(
            groupValue: selected,
            onChanged: _pick,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  value: autoAudioDevice,
                  toggleable: true,
                  title: Text(l10n.audioDeviceAuto),
                ),
                if (missing)
                  RadioListTile<String>(
                    value: saved,
                    enabled: false,
                    title: Text(
                      l10n.audioDeviceMissing(savedDescription ?? saved),
                    ),
                  ),
                for (final d in main) _tile(d),
                if (choices.isEmpty)
                  ListTile(title: Text(l10n.audioDeviceNoneFound)),
                if (others.isNotEmpty)
                  ExpansionTile(
                    title: Text(l10n.audioDeviceOtherOutputs),
                    initiallyExpanded: others.any((d) => d.name == saved),
                    children: [
                      for (final driver in {...others.map(_driverOf)}) ...[
                        ListTile(
                          dense: true,
                          title: Text(_driverLabel(driver)),
                        ),
                        for (final d in others)
                          if (_driverOf(d) == driver) _tile(d),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
