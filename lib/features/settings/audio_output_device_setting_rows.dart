import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/audio_device_choice.dart';
import '../../core/player/audio_output_device.dart';
import '../../core/player/audio_output_devices_provider.dart';
import '../../core/player/player_service.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'audio_output_device_picker_setting_rows.dart';
import 'setting_row.dart';

/// The output device row: names the chosen device (or why Automatic is in
/// use instead) and opens the dialog that changes it.
class AudioOutputDeviceSettingRow extends ConsumerWidget {
  const AudioOutputDeviceSettingRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = ref.watch(settingsProvider.select((s) => s.playback));
    final failed = ref.watch(audioOutputFailedDeviceProvider);
    final devices = _devices(ref);
    final saved = p.audioDeviceName;
    final shown = p.audioDeviceDescription ?? saved;

    final String subtitle;
    if (saved == null || shown == null) {
      subtitle = l10n.audioDeviceAuto;
    } else if (!isAudioDeviceAvailable(saved, devices)) {
      subtitle = l10n.audioDeviceMissing(shown);
    } else if (failed == saved) {
      subtitle = l10n.audioDeviceFailed(shown);
    } else {
      subtitle = shown;
    }

    return SettingRow.single(
      title: l10n.settingsAudioOutputDevice,
      subtitle: subtitle,
      control: FilledButton.tonal(
        style: settingButtonStyle(),
        onPressed: () => showAudioOutputDeviceDialog(context),
        child: Text(
          l10n.audioDeviceChange,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// The latest list; before the first event, what the engine lists now.
  static List<AudioOutputDevice> _devices(WidgetRef ref) =>
      ref.watch(audioOutputDevicesProvider).value ??
      ref.read(audioBackendProvider).audioDevices;
}
