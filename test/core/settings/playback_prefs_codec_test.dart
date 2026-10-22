import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/playback_prefs.dart';
import 'package:kanaru/core/settings/playback_prefs_codec.dart';
import 'package:kanaru/core/stats/listen_accumulator.dart';

void main() {
  test('missing object or keys give the defaults', () {
    expect(decodePlaybackPrefs(null).$1, const PlaybackPrefs());
    expect(decodePlaybackPrefs(<String, Object?>{}).$1, const PlaybackPrefs());
    expect(decodePlaybackPrefs(7).$2, isEmpty);
    expect(decodePlaybackPrefs(['x']).$1, const PlaybackPrefs());
  });

  test('defaults are what the player does today', () {
    const d = PlaybackPrefs();
    expect(d.gapless, isTrue);
    expect(d.infiniteQueue, isFalse);
    expect(d.crossfadeSeconds, 0);
    expect(d.fadeOnPlayMs, 0);
    expect(d.fadeOnPauseMs, 0);
    expect(d.listenThresholdMinutes, listenThresholdCap.inMinutes);
    expect(d.listenThresholdPercent, 50);
  });

  test('values round-trip', () {
    const prefs = PlaybackPrefs(
      preferEmbeddedLyrics: false,
      gapless: false,
      infiniteQueue: true,
      crossfadeSeconds: 6,
      fadeOnPlayMs: 300,
      fadeOnPauseMs: 500,
      listenThresholdMinutes: 2,
      listenThresholdPercent: 30,
    );

    expect(decodePlaybackPrefs(encodePlaybackPrefs(prefs)).$1, prefs);
  });

  test('values of the wrong type give the default of that key only', () {
    for (final bad in <Object?>['x', null, <Object?>[], 2.5]) {
      final decoded = decodePlaybackPrefs({
        'preferEmbeddedLyrics': bad,
        'gapless': bad,
        'infiniteQueue': bad,
        'crossfadeSeconds': bad,
        'fadeOnPlayMs': bad,
        'fadeOnPauseMs': bad,
        'listenThresholdMinutes': bad,
        'listenThresholdPercent': bad,
      }).$1;

      expect(decoded, const PlaybackPrefs(), reason: '$bad');
    }
  });

  test('numbers outside the range are moved to the nearest bound', () {
    PlaybackPrefs decode(int n) => decodePlaybackPrefs({
      'crossfadeSeconds': n,
      'fadeOnPlayMs': n,
      'fadeOnPauseMs': n,
      'listenThresholdMinutes': n,
      'listenThresholdPercent': n,
    }).$1;

    final low = decode(-3);
    expect(low.crossfadeSeconds, 0);
    expect(low.fadeOnPlayMs, 0);
    expect(low.fadeOnPauseMs, 0);
    expect(low.listenThresholdMinutes, PlaybackPrefs.minListenThresholdMinutes);
    expect(low.listenThresholdPercent, PlaybackPrefs.minListenThresholdPercent);

    final high = decode(1000000);
    expect(high.crossfadeSeconds, PlaybackPrefs.maxCrossfadeSeconds);
    expect(high.fadeOnPlayMs, PlaybackPrefs.maxFadeMs);
    expect(high.fadeOnPauseMs, PlaybackPrefs.maxFadeMs);
    expect(
      high.listenThresholdMinutes,
      PlaybackPrefs.maxListenThresholdMinutes,
    );
    expect(
      high.listenThresholdPercent,
      PlaybackPrefs.maxListenThresholdPercent,
    );
  });

  test('keys this version does not know are kept', () {
    final (prefs, extra) = decodePlaybackPrefs({
      'gapless': false,
      'eq': [1],
    });

    expect(extra, {
      'eq': [1],
    });
    final json = encodePlaybackPrefs(prefs, extra: extra);
    expect(json['eq'], [1]);
    expect(json['gapless'], false);
  });

  group('ReplayGain and output device', () {
    test('defaults keep ReplayGain off and the automatic device', () {
      const d = PlaybackPrefs();
      expect(d.replayGainMode, ReplayGainMode.off);
      expect(d.replayGainPreampDb, 0);
      expect(d.replayGainPreventClipping, isTrue);
      expect(d.audioDeviceName, isNull);
      expect(d.audioDeviceDescription, isNull);
    });

    test('values round-trip', () {
      final prefs = const PlaybackPrefs(
        replayGainMode: ReplayGainMode.auto,
        replayGainPreampDb: -4.5,
        replayGainPreventClipping: false,
      ).withAudioDevice(name: 'pipewire/usb-dac', description: 'USB DAC');

      final json = encodePlaybackPrefs(prefs);
      expect(json['replayGainMode'], 'auto');
      expect(json['audioDeviceName'], 'pipewire/usb-dac');
      expect(decodePlaybackPrefs(json).$1, prefs);
      for (final mode in ReplayGainMode.values) {
        final p = PlaybackPrefs(replayGainMode: mode);
        expect(decodePlaybackPrefs(encodePlaybackPrefs(p)).$1, p);
      }
    });

    test('the device keys are left out while no device is chosen', () {
      final json = encodePlaybackPrefs(const PlaybackPrefs());
      expect(json.containsKey('audioDeviceName'), isFalse);
      expect(json.containsKey('audioDeviceDescription'), isFalse);
      expect(decodePlaybackPrefs(json).$1, const PlaybackPrefs());
    });

    test('preamp outside the range is moved to the nearest bound', () {
      double preamp(Object? value) =>
          decodePlaybackPrefs({'replayGainPreampDb': value})
              .$1
              .replayGainPreampDb;
      expect(preamp(20), PlaybackPrefs.maxReplayGainPreampDb);
      expect(preamp(-99.5), PlaybackPrefs.minReplayGainPreampDb);
      expect(preamp(3), 3.0);
      expect(preamp('3'), 0);
      expect(preamp(double.nan), 0);
      expect(preamp(double.infinity), 0);
    });

    test('values of the wrong type give the default of that key only', () {
      final prefs = decodePlaybackPrefs({
        'replayGainMode': 'loud',
        'replayGainPreventClipping': 'yes',
        'audioDeviceName': 42,
        'audioDeviceDescription': ['x'],
        'gapless': false,
      }).$1;
      expect(prefs, const PlaybackPrefs(gapless: false));
    });

    test('an empty device name is the automatic device', () {
      final prefs = decodePlaybackPrefs({
        'audioDeviceName': '',
        'audioDeviceDescription': 'Speakers',
      }).$1;
      expect(prefs.audioDeviceName, isNull);
      expect(prefs.audioDeviceDescription, isNull);
    });

    test('withAudioDevice sets both fields and resets to auto', () {
      final chosen = const PlaybackPrefs(gapless: false)
          .withAudioDevice(name: 'alsa/hw', description: 'HW');
      expect(chosen.audioDeviceName, 'alsa/hw');
      expect(chosen.audioDeviceDescription, 'HW');
      expect(chosen.gapless, isFalse);

      // copyWith keeps the device.
      expect(chosen.copyWith(gapless: true).audioDeviceName, 'alsa/hw');

      final reset = chosen.withAudioDevice();
      expect(reset.audioDeviceName, isNull);
      expect(reset.audioDeviceDescription, isNull);
      expect(reset, const PlaybackPrefs(gapless: false));

      // A description without a name is dropped.
      expect(
        const PlaybackPrefs().withAudioDevice(description: 'X'),
        const PlaybackPrefs(),
      );
    });
  });
}
