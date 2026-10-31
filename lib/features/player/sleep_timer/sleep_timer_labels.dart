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

/// Full text of the menu header and of the tooltip while the timer runs.
String sleepTimerStatusText(AppLocalizations l10n, SleepTimerState state) =>
    switch (state.mode) {
      null => '',
      SleepTimerMode.minutes =>
        state.countingPaused
            ? l10n.sleepTimerLeftPaused(formatDuration(state.remaining))
            : l10n.sleepTimerLeft(formatDuration(state.remaining)),
      SleepTimerMode.tracks => l10n.sleepTimerPausesAfterTracks(
        state.tracksLeft,
      ),
      SleepTimerMode.endOfTrack => l10n.sleepTimerEndOfTrack,
      SleepTimerMode.endOfAlbum => l10n.sleepTimerEndOfAlbum,
      SleepTimerMode.endOfQueue => l10n.sleepTimerEndOfQueue,
    };
