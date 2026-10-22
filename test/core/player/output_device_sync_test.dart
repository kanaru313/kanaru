import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/output_device_sync.dart';
import 'package:kanaru/core/settings/playback_prefs.dart';

import 'audio_sync_test_support.dart';
import 'fake_audio_backend.dart';

void main() {
  late FakeAudioBackend fake;
  late List<String?> failedReports;
  late OutputDeviceSync sync;

  setUp(() {
    fake = FakeAudioBackend();
    failedReports = [];
    sync = OutputDeviceSync(
      backend: fake,
      onFailedDeviceChanged: failedReports.add,
    );
  });

  tearDown(() => sync.dispose());

  group('output device', () {
    const x = 'pipewire/x';

    PlaybackPrefs saved([String? name = x]) =>
        const PlaybackPrefs().withAudioDevice(name: name, description: 'X');

    testWidgets('waits for the list, then uses the saved device', (
      tester,
    ) async {
      sync.setPrefs(saved());
      sync.setDevices([device('auto')]);
      expect(fake.audioCalls, isEmpty);

      sync.setDevices([device('auto'), device(x)]);
      expect(fake.audioCalls, ['setAudioDevice($x)']);
    });

    testWidgets('a device that leaves goes to auto at once, back after 2 s', (
      tester,
    ) async {
      sync.setPrefs(saved());
      sync.setDevices([device('auto'), device(x)]);
      fake.audioCalls.clear();

      sync.setDevices([device('auto')]);
      expect(fake.audioCalls, ['setAudioDevice(auto)']);
      fake.audioCalls.clear();

      sync.setDevices([device('auto'), device(x)]);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(fake.audioCalls, isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      expect(fake.audioCalls, ['setAudioDevice($x)']);
    });

    testWidgets('a device that flickers is not moved to while it does', (
      tester,
    ) async {
      sync.setPrefs(saved());
      sync.setDevices([device('auto'), device(x)]);
      sync.setDevices([device('auto')]);
      fake.audioCalls.clear();

      sync.setDevices([device('auto'), device(x)]);
      await tester.pump(const Duration(seconds: 1));
      sync.setDevices([device('auto')]);
      await tester.pump(const Duration(seconds: 1));
      sync.setDevices([device('auto'), device(x)]);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(fake.audioCalls, isEmpty);
      await tester.pump(const Duration(milliseconds: 600));
      expect(fake.audioCalls, ['setAudioDevice($x)']);
    });

    test('names mpv would take as something else are never sent', () {
      final list = [device('auto'), device('pipewire'), device('jack')];
      for (final name in ['pcm/out.wav', 'pipewire', 'jack', 'help']) {
        sync.setPrefs(saved(name));
        sync.setDevices(list);
      }

      expect(fake.audioCalls, isEmpty);
    });

    test('a failed device stays on auto while it is listed', () {
      sync.setPrefs(saved());
      sync.setDevices([device('auto'), device(x)]);
      fake.audioCalls.clear();

      sync.markDeviceFailed(x);
      sync.setDevices([device('auto'), device(x), device('pulse/y')]);

      expect(fake.audioCalls, isEmpty); // the backend already went to auto
      expect(sync.failedDevice, x);
      expect(failedReports, [x]);
    });

    test('choosing it again tries it again', () {
      sync.setPrefs(saved());
      sync.setDevices([device('auto'), device(x)]);
      sync.markDeviceFailed(x);
      fake.audioCalls.clear();

      sync.setPrefs(saved('pulse/y'));
      sync.setPrefs(saved());

      expect(fake.audioCalls, ['setAudioDevice($x)']);
      expect(sync.failedDevice, isNull);
      expect(failedReports, [x, null]);
    });

    test('retrying clears the failure and uses the saved device again', () {
      sync.setPrefs(saved());
      sync.setDevices([device('auto'), device(x)]);
      sync.markDeviceFailed(x);
      fake.audioCalls.clear();

      sync.retryDevice();
      sync.retryDevice(); // nothing left to retry

      expect(fake.audioCalls, ['setAudioDevice($x)']);
      expect(sync.failedDevice, isNull);
      expect(failedReports, [x, null]);
    });

    testWidgets('a failed device that leaves and returns is tried again', (
      tester,
    ) async {
      sync.setPrefs(saved());
      sync.setDevices([device('auto'), device(x)]);
      sync.markDeviceFailed(x);
      fake.audioCalls.clear();

      sync.setDevices([device('auto')]);
      expect(sync.failedDevice, isNull);
      sync.setDevices([device('auto'), device(x)]);
      await tester.pump(const Duration(seconds: 3));

      expect(fake.audioCalls, ['setAudioDevice($x)']);
    });

    test('a late failure of the previous choice re-applies the saved one', () {
      const y = 'pulse/y';
      sync.setPrefs(saved(y));
      sync.setDevices([device('auto'), device(x), device(y)]);
      expect(fake.audioCalls, ['setAudioDevice($y)']);
      fake.audioCalls.clear();

      // The backend fell back to auto when x failed, after y was chosen.
      sync.markDeviceFailed(x);

      expect(fake.audioCalls, ['setAudioDevice($y)']);
      expect(sync.failedDevice, isNull);
    });

    test('the device list the engine has at the start is used', () {
      sync.setPrefs(saved());
      sync.setDevices([device('auto'), device(x)]);
      sync.setDevices([device('auto'), device(x)]); // the stream repeats it

      expect(fake.audioCalls, ['setAudioDevice($x)']);
    });

    test('a failure of a device that is not the saved one is ignored', () {
      sync.setPrefs(saved('pulse/y'));
      sync.markDeviceFailed(x);

      expect(sync.failedDevice, isNull);
      expect(failedReports, isEmpty);
    });
  });

  testWidgets('nothing reaches the engine after dispose', (tester) async {
    sync.setPrefs(const PlaybackPrefs().withAudioDevice(name: 'pipewire/x'));
    sync.setDevices([device('auto'), device('pipewire/x')]);
    // A device that returns after leaving waits on a timer.
    sync.setDevices([device('auto')]);
    sync.setDevices([device('auto'), device('pipewire/x')]);
    fake.audioCalls.clear();

    sync.dispose();
    await tester.pump(const Duration(seconds: 5));
    sync.setPrefs(const PlaybackPrefs());
    sync.setDevices([device('auto')]);
    sync.markDeviceFailed('pipewire/x');

    expect(fake.audioCalls, isEmpty);
  });
}
