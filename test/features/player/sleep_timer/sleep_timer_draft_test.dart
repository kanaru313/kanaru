import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/playback_fade.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/sleep_timer.dart';
import 'package:kanaru/features/player/sleep_timer/sleep_timer_draft.dart';

import '../../../core/player/fake_audio_backend.dart';
import '../../../core/player/manual_fade_clock.dart';

void main() {
  const minutesTab = SleepTimerDraft();
  const tracksTab = SleepTimerDraft(tab: SleepTimerSetupTab.tracks);

  group('defaults and start rules', () {
    test('opens on 45 minutes and 3 tracks', () {
      expect(minutesTab.minutes, 45);
      expect(minutesTab.tracks, 3);
      expect(minutesTab.value, 45);
      expect(tracksTab.value, 3);
    });

    test('the number tabs can always start; End of needs a pick', () {
      expect(minutesTab.canStart, isTrue);
      expect(tracksTab.canStart, isTrue);
      const endOf = SleepTimerDraft(tab: SleepTimerSetupTab.endOf);
      expect(endOf.canStart, isFalse);
      expect(endOf.copyWith(endKind: SleepTimerMode.endOfAlbum).canStart, true);
    });
  });

  group('fromState', () {
    test('minutes: rounds the time left up', () {
      final draft = SleepTimerDraft.fromState(
        const SleepTimerState(
          mode: SleepTimerMode.minutes,
          remaining: Duration(minutes: 12, seconds: 1),
        ),
      );
      expect(draft.tab, SleepTimerSetupTab.minutes);
      expect(draft.minutes, 13);
    });

    test('tracks: the tracks left', () {
      final draft = SleepTimerDraft.fromState(
        const SleepTimerState(mode: SleepTimerMode.tracks, tracksLeft: 7),
      );
      expect(draft.tab, SleepTimerSetupTab.tracks);
      expect(draft.tracks, 7);
    });

    test('an end mode preselects its row', () {
      final draft = SleepTimerDraft.fromState(
        const SleepTimerState(mode: SleepTimerMode.endOfQueue),
      );
      expect(draft.tab, SleepTimerSetupTab.endOf);
      expect(draft.endKind, SleepTimerMode.endOfQueue);
      expect(draft.canStart, isTrue);
    });

    test('off gives the defaults', () {
      final draft = SleepTimerDraft.fromState(const SleepTimerState.off());
      expect(draft.tab, SleepTimerSetupTab.minutes);
      expect(draft.minutes, 45);
    });
  });

  group('typed numbers', () {
    test('empty and zero keep the last valid value', () {
      expect(minutesTab.withTyped(null).minutes, 45);
      expect(minutesTab.withTyped(0).minutes, 45);
      expect(tracksTab.withTyped(0).tracks, 3);
    });

    test('a number is clamped to the range of the tab', () {
      expect(minutesTab.withTyped(7).minutes, 7);
      expect(minutesTab.withTyped(999).minutes, 720);
      expect(minutesTab.withTyped(1).minutes, 1);
      expect(tracksTab.withTyped(25).tracks, 20);
      expect(tracksTab.withTyped(20).tracks, 20);
    });

    test('the other tab keeps its own number', () {
      expect(minutesTab.withTyped(90).tracks, 3);
      expect(tracksTab.withTyped(9).minutes, 45);
    });
  });

  group('slider', () {
    test('shows the number inside its range', () {
      expect(minutesTab.withTyped(7).sliderValue, 7);
      expect(minutesTab.withTyped(3).sliderValue, 5);
      expect(minutesTab.withTyped(240).sliderValue, 180);
      expect(minutesTab.withTyped(240).minutes, 240);
      expect(tracksTab.withTyped(20).sliderValue, 20);
    });

    test('has the range and step of the tab', () {
      expect((minutesTab.sliderMin, minutesTab.sliderMax), (5, 180));
      expect(minutesTab.step, 5);
      expect((tracksTab.sliderMin, tracksTab.sliderMax), (1, 20));
      expect(tracksTab.step, 1);
    });
  });

  group('- and + buttons', () {
    test('minutes move by 5 within 1 to 720', () {
      expect(minutesTab.withValue(7).stepped(-1).minutes, 2);
      expect(minutesTab.withValue(3).stepped(-1).minutes, 1);
      expect(minutesTab.withValue(718).stepped(1).minutes, 720);
      expect(minutesTab.stepped(1).minutes, 50);
    });

    test('tracks move by 1 within 1 to 20', () {
      expect(tracksTab.stepped(1).tracks, 4);
      expect(tracksTab.withValue(1).stepped(-1).tracks, 1);
      expect(tracksTab.withValue(20).stepped(1).tracks, 20);
    });

    test('they are off at the bounds', () {
      expect(minutesTab.withValue(1).canStepDown, isFalse);
      expect(minutesTab.withValue(720).canStepUp, isFalse);
      expect(minutesTab.canStepDown && minutesTab.canStepUp, isTrue);
      expect(tracksTab.withValue(1).canStepDown, isFalse);
      expect(tracksTab.withValue(20).canStepUp, isFalse);
    });
  });

  group('startOn', () {
    late ProviderContainer container;
    SleepTimerState state() => container.read(sleepTimerProvider);

    setUp(() {
      container = ProviderContainer(
        overrides: [
          audioBackendProvider.overrideWithValue(FakeAudioBackend()),
          playbackFadeClockProvider.overrideWithValue(ManualFadeClock().clock),
        ],
      );
      container.listen(sleepTimerProvider, (_, _) {});
    });
    tearDown(() => container.dispose());

    void startOn(SleepTimerDraft draft) =>
        draft.startOn(container.read(sleepTimerProvider.notifier));

    test('starts minutes', () {
      startOn(minutesTab.withTyped(720));
      expect(state().mode, SleepTimerMode.minutes);
      expect(state().remaining, const Duration(minutes: 720));
    });

    test('starts tracks', () {
      startOn(tracksTab.withTyped(5));
      expect(state().mode, SleepTimerMode.tracks);
      expect(state().tracksLeft, 5);
    });

    test('starts the end mode picked', () {
      for (final mode in [
        SleepTimerMode.endOfTrack,
        SleepTimerMode.endOfAlbum,
        SleepTimerMode.endOfQueue,
      ]) {
        startOn(
          const SleepTimerDraft(tab: SleepTimerSetupTab.endOf)
              .copyWith(endKind: mode),
        );
        expect(state().mode, mode);
      }
    });

    test('starts nothing on End of without a pick', () {
      startOn(const SleepTimerDraft(tab: SleepTimerSetupTab.endOf));
      expect(state().active, isFalse);
    });
  });
}
