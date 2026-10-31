import '../../../core/player/sleep_timer.dart';

/// The tabs of the sleep timer dialog.
enum SleepTimerSetupTab { minutes, tracks, endOf }

/// Minutes the quick choice chips offer.
const sleepTimerMinutePresets = [15, 30, 45, 60, 90];

/// Tracks the quick choice chips offer.
const sleepTimerTrackPresets = [1, 2, 3, 5, 10];

/// Range and step of the slider (the typed number goes wider).
const sleepTimerSliderMinMinutes = 5;
const sleepTimerSliderMaxMinutes = 180;
const sleepTimerMinutesStep = 5;

const _defaultMinutes = 45;
const _defaultTracks = 3;

/// What the user has chosen in the dialog and not started yet. Pure: the
/// number field, slider, buttons and chips all go through the methods
/// below, so they agree on the ranges.
class SleepTimerDraft {
  const SleepTimerDraft({
    this.tab = SleepTimerSetupTab.minutes,
    this.minutes = _defaultMinutes,
    this.tracks = _defaultTracks,
    this.endKind,
  });

  /// Starts from the running timer: its mode's tab, with its values.
  factory SleepTimerDraft.fromState(SleepTimerState state) {
    switch (state.mode) {
      case SleepTimerMode.minutes:
        // Rounded up to whole minutes, within the typed range.
        final minutes = (state.remaining.inSeconds / 60).ceil().clamp(
          sleepTimerMinMinutes,
          sleepTimerMaxMinutes,
        );
        return SleepTimerDraft(minutes: minutes);
      case SleepTimerMode.tracks:
        return SleepTimerDraft(
          tab: SleepTimerSetupTab.tracks,
          tracks: state.tracksLeft,
        );
      case SleepTimerMode.endOfTrack ||
          SleepTimerMode.endOfAlbum ||
          SleepTimerMode.endOfQueue:
        return SleepTimerDraft(
          tab: SleepTimerSetupTab.endOf,
          endKind: state.mode,
        );
      case null:
        return const SleepTimerDraft();
    }
  }

  final SleepTimerSetupTab tab;
  final int minutes;
  final int tracks;

  /// The end of track, album or queue mode picked on the End of tab.
  final SleepTimerMode? endKind;

  bool get _isTracks => tab == SleepTimerSetupTab.tracks;

  /// Whether Start has something to start.
  bool get canStart => tab != SleepTimerSetupTab.endOf || endKind != null;

  /// The number the big field shows on the number tabs.
  int get value => _isTracks ? tracks : minutes;

  /// Range a typed number is kept in.
  int get min => _isTracks ? sleepTimerMinTracks : sleepTimerMinMinutes;
  int get max => _isTracks ? sleepTimerMaxTracks : sleepTimerMaxMinutes;

  /// Amount of the - and + buttons and of a slider step.
  int get step => _isTracks ? 1 : sleepTimerMinutesStep;

  double get sliderMin =>
      (_isTracks ? sleepTimerMinTracks : sleepTimerSliderMinMinutes).toDouble();
  double get sliderMax =>
      (_isTracks ? sleepTimerMaxTracks : sleepTimerSliderMaxMinutes).toDouble();

  /// The value on the slider: the number kept inside the slider's range,
  /// so a typed 7 or 240 leaves the draft as typed and the thumb at the
  /// nearest end.
  double get sliderValue => value.clamp(sliderMin, sliderMax).toDouble();

  bool get canStepDown => value > min;
  bool get canStepUp => value < max;

  SleepTimerDraft copyWith({
    SleepTimerSetupTab? tab,
    int? minutes,
    int? tracks,
    SleepTimerMode? endKind,
  }) => SleepTimerDraft(
    tab: tab ?? this.tab,
    minutes: minutes ?? this.minutes,
    tracks: tracks ?? this.tracks,
    endKind: endKind ?? this.endKind,
  );

  /// Sets the current tab's number, kept within its range.
  SleepTimerDraft withValue(int number) {
    final kept = number.clamp(min, max);
    return _isTracks ? copyWith(tracks: kept) : copyWith(minutes: kept);
  }

  /// A number typed in the field: empty or zero (`null` or below the
  /// range) keeps the last valid value, anything else is clamped.
  SleepTimerDraft withTyped(int? typed) =>
      typed == null || typed < 1 ? this : withValue(typed);

  /// The - (`-1`) or + (`1`) button: one step, kept within the range.
  SleepTimerDraft stepped(int direction) => withValue(value + direction * step);

  /// Starts the timer the draft describes (replacing a running one).
  void startOn(SleepTimer timer) {
    switch (tab) {
      case SleepTimerSetupTab.minutes:
        timer.startMinutes(minutes);
      case SleepTimerSetupTab.tracks:
        timer.startTracks(tracks);
      case SleepTimerSetupTab.endOf:
        switch (endKind) {
          case SleepTimerMode.endOfTrack:
            timer.startEndOfTrack();
          case SleepTimerMode.endOfAlbum:
            timer.startEndOfAlbum();
          case SleepTimerMode.endOfQueue:
            timer.startEndOfQueue();
          case _:
            break;
        }
    }
  }
}
