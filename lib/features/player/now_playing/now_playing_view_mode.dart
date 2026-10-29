import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lyrics/online/playing_lyrics_status_provider.dart';

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

/// Whether the playing track has lyrics to translate (they gate the
/// translation button and key). Found lyrics: true; a search or no lyrics:
/// false. While the status is still being read the previous answer stays, so
/// track changes do not flip it; before the first answer it is false.
class NowPlayingLyricsAvailable extends Notifier<bool> {
  bool _last = false;

  @override
  bool build() {
    final available = switch (ref.watch(playingLyricsStatusProvider)) {
      null => false,
      LyricsFound() => true,
      LyricsSearching() || LyricsNone() => false,
      LyricsReading() => _last,
    };
    return _last = available;
  }
}

final nowPlayingLyricsAvailableProvider =
    NotifierProvider.autoDispose<NowPlayingLyricsAvailable, bool>(
      NowPlayingLyricsAvailable.new,
    );
