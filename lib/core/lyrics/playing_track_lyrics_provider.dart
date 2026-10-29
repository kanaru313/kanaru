import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'online/playing_lyrics_status_provider.dart';
import 'playing_local_lyrics_provider.dart';

export 'playing_local_lyrics_provider.dart';

/// The lyrics of the playing track from any source (pin, tags, `.lrc`, the
/// online cache), as the views that only need the text see them: loading
/// while the status is being worked out or a search runs, data when lyrics
/// are found, data(null) when there are none. Derived from
/// [playingLyricsStatusProvider]; the value carries the uri it is for.
final playingTrackLyricsProvider =
    Provider.autoDispose<AsyncValue<PlayingLyrics?>>((ref) {
      final status = ref.watch(playingLyricsStatusProvider);
      return switch (status) {
        null => const AsyncData<PlayingLyrics?>(null),
        LyricsReading() ||
        LyricsSearching() => const AsyncLoading<PlayingLyrics?>(),
        LyricsFound(:final uri, :final lyrics) => AsyncData<PlayingLyrics?>((
          uri: uri,
          lyrics: lyrics,
        )),
        LyricsNone() => const AsyncData<PlayingLyrics?>(null),
      };
    });
