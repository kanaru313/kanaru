import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/replay_gain_options.dart';
import 'package:kanaru/core/settings/playback_prefs.dart';

void main() {
  PlaybackPrefs prefs(
    ReplayGainMode mode, {
    double preamp = 0,
    bool preventClipping = true,
  }) => PlaybackPrefs(
    replayGainMode: mode,
    replayGainPreampDb: preamp,
    replayGainPreventClipping: preventClipping,
  );

  group('replayGainOptionsFor', () {
    test('maps every mode, auto by whether an album run plays', () {
      MpvReplayGain modeOf(ReplayGainMode mode, {required bool run}) =>
          replayGainOptionsFor(prefs(mode), albumRun: run).mode;

      for (final run in [false, true]) {
        expect(modeOf(ReplayGainMode.off, run: run), MpvReplayGain.no);
        expect(modeOf(ReplayGainMode.track, run: run), MpvReplayGain.track);
        expect(modeOf(ReplayGainMode.album, run: run), MpvReplayGain.album);
      }
      expect(modeOf(ReplayGainMode.auto, run: true), MpvReplayGain.album);
      expect(modeOf(ReplayGainMode.auto, run: false), MpvReplayGain.track);
    });

    test('the default settings are what mpv does without being told', () {
      expect(
        replayGainOptionsFor(const PlaybackPrefs(), albumRun: false),
        ReplayGainOptions.engineDefault,
      );
    });

    test('the preamp is clamped, and a value that is no number is 0', () {
      double preampOf(double db) => replayGainOptionsFor(
        prefs(ReplayGainMode.track, preamp: db),
        albumRun: false,
      ).preampDb;

      expect(preampOf(20), 15);
      expect(preampOf(-99), -15);
      expect(preampOf(double.nan), 0);
      expect(preampOf(double.infinity), 0);
      expect(preampOf(2.5), 2.5);
    });

    test('clipping is inverted: preventing it is replaygain-clip=no', () {
      expect(
        replayGainOptionsFor(
          prefs(ReplayGainMode.track),
          albumRun: false,
        ).allowClipping,
        isFalse,
      );
      expect(
        replayGainOptionsFor(
          prefs(ReplayGainMode.track, preventClipping: false),
          albumRun: false,
        ).allowClipping,
        isTrue,
      );
    });
  });

  group('toMpvProperties', () {
    test('sets the mode last, with plain decimals', () {
      const options = ReplayGainOptions(
        mode: MpvReplayGain.album,
        preampDb: -3,
        allowClipping: true,
      );
      expect(options.toMpvProperties(), [
        ('replaygain-preamp', '-3.00'),
        ('replaygain-clip', 'yes'),
        ('replaygain', 'album'),
      ]);
    });

    test('rounds to two decimals and never writes a negative zero', () {
      String preamp(double db) => ReplayGainOptions(
        mode: MpvReplayGain.track,
        preampDb: db,
        allowClipping: false,
      ).toMpvProperties().first.$2;

      expect(preamp(2.5), '2.50');
      expect(preamp(-0.0), '0.00');
      expect(preamp(0.126), '0.13');
    });
  });

  group('isAlbumRun', () {
    const a = (artist: 'Ann', title: 'One');
    const same = (artist: 'Ann', title: 'One');
    const other = (artist: 'Ann', title: 'Two');
    const otherArtist = (artist: 'Bob', title: 'One');
    const noArtist = (artist: null, title: 'One');

    test('needs a current key', () {
      expect(isAlbumRun(current: null, previous: a, next: a), isFalse);
    });

    test('a neighbour on either side with the same key makes a run', () {
      expect(isAlbumRun(previous: same, current: a), isTrue);
      expect(isAlbumRun(current: a, next: same), isTrue);
    });

    test('neighbours of other albums or without a key do not', () {
      expect(isAlbumRun(previous: other, current: a, next: other), isFalse);
      expect(isAlbumRun(current: a), isFalse);
      expect(isAlbumRun(previous: null, current: a, next: null), isFalse);
    });

    test('the same title under another artist is another album', () {
      expect(isAlbumRun(previous: otherArtist, current: a), isFalse);
    });

    test('albums without an artist match by title', () {
      expect(isAlbumRun(previous: noArtist, current: noArtist), isTrue);
      expect(isAlbumRun(previous: noArtist, current: a), isFalse);
    });
  });
}
