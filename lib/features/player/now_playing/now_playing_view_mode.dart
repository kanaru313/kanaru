import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lyrics/playing_track_lyrics_provider.dart';

/// The body wide Now Playing shows under its header.
enum NowPlayingViewMode { split, lyricsOnly, coverOnly }

/// What is known about the playing track's lyrics. `unknown` is the state
/// before the first answer, e.g. right after Now Playing opens.
enum NowPlayingLyricsState { unknown, available, none }

/// The mode to show for the [chosen] one: Lyrics only falls back to Split
/// when the track is known to have no lyrics. While the answer is unknown the
/// chosen mode shows, so reopening in Lyrics only never flashes Split. The
/// fallback is never written back to the choice, so Lyrics only returns with
/// lyrics.
NowPlayingViewMode effectiveViewMode(
  NowPlayingViewMode chosen,
  NowPlayingLyricsState lyrics,
) =>
    chosen == NowPlayingViewMode.lyricsOnly &&
        lyrics == NowPlayingLyricsState.none
    ? NowPlayingViewMode.split
    : chosen;

/// The mode after [effective] in the cycle Split, Lyrics only, Cover only.
/// Lyrics only is skipped when the track is known to have no lyrics.
NowPlayingViewMode nextViewMode(
  NowPlayingViewMode effective,
  NowPlayingLyricsState lyrics,
) => switch (effective) {
  NowPlayingViewMode.split =>
    lyrics == NowPlayingLyricsState.none
        ? NowPlayingViewMode.coverOnly
        : NowPlayingViewMode.lyricsOnly,
  NowPlayingViewMode.lyricsOnly => NowPlayingViewMode.coverOnly,
  NowPlayingViewMode.coverOnly => NowPlayingViewMode.split,
};

/// The mode the user chose. Kept for the running app only, like the library
/// pages' list or grid choice: every launch starts in Split.
class NowPlayingViewModeNotifier extends Notifier<NowPlayingViewMode> {
  @override
  NowPlayingViewMode build() => NowPlayingViewMode.split;

  void choose(NowPlayingViewMode mode) => state = mode;
}

final nowPlayingViewModeProvider =
    NotifierProvider<NowPlayingViewModeNotifier, NowPlayingViewMode>(
      NowPlayingViewModeNotifier.new,
    );

/// What Now Playing knows about the lyrics: `unknown` until the first read
/// answers (every opening starts there, since the read lives only while the
/// screen is shown), then whether the track has any. While the next track's
/// lyrics load the previous answer stays, so track changes do not flip it.
final nowPlayingLyricsStateProvider =
    Provider.autoDispose<NowPlayingLyricsState>((ref) {
      final lyrics = ref.watch(playingTrackLyricsProvider);
      if (lyrics.isLoading && !lyrics.hasValue) {
        return NowPlayingLyricsState.unknown;
      }
      return lyrics.value != null
          ? NowPlayingLyricsState.available
          : NowPlayingLyricsState.none;
    });
