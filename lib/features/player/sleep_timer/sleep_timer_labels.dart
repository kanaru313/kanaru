import 'package:material_ui/material_ui.dart';

import '../../../core/player/sleep_timer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/format_duration.dart';

/// Short text beside the timer button: the time left, or the mode.
String sleepTimerShortLabel(AppLocalizations l10n, SleepTimerState state) =>
    switch (state.mode) {
      null => '',
      SleepTimerMode.minutes => formatDuration(state.remaining),
      SleepTimerMode.tracks => l10n.sleepTimerTracksShort(state.tracksLeft),
      SleepTimerMode.endOfTrack => l10n.sleepTimerLabelTrack,
      SleepTimerMode.endOfAlbum => l10n.sleepTimerLabelAlbum,
      SleepTimerMode.endOfQueue => l10n.sleepTimerLabelQueue,
    };

/// Full text of the dialog's status line and of the button's tooltip while
/// the timer runs.
String sleepTimerStatusText(AppLocalizations l10n, SleepTimerState state) =>
    switch (state.mode) {
      null => '',
      SleepTimerMode.minutes =>
        state.countingPaused
            ? l10n.sleepTimerPausedLeft(formatDuration(state.remaining))
            : l10n.sleepTimerSleepingIn(formatDuration(state.remaining)),
      SleepTimerMode.tracks => l10n.sleepTimerPausesAfterTracks(
        state.tracksLeft,
      ),
      SleepTimerMode.endOfTrack => l10n.sleepTimerPausesEndOfTrack,
      SleepTimerMode.endOfAlbum => l10n.sleepTimerPausesEndOfAlbum,
      SleepTimerMode.endOfQueue => l10n.sleepTimerPausesEndOfQueue,
    };

/// Label of a minutes chip: `15m`, `1h`, `1h30`.
String sleepTimerChipLabel(AppLocalizations l10n, int minutes) {
  if (minutes < 60) return l10n.sleepTimerChipMinutes(minutes);
  if (minutes % 60 == 0) return l10n.sleepTimerChipHours(minutes ~/ 60);
  return l10n.sleepTimerChipHoursMinutes(minutes ~/ 60, minutes % 60);
}

/// "Stops at" and the clock time for a timer of [left] from [now], in the
/// locale's time format (12 or 24 hours as the system asks).
String sleepTimerStopsAtText(
  BuildContext context,
  AppLocalizations l10n,
  Duration left, {
  DateTime? now,
}) {
  final at = (now ?? DateTime.now()).add(left);
  final time = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(at),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return l10n.sleepTimerStopsAt(time);
}

/// Small text under the big value of the running view.
String sleepTimerRunningCaption(
  BuildContext context,
  AppLocalizations l10n,
  SleepTimerState state,
) => switch (state.mode) {
  null => '',
  SleepTimerMode.minutes =>
    state.countingPaused
        ? l10n.sleepTimerCountingPaused
        : sleepTimerStopsAtText(context, l10n, state.remaining),
  SleepTimerMode.tracks => l10n.sleepTimerTracksLeftCaption(state.tracksLeft),
  _ => l10n.sleepTimerEndCaption,
};
