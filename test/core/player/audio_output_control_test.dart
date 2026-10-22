import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/audio_output_control.dart';
import 'package:kanaru/core/player/audio_output_device.dart';
import 'package:kanaru/core/player/replay_gain_options.dart';

const _failureLine = 'Could not open/initialize audio device -> no sound.';

AudioOutputDevice _device(String name, [String? description]) =>
    AudioOutputDevice(name: name, description: description ?? name);

void main() {
  late List<(String, String)> properties;
  late List<AudioOutputDevice> listed;
  late StreamController<List<AudioOutputDevice>> updates;
  late AudioOutputControl control;
  Completer<void>? gate;

  setUp(() {
    properties = [];
    listed = [_device('auto'), _device('pipewire/x'), _device('pulse/y')];
    updates = StreamController<List<AudioOutputDevice>>.broadcast();
    gate = null;
    control = AudioOutputControl(
      setProperty: (name, value) async {
        properties.add((name, value));
        await gate?.future;
      },
      listed: () => listed,
      updates: updates.stream,
    );
  });

  tearDown(() async {
    await control.dispose();
    await updates.close();
  });

  group('isAudioOpenFailure', () {
    test('matches the line mpv prints when the output does not open', () {
      expect(isAudioOpenFailure(_failureLine), isTrue);
    });

    test('ignores other lines', () {
      expect(isAudioOpenFailure('Audio device changed'), isFalse);
      expect(isAudioOpenFailure(''), isFalse);
    });
  });

  group('output device', () {
    test('a listed device is set as it is', () async {
      await control.setAudioDevice('pipewire/x');

      expect(properties, [('audio-device', 'pipewire/x')]);
    });

    test('a name that is not listed becomes auto', () async {
      await control.setAudioDevice('pipewire/gone');
      await control.setAudioDevice('pipewire'); // a bare driver name

      expect(properties, [('audio-device', 'auto'), ('audio-device', 'auto')]);
    });

    test(
      'a failure line while on a device reports it and goes to auto',
      () async {
        final failed = <String>[];
        control.deviceFailed.listen(failed.add);
        await control.setAudioDevice('pipewire/x');
        properties.clear();

        control.onMpvLog(_failureLine);
        await pumpEventQueue();

        expect(failed, ['pipewire/x']);
        expect(properties, [('audio-device', 'auto')]);

        // Now on auto: another such line has nobody to blame.
        control.onMpvLog(_failureLine);
        await pumpEventQueue();
        expect(failed, hasLength(1));
        expect(properties, hasLength(1));
      },
    );

    test('a failure line while on auto is ignored', () async {
      final failed = <String>[];
      control.deviceFailed.listen(failed.add);

      control.onMpvLog(_failureLine);
      await pumpEventQueue();

      expect(failed, isEmpty);
      expect(properties, isEmpty);
    });

    test('other log lines are ignored', () async {
      final failed = <String>[];
      control.deviceFailed.listen(failed.add);
      await control.setAudioDevice('pipewire/x');
      properties.clear();

      control.onMpvLog('Audio device changed');
      await pumpEventQueue();

      expect(failed, isEmpty);
      expect(properties, isEmpty);
    });

    test('a failing set is swallowed and does not block the next', () async {
      var first = true;
      final guarded = AudioOutputControl(
        setProperty: (name, value) async {
          if (first) {
            first = false;
            throw StateError('mpv said no');
          }
          properties.add((name, value));
        },
        listed: () => listed,
        updates: updates.stream,
      );
      addTearDown(guarded.dispose);

      await guarded.setAudioDevice('pipewire/x');
      await guarded.setAudioDevice('pulse/y');

      expect(properties, [('audio-device', 'pulse/y')]);
    });
  });

  group('ReplayGain', () {
    test('sends the preamp, clipping and mode, mode last', () async {
      await control.setReplayGain(
        const ReplayGainOptions(
          mode: MpvReplayGain.album,
          preampDb: 2,
          allowClipping: false,
        ),
      );

      expect(properties.map((p) => p.$1), [
        'replaygain-preamp',
        'replaygain-clip',
        'replaygain',
      ]);
    });
  });

  group('devicesChanged', () {
    test('starts with the current list, then each real change', () async {
      final lists = <List<AudioOutputDevice>>[];
      final subscription = control.devicesChanged.listen(lists.add);
      await pumpEventQueue();
      expect(lists, [listed]);

      updates.add([...listed]); // equal: dropped
      updates.add([...listed, _device('pulse/z')]);
      await pumpEventQueue();
      expect(lists, hasLength(2));

      await subscription.cancel();
    });

    test('a changed description alone is a change', () async {
      final lists = <List<AudioOutputDevice>>[];
      final subscription = control.devicesChanged.listen(lists.add);
      await pumpEventQueue();

      updates.add([
        _device('auto'),
        _device('pipewire/x', 'Renamed'),
        _device('pulse/y'),
      ]);
      await pumpEventQueue();

      expect(lists, hasLength(2));
      expect(lists.last[1].description, 'Renamed');
      await subscription.cancel();
    });
  });

  group('after dispose', () {
    test('nothing runs, not even a call that was queued', () async {
      gate = Completer<void>();
      final running = control.setAudioDevice('pipewire/x');
      final queued = control.setAudioDevice('pulse/y');
      await pumpEventQueue(); // the first is running, held by the gate
      final disposing = control.dispose();

      gate!.complete();
      await Future.wait([running, queued, disposing]);
      expect(properties, [('audio-device', 'pipewire/x')]);

      await control.setAudioDevice('pipewire/x');
      await control.setReplayGain(ReplayGainOptions.engineDefault);
      control.onMpvLog(_failureLine);
      await pumpEventQueue();
      expect(properties, hasLength(1));
    });
  });
}
