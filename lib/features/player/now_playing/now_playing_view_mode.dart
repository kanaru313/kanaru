import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lyrics/playing_track_lyrics_provider.dart';

/// The body wide Now Playing shows under its header.
enum NowPlayingViewMode { split, lyricsOnly, coverOnly }

/// The mode after [mode] in the cycle Split, Lyrics only, Cover only.
NowPlayingViewMode nextViewMode(NowPlayingViewMode mode) => switch (mode) {
  NowPlayingViewMode.split => NowPlayingViewMode.lyricsOnly,
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

/// Whether the playing track has lyrics (they gate the translation button and
/// key). While the next track's lyrics load the previous answer stays, so
/// track changes do not flip it; before the first answer it is false.
final nowPlayingLyricsAvailableProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(playingTrackLyricsProvider).value != null,
);
