import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/audio_device_choice.dart';
import 'package:kanaru/core/player/audio_output_device.dart';

AudioOutputDevice d(String name, [String description = '']) =>
    AudioOutputDevice(name: name, description: description);

/// The devices of the dev machine, as `mpv --audio-device=help` lists them.
final devMachine = [
  d('auto', 'Autoselect device'),
  d('pipewire', 'Default (pipewire)'),
  for (final n in ['HDMI3', 'HDMI2', 'HDMI1', 'Speaker'])
    d('pipewire/alsa_output.pci-0000_00_1f.3.HiFi__${n}__sink', n),
  for (final n in ['HDMI3', 'HDMI2', 'HDMI1', 'Speaker'])
    d('pulse/alsa_output.pci-0000_00_1f.3.HiFi__${n}__sink', n),
  d('alsa', 'Default (alsa)'),
  d('alsa/pipewire', 'PipeWire Sound Server'),
  d('alsa/sysdefault:CARD=sofhdadsp', 'sof-hda-dsp'),
  d('openal', 'Default (openal)'),
];

void main() {
  group('selectableDevices', () {
    test('keeps entries with a driver and a device, drops defaults', () {
      final names = selectableDevices(devMachine).map((e) => e.name).toList();

      expect(names, hasLength(10));
      expect(names, isNot(contains('auto')));
      expect(names, isNot(contains('pipewire')));
      expect(names, isNot(contains('alsa')));
      expect(names, isNot(contains('openal')));
      expect(names.where((n) => n.startsWith('pipewire/')), hasLength(4));
      expect(names.where((n) => n.startsWith('pulse/')), hasLength(4));
      expect(names.where((n) => n.startsWith('alsa/')), hasLength(2));
    });

    test('an empty device part or driver part is not a device', () {
      expect(selectableDevices([d('alsa/'), d('/x'), d('')]), isEmpty);
    });
  });

  group('primaryDriver', () {
    test('is the driver of the first device mpv lists', () {
      expect(primaryDriver(devMachine), 'pipewire');
    });

    test('is pulse in a build without pipewire', () {
      expect(primaryDriver([d('auto'), d('pulse/x'), d('alsa/hw:0')]), 'pulse');
    });

    test('is null when only auto is listed', () {
      expect(primaryDriver([d('auto')]), isNull);
      expect(selectableDevices([d('auto')]), isEmpty);
    });
  });

  group('effectiveAudioDevice', () {
    final list = devMachine;
    const pipewireSpeaker =
        'pipewire/alsa_output.pci-0000_00_1f.3.HiFi__Speaker__sink';

    test('nothing saved, or auto, is auto', () {
      expect(effectiveAudioDevice(null, list), autoAudioDevice);
      expect(effectiveAudioDevice('auto', list), autoAudioDevice);
    });

    test('a device listed once is used', () {
      expect(effectiveAudioDevice(pipewireSpeaker, list), pipewireSpeaker);
      expect(isAudioDeviceAvailable(pipewireSpeaker, list), isTrue);
    });

    test('a device listed twice is not used', () {
      final twice = [d('pulse/x'), d('pulse/x', 'again')];
      expect(effectiveAudioDevice('pulse/x', twice), autoAudioDevice);
    });

    test('a device that is not listed is not used', () {
      expect(effectiveAudioDevice('pipewire/gone', list), autoAudioDevice);
      expect(isAudioDeviceAvailable('pipewire/gone', list), isFalse);
    });

    test('names mpv would take as something else are never sent', () {
      // Even when the list holds them: a bare driver, a driver without a
      // device, and anything that is not `<driver>/<device>`.
      final odd = [d('pcm/out.wav'), d('null/x'), d('help'), d(''), ...list];
      for (final name in ['help', '', 'pipewire', 'jack', 'alsa/']) {
        expect(effectiveAudioDevice(name, odd), autoAudioDevice, reason: name);
      }
      // Not in the list: refused as well.
      expect(effectiveAudioDevice('pcm/out.wav', list), autoAudioDevice);
      expect(effectiveAudioDevice('null/x', list), autoAudioDevice);
    });

    test('an alsa card and a pulse device of another driver are allowed', () {
      expect(
        effectiveAudioDevice('alsa/sysdefault:CARD=sofhdadsp', list),
        'alsa/sysdefault:CARD=sofhdadsp',
      );
      expect(
        effectiveAudioDevice(
          'pulse/alsa_output.pci-0000_00_1f.3.HiFi__HDMI1__sink',
          list,
        ),
        'pulse/alsa_output.pci-0000_00_1f.3.HiFi__HDMI1__sink',
      );
    });
  });

  group('audioDriverForLog', () {
    test('keeps only the driver', () {
      expect(audioDriverForLog('pipewire/bluez_output.AA_BB.1'), 'pipewire');
      expect(audioDriverForLog('alsa/sysdefault:CARD=x'), 'alsa');
    });

    test('never returns an address or a serial', () {
      expect(audioDriverForLog('bluez_output.AA:BB:CC:DD:EE:FF'), 'unknown');
      expect(audioDriverForLog('AA:BB:CC/x'), 'unknown');
      expect(audioDriverForLog('${'a' * 40}/x'), hasLength(16));
    });
  });
}
